import ArgumentParser

struct CleanCommand: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "clean",
    abstract: "Remove .snapview/ output directory."
  )

  @Option(name: .long) var output: String = ".snapview"

  func run() throws {
    print("clean not yet implemented")
  }
}
