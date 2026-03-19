import Foundation

enum ProcessRunner {

  struct Result {
    let terminationStatus: Int32
    let output: String
  }

  static func run(
    executableURL: URL,
    arguments: [String],
    environment: [String: String] = ProcessInfo.processInfo.environment,
    verbose: Bool
  ) throws -> Result {
    let process = Process()
    process.executableURL = executableURL
    process.arguments = arguments
    process.environment = environment

    var outputPath: String?
    if verbose {
      process.standardOutput = FileHandle.standardOutput
      process.standardError = FileHandle.standardError
    } else {
      let tempFile = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
      FileManager.default.createFile(atPath: tempFile.path, contents: nil)
      let handle = try FileHandle(forWritingTo: tempFile)
      process.standardOutput = handle
      process.standardError = handle
      outputPath = tempFile.path
    }

    try process.run()
    process.waitUntilExit()

    let output: String
    if let outputPath {
      let data = (try? Data(contentsOf: URL(filePath: outputPath))) ?? Data()
      output = String(data: data, encoding: .utf8) ?? ""
      try? FileManager.default.removeItem(atPath: outputPath)
    } else {
      output = "(see verbose output above)"
    }

    return Result(terminationStatus: process.terminationStatus, output: output)
  }
}
