import ArgumentParser

struct ListCommand: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "list",
    abstract: "List all discovered #Preview blocks."
  )

  @Option(name: .long) var project: String?
  @Option(name: .long) var workspace: String?

  func run() throws {
    print("list not yet implemented")
  }
}
