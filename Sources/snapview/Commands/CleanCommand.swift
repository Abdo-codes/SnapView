import ArgumentParser
import Foundation

struct CleanCommand: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "clean",
    abstract: "Remove .snapview/ output directory."
  )

  @Option(name: .long) var output: String = ".snapview"

  func run() throws {
    let fm = FileManager.default
    let outputDir = "\(fm.currentDirectoryPath)/\(output)"
    if fm.fileExists(atPath: outputDir) {
      try fm.removeItem(atPath: outputDir)
      print("Removed \(output)/")
    } else {
      print("Nothing to clean — \(output)/ does not exist.")
    }
  }
}
