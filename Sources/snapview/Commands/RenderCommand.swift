import ArgumentParser
import Foundation

struct RenderCommand: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "render",
    abstract: "Render #Preview entries matching a view name or preview name."
  )

  @OptionGroup var globalOptions: GlobalOptions

  @Argument(help: "View name or preview name to render. The view must be covered by a #Preview.")
  var viewName: String

  @Option(name: .long, help: "Xcode scheme to build.")
  var scheme: String

  @Option(name: .long) var project: String?
  @Option(name: .long) var workspace: String?
  @Option(name: .long) var testTarget: String?
  @Option(name: .long) var device: String = "iPhone15Pro"
  @Option(name: .long) var scale: Double = 2.0
  @Option(name: .long) var output: String = ".snapview"
  @Option(name: .long) var simulator: String?
  @Flag(name: .long) var rtl = false
  @Option(name: .long) var locale: String = "en_US"
  @Flag(name: .long) var verbose = false

  func run() throws {
    let projectInfo = try ProjectDetector.detect(
      projectPath: project, workspacePath: workspace, testTarget: testTarget
    )
    try ProjectValidator.validateRenderPrerequisites(project: projectInfo, scheme: scheme)
    let prepared = try PreparationStore.load(sourceRoot: projectInfo.sourceRoot)
    try PreparationStore.validate(prepared, project: projectInfo, scheme: scheme)

    // Verify init was run
    let rendererPath = "\(projectInfo.sourceRoot)/\(projectInfo.testTargetName)/SnapViewRenderer.swift"
    guard FileManager.default.fileExists(atPath: rendererPath) else {
      throw CleanExit.message("[snapview:error] Not initialized. Run: snapview init --scheme \(scheme)")
    }

    let (width, height) = Self.deviceDimensions(device)
    let report: (String) -> Void = globalOptions.json ? { _ in } : { print($0) }

    // Step 1: Scan for previews
    report("[1/4] Scanning for #Preview blocks matching \"\(viewName)\"...")
    let allEntries = Self.scanProject(sourceRoot: projectInfo.sourceRoot, appName: projectInfo.appName)
    let matched = PreviewMatcher.match(viewName: viewName, entries: allEntries)

    guard !matched.isEmpty else {
      if globalOptions.json {
        print(JSONOutput.failure(command: "render", error: "No #Preview found for \"\(viewName)\" in project sources."))
        throw ExitCode.failure
      }
      throw CleanExit.message(RenderMessaging.previewNotFound(viewName: viewName))
    }

    let names = matched.map(\.name).joined(separator: ", ")
    report("       Found: \(matched[0].filePath) → \(names)")

    report("[2/4] Loading prepared test artifacts...")
    report("       \(prepared.destinationSpecifier)")

    let startTime = Date()
    let options = BuildRunner.Options(
      scheme: scheme, project: projectInfo, viewNames: matched.map(\.name),
      scale: scale, width: width, height: height,
      rtl: rtl, locale: locale, simulator: simulator, verbose: verbose
    )
    let renderedOutputPath: String

    if let state = try HostSupervisor.reusableHost(
      prepared: prepared,
      sourceRoot: projectInfo.sourceRoot,
      existingHost: try HostStore.loadIfPresent(sourceRoot: projectInfo.sourceRoot)
    ) {
      report("[3/4] Rendering through persistent host...")
      do {
        let response = try HostRuntime.requestRender(
          .init(viewNames: matched.map(\.name), options: options),
          runtimeDirectory: state.runtimeDirectory,
          timeout: 15
        )
        if let errorMessage = response.errorMessage {
          throw CleanExit.message("[snapview:error] \(errorMessage)")
        }
        renderedOutputPath = HostRuntime.outputDirectory(runtimeDirectory: state.runtimeDirectory)
      } catch let error as CleanExit {
        throw error
      } catch {
        report("       Host unavailable, falling back to cached test bundle...")
        renderedOutputPath = try BuildRunner.runPrepared(options: options, prepared: prepared)
      }
    } else {
      report("[3/4] Running cached test bundle...")
      renderedOutputPath = try BuildRunner.runPrepared(options: options, prepared: prepared)
    }
    let elapsed = String(format: "%.1f", Date().timeIntervalSince(startTime))

    // Step 4: Extract PNGs
    let outputDir = "\(projectInfo.sourceRoot)/\(output)"
    let finalized = try RenderedOutputFinalizer.finalize(
      renderedOutputPath: renderedOutputPath,
      outputDir: outputDir
    )
    if finalized.usedRuntimeFallback {
      report("       Warning: couldn't copy PNGs to \(outputDir); using runtime output instead.")
      for warning in finalized.warnings {
        report("       \(warning)")
      }
    }
    let paths = finalized.imagePaths
    let galleryEntries = Self.galleryEntries(
      from: matched,
      finalized: finalized,
      updatedAt: Date()
    )
    _ = try GalleryStore.persist(
      entries: galleryEntries,
      projectPath: projectInfo.projectPath,
      scheme: scheme,
      sourceRoot: projectInfo.sourceRoot,
      mergeWithExisting: true
    )

    if globalOptions.json {
      let data = RenderJSONData(
        viewName: viewName,
        matchedPreviews: matched.map(\.name),
        imagePaths: paths,
        elapsed: elapsed,
        usedRuntimeFallback: finalized.usedRuntimeFallback,
        warnings: finalized.warnings
      )
      print(JSONOutput.success(command: "render", data: data))
    } else {
      print("[4/4] Done (\(elapsed)s).\n")
      for path in paths {
        print("  \(path)")
      }
    }
  }

  // MARK: - Shared Utilities

  static func deviceDimensions(_ device: String) -> (Double, Double) {
    switch device {
    case "iPhone15Pro": return (393, 852)
    case "iPhoneSE": return (375, 667)
    case "iPadPro": return (1024, 1366)
    default:
      if device.hasPrefix("custom:") {
        let parts = device.dropFirst(7).split(separator: "x").compactMap { Double($0) }
        if parts.count == 2 { return (parts[0], parts[1]) }
      }
      return (393, 852)
    }
  }

  static func scanProject(sourceRoot: String, appName: String) -> [PreviewEntry] {
    let fm = FileManager.default
    let appDir = "\(sourceRoot)/\(appName)"
    guard let enumerator = fm.enumerator(atPath: appDir) else { return [] }

    var entries: [PreviewEntry] = []
    while let file = enumerator.nextObject() as? String {
      guard file.hasSuffix(".swift") else { continue }
      let fullPath = "\(appDir)/\(file)"
      guard let source = try? String(contentsOfFile: fullPath, encoding: .utf8) else { continue }
      let fileEntries = PreviewScanner.scan(source: source, filePath: file)
      entries.append(contentsOf: fileEntries)
    }
    return entries
  }

  static func galleryEntries(
    from previewEntries: [PreviewEntry],
    finalized: FinalizedRenderOutput,
    updatedAt: Date
  ) -> [GalleryEntry] {
    let imagePathsByName = Dictionary(uniqueKeysWithValues: finalized.imagePaths.map { path in
      (URL(filePath: path).deletingPathExtension().lastPathComponent, path)
    })

    return previewEntries.compactMap { entry in
      guard let imagePath = imagePathsByName[entry.name] else {
        return nil
      }

      return GalleryEntry(
        previewName: entry.name,
        sourceFile: entry.filePath,
        imagePath: imagePath,
        source: finalized.usedRuntimeFallback ? .runtimeFallback : .copied,
        warnings: finalized.warnings,
        updatedAt: updatedAt
      )
    }
  }
}

struct RenderJSONData: Encodable {
  let viewName: String
  let matchedPreviews: [String]
  let imagePaths: [String]
  let elapsed: String
  let usedRuntimeFallback: Bool
  let warnings: [String]
}
