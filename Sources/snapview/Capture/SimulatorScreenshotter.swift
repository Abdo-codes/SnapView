import Foundation

struct SimulatorScreenshotter {
  typealias Runner = (_ arguments: [String], _ environment: [String: String]) throws -> Void

  private let run: Runner

  init(run: @escaping Runner) {
    self.run = run
  }

  func capture(device: String, screenName: String, directory: String) throws -> String {
    try FileManager.default.createDirectory(
      at: URL(filePath: directory),
      withIntermediateDirectories: true
    )

    let outputPath = "\(directory)/\(sanitize(screenName)).png"

    do {
      try run(["simctl", "io", device, "screenshot", outputPath], [:])
      return outputPath
    } catch {
      throw Error.captureFailed(screenName: screenName, detail: describe(error))
    }
  }

  enum Error: Swift.Error, Equatable {
    case captureFailed(screenName: String, detail: String)
  }

  private func sanitize(_ screenName: String) -> String {
    let trimmed = screenName.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed
      .split(whereSeparator: \.isWhitespace)
      .joined(separator: "-")
  }

  private func describe(_ error: Swift.Error) -> String {
    String(describing: error)
  }
}
