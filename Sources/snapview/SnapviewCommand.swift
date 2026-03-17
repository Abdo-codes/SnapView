import ArgumentParser

@main
struct Snapview: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "snapview",
    abstract: "Render SwiftUI #Preview blocks to PNG images.",
    subcommands: [
      InitCommand.self,
      RenderCommand.self,
      RenderAllCommand.self,
      ListCommand.self,
      CleanCommand.self,
    ]
  )
}
