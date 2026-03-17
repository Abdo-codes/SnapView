import ArgumentParser
import Foundation

struct RenderAllCommand: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "render-all",
    abstract: "Render all #Preview blocks in the project."
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

    let rendererPath = "\(projectInfo.sourceRoot)/\(projectInfo.testTargetName)/SnapViewRenderer.swift"
    guard FileManager.default.fileExists(atPath: rendererPath) else {
      throw CleanExit.message("[snapview:error] Not initialized. Run: snapview init --scheme \(scheme)")
    }

    print("[1/4] Scanning all #Preview blocks...")
    let allEntries = RenderCommand.scanProject(sourceRoot: projectInfo.sourceRoot, appName: projectInfo.appName)
    guard !allEntries.isEmpty else {
      throw CleanExit.message("[snapview:error] No #Preview blocks found in project.")
    }
    print("       Found \(allEntries.count) previews.")

    print("[2/4] Regenerating SnapViewRegistry.swift...")
    let allImports = Set(allEntries.flatMap { entry in
      let fullPath = "\(projectInfo.sourceRoot)/\(projectInfo.appName)/\(entry.filePath)"
      let source = (try? String(contentsOfFile: fullPath, encoding: .utf8)) ?? ""
      return ImportScanner.scan(source: source)
    })
    let registry = RegistryGenerator.generate(
      entries: allEntries, imports: Array(allImports), appModule: projectInfo.appName
    )
    let registryPath = "\(projectInfo.sourceRoot)/\(projectInfo.testTargetName)/SnapViewRegistry.swift"
    try registry.write(toFile: registryPath, atomically: true, encoding: .utf8)

    let (width, height) = RenderCommand.deviceDimensions(device)
    print("[3/4] Building & running test...")
    let startTime = Date()
    try BuildRunner.run(options: .init(
      scheme: scheme, project: projectInfo, viewNames: [],
      scale: scale, width: width, height: height,
      rtl: rtl, locale: locale, simulator: simulator, verbose: verbose
    ))
    let elapsed = String(format: "%.1f", Date().timeIntervalSince(startTime))

    let outputDir = "\(projectInfo.sourceRoot)/\(output)"
    let paths = try PNGExtractor.extract(to: outputDir)
    print("[4/4] Done (\(elapsed)s).\n")
    for path in paths { print("  \(path)") }
  }
}
