import ArgumentParser
import Foundation

struct RenderAllCommand: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "render-all",
    abstract: "Render all discovered #Preview blocks in the project."
  )

  @OptionGroup var globalOptions: GlobalOptions

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

    let report: (String) -> Void = globalOptions.json ? { _ in } : { print($0) }
    let request = RenderAllRequest(
      scheme: scheme,
      projectInfo: projectInfo,
      prepared: prepared,
      device: device,
      scale: scale,
      output: output,
      simulator: simulator,
      rtl: rtl,
      locale: locale,
      verbose: verbose
    )
    let result = try Self.perform(request: request, report: report)

    if globalOptions.json {
      let data = RenderAllJSONData(
        previewCount: result.imagePaths.count,
        imagePaths: result.imagePaths,
        elapsed: result.elapsed
      )
      print(JSONOutput.success(command: "render-all", data: data))
    } else {
      print("[4/4] Done (\(result.elapsed)s).\n")
      for path in result.imagePaths {
        print("  \(path)")
      }
    }
  }
}

struct RenderAllRequest {
  let scheme: String
  let projectInfo: ProjectInfo
  let prepared: PreparedRenderState
  let device: String
  let scale: Double
  let output: String
  let simulator: String?
  let rtl: Bool
  let locale: String
  let verbose: Bool
}

struct RenderAllResult {
  let imagePaths: [String]
  let elapsed: String
}

extension RenderAllCommand {
  static func perform(
    request: RenderAllRequest,
    report: (String) -> Void
  ) throws -> RenderAllResult {
    let projectInfo = request.projectInfo
    let prepared = request.prepared

    let rendererPath = "\(projectInfo.sourceRoot)/\(projectInfo.testTargetName)/SnapViewRenderer.swift"
    guard FileManager.default.fileExists(atPath: rendererPath) else {
      throw CleanExit.message("[snapview:error] Not initialized. Run: snapview init --scheme \(request.scheme)")
    }

    report("[1/4] Scanning all #Preview blocks...")
    let allEntries = RenderCommand.scanProject(sourceRoot: projectInfo.sourceRoot, appName: projectInfo.appName)
    guard !allEntries.isEmpty else {
      throw CleanExit.message(RenderMessaging.noPreviewsFound())
    }
    report("       Found \(allEntries.count) previews.")

    report("[2/4] Loading prepared test artifacts...")
    report("       \(prepared.destinationSpecifier)")

    let (width, height) = RenderCommand.deviceDimensions(request.device)
    let startTime = Date()
    let options = BuildRunner.Options(
      scheme: request.scheme, project: projectInfo, viewNames: [],
      scale: request.scale, width: width, height: height,
      rtl: request.rtl, locale: request.locale, simulator: request.simulator, verbose: request.verbose
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
          .init(viewNames: [], options: options),
          runtimeDirectory: state.runtimeDirectory,
          timeout: 60
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

    let outputDir = "\(projectInfo.sourceRoot)/\(request.output)"
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

    let galleryEntries = RenderCommand.galleryEntries(
      from: allEntries,
      finalized: finalized,
      updatedAt: Date()
    )
    _ = try GalleryStore.persist(
      entries: galleryEntries,
      projectPath: projectInfo.projectPath,
      scheme: request.scheme,
      sourceRoot: projectInfo.sourceRoot,
      mergeWithExisting: false
    )

    return RenderAllResult(imagePaths: finalized.imagePaths, elapsed: elapsed)
  }
}

struct RenderAllJSONData: Encodable {
  let previewCount: Int
  let imagePaths: [String]
  let elapsed: String
}
