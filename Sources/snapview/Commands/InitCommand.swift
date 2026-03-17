import ArgumentParser
import Foundation

struct InitCommand: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "init",
    abstract: "One-time setup — adds renderer to test target."
  )

  @Option(name: .long, help: "Xcode scheme to build.")
  var scheme: String

  @Option(name: .long, help: "Path to .xcodeproj.")
  var project: String?

  @Option(name: .long, help: "Path to .xcworkspace.")
  var workspace: String?

  @Option(name: .long, help: "Test target name.")
  var testTarget: String?

  func run() throws {
    print("[1/4] Detecting project...")
    let projectInfo = try ProjectDetector.detect(
      projectPath: project, workspacePath: workspace, testTarget: testTarget
    )
    print("       \(URL(filePath: projectInfo.projectPath).lastPathComponent)")

    print("[2/4] Finding test target... \(projectInfo.testTargetName)")

    if XcodeDetector.isXcodeOpen(projectPath: projectInfo.projectPath) {
      FileHandle.standardError.write(Data(
        "[snapview:warn] Xcode has the project open. Reload the project after init completes.\n".utf8
      ))
    }

    print("[3/4] Adding SnapViewRenderer.swift and SnapViewRegistry.swift...")
    try ProjectInjector.inject(project: projectInfo)

    print("[4/4] Done.\n")
    print("snapview is ready. Run: snapview render <ViewName> --scheme \(scheme)")
    print("Tip: Add .snapview/ to your .gitignore.")
  }
}
