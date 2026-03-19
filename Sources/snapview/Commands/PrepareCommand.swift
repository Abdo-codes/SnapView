import ArgumentParser
import Foundation

struct PrepareCommand: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "prepare",
    abstract: "Generate the full preview registry and build test artifacts for fast renders."
  )

  @Option(name: .long, help: "Xcode scheme to build.")
  var scheme: String

  @Option(name: .long) var project: String?
  @Option(name: .long) var workspace: String?
  @Option(name: .long) var testTarget: String?
  @Option(name: .long) var simulator: String?
  @Flag(name: .long) var verbose = false

  func run() throws {
    let projectInfo = try ProjectDetector.detect(
      projectPath: project, workspacePath: workspace, testTarget: testTarget
    )
    _ = try Self.performPreparation(
      projectInfo: projectInfo,
      scheme: scheme,
      simulator: simulator,
      verbose: verbose,
      report: { print($0) }
    )
    print("snapview is prepared.")
    print("Run: snapview render <ViewName> --scheme \(scheme)")
  }

  @discardableResult
  static func performPreparation(
    projectInfo: ProjectInfo,
    scheme: String,
    simulator: String?,
    verbose: Bool,
    report: (String) -> Void
  ) throws -> PreparedRenderState {
    try ProjectValidator.validateRenderPrerequisites(project: projectInfo, scheme: scheme)

    let rendererPath = "\(projectInfo.sourceRoot)/\(projectInfo.testTargetName)/SnapViewRenderer.swift"
    guard FileManager.default.fileExists(atPath: rendererPath) else {
      throw CleanExit.message("[snapview:error] Not initialized. Run: snapview init --scheme \(scheme)")
    }

    report("[1/4] Scanning all #Preview blocks...")
    let allEntries = RenderCommand.scanProject(sourceRoot: projectInfo.sourceRoot, appName: projectInfo.appName)
    guard !allEntries.isEmpty else {
      throw CleanExit.message(RenderMessaging.noPreviewsFound())
    }
    report("       Found \(allEntries.count) previews.")

    report("[2/4] Regenerating full SnapViewRegistry.swift...")
    let allImports = Set(allEntries.flatMap { entry in
      let fullPath = "\(projectInfo.sourceRoot)/\(projectInfo.appName)/\(entry.filePath)"
      let source = (try? String(contentsOfFile: fullPath, encoding: .utf8)) ?? ""
      return ImportScanner.scan(source: source)
    })
    let registry = RegistryGenerator.generate(
      entries: allEntries,
      imports: Array(allImports),
      appModule: projectInfo.moduleName
    )
    let registryPath = "\(projectInfo.sourceRoot)/\(projectInfo.testTargetName)/SnapViewRegistry.swift"
    try registry.write(toFile: registryPath, atomically: true, encoding: .utf8)

    report("[3/4] Building test artifacts...")
    let state = try BuildRunner.prepare(
      scheme: scheme,
      project: projectInfo,
      simulator: simulator,
      verbose: verbose
    )

    report("[4/4] Saving preparation metadata...\n")
    try PreparationStore.save(state, sourceRoot: projectInfo.sourceRoot)
    return state
  }
}
