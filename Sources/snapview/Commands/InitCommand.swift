import ArgumentParser
import Foundation

struct InitCommand: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "init",
    abstract: "One-time setup — adds renderer to test target."
  )

  @OptionGroup var globalOptions: GlobalOptions

  @Option(name: .long, help: "Xcode scheme to build.")
  var scheme: String

  @Option(name: .long, help: "Path to .xcodeproj.")
  var project: String?

  @Option(name: .long, help: "Path to .xcworkspace.")
  var workspace: String?

  @Option(name: .long, help: "Test target name.")
  var testTarget: String?

  func run() throws {
    let report: (String) -> Void = globalOptions.json ? { _ in } : { print($0) }

    report("[1/4] Detecting project...")
    let projectInfo = try ProjectDetector.detect(
      projectPath: project, workspacePath: workspace, testTarget: testTarget
    )
    report("       \(URL(filePath: projectInfo.projectPath).lastPathComponent)")

    report("[2/4] Finding test target... \(projectInfo.testTargetName)")

    if XcodeDetector.isXcodeOpen(projectPath: projectInfo.projectPath) {
      FileHandle.standardError.write(Data(
        "[snapview:warn] Xcode has the project open. Reload the project after init completes.\n".utf8
      ))
    }

    report("[3/4] Adding SnapViewRenderer.swift and SnapViewRegistry.swift...")
    try ProjectInjector.inject(project: projectInfo)

    if globalOptions.json {
      let data = InitJSONData(
        projectPath: projectInfo.projectPath,
        testTarget: projectInfo.testTargetName
      )
      print(JSONOutput.success(command: "init", data: data))
    } else {
      print("[4/4] Done.\n")
      print("snapview is ready. Run: snapview prepare --scheme \(scheme)")
      print("Tip: Add .snapview/ to your .gitignore.")
    }
  }
}

struct InitJSONData: Encodable {
  let projectPath: String
  let testTarget: String
}
