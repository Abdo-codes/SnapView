import ArgumentParser

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
    print("init not yet implemented")
  }
}
