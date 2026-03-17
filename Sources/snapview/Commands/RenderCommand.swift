import ArgumentParser

struct RenderCommand: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "render",
    abstract: "Render previews matching a view name or preview name."
  )

  @Argument(help: "View name or preview name to render.")
  var viewName: String

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
    print("render not yet implemented")
  }
}
