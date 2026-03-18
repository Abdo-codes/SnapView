import ArgumentParser
import Foundation

struct RenderAllCommand: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "render-all",
    abstract: "Render all discovered #Preview blocks in the project."
  )

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

    let rendererPath = "\(projectInfo.sourceRoot)/\(projectInfo.testTargetName)/SnapViewRenderer.swift"
    guard FileManager.default.fileExists(atPath: rendererPath) else {
      throw CleanExit.message("[snapview:error] Not initialized. Run: snapview init --scheme \(scheme)")
    }

    print("[1/4] Scanning all #Preview blocks...")
    let allEntries = RenderCommand.scanProject(sourceRoot: projectInfo.sourceRoot, appName: projectInfo.appName)
    guard !allEntries.isEmpty else {
      throw CleanExit.message(RenderMessaging.noPreviewsFound())
    }
    print("       Found \(allEntries.count) previews.")

    print("[2/4] Loading prepared test artifacts...")
    print("       \(prepared.destinationSpecifier)")

    let (width, height) = RenderCommand.deviceDimensions(device)
    let startTime = Date()
    let options = BuildRunner.Options(
      scheme: scheme, project: projectInfo, viewNames: [],
      scale: scale, width: width, height: height,
      rtl: rtl, locale: locale, simulator: simulator, verbose: verbose
    )
    let renderedOutputPath: String

    if let state = try HostStore.loadActive(sourceRoot: projectInfo.sourceRoot) {
      print("[3/4] Rendering through persistent host...")
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
        print("       Host unavailable, falling back to cached test bundle...")
        try? HostStore.remove(sourceRoot: projectInfo.sourceRoot)
        renderedOutputPath = try BuildRunner.runPrepared(options: options, prepared: prepared)
      }
    } else {
      print("[3/4] Running cached test bundle...")
      renderedOutputPath = try BuildRunner.runPrepared(options: options, prepared: prepared)
    }
    let elapsed = String(format: "%.1f", Date().timeIntervalSince(startTime))

    let outputDir = "\(projectInfo.sourceRoot)/\(output)"
    let finalized = try RenderedOutputFinalizer.finalize(
      renderedOutputPath: renderedOutputPath,
      outputDir: outputDir
    )
    if finalized.usedRuntimeFallback {
      print("       Warning: couldn't copy PNGs to \(outputDir); using runtime output instead.")
      for warning in finalized.warnings {
        print("       \(warning)")
      }
    }
    let paths = finalized.imagePaths
    let galleryEntries = RenderCommand.galleryEntries(
      from: allEntries,
      finalized: finalized,
      updatedAt: Date()
    )
    _ = try GalleryStore.persist(
      entries: galleryEntries,
      projectPath: projectInfo.projectPath,
      scheme: scheme,
      sourceRoot: projectInfo.sourceRoot,
      mergeWithExisting: false
    )
    print("[4/4] Done (\(elapsed)s).\n")
    for path in paths { print("  \(path)") }
  }
}
