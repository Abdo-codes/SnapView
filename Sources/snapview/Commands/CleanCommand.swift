import ArgumentParser
import Foundation

struct CleanCommand: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "clean",
    abstract: "Remove .snapview/ output directory."
  )

  @OptionGroup var globalOptions: GlobalOptions

  @Option(name: .long) var output: String = ".snapview"

  func run() throws {
    let fm = FileManager.default
    let outputDir = "\(fm.currentDirectoryPath)/\(output)"
    let existed = fm.fileExists(atPath: outputDir)

    if existed {
      try fm.removeItem(atPath: outputDir)
    }

    if globalOptions.json {
      let data = CleanJSONData(removed: existed, path: outputDir)
      print(JSONOutput.success(command: "clean", data: data))
    } else {
      if existed {
        print("Removed \(output)/")
      } else {
        print("Nothing to clean — \(output)/ does not exist.")
      }
    }
  }
}

struct CleanJSONData: Encodable {
  let removed: Bool
  let path: String
}
