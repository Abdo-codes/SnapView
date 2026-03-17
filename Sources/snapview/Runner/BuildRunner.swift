import Foundation

enum BuildRunner {

  struct Options {
    let scheme: String
    let project: ProjectInfo
    let viewNames: [String]
    let scale: Double
    let width: Double
    let height: Double
    let rtl: Bool
    let locale: String
    let simulator: String?
    let verbose: Bool
  }

  enum Error: Swift.Error, CustomStringConvertible {
    case buildFailed(Int32, String)

    var description: String {
      switch self {
      case .buildFailed(let code, let output):
        let firstLine = output.split(separator: "\n").first.map(String.init) ?? "unknown"
        return "[snapview:error] xcodebuild failed (exit \(code)): \(firstLine)"
      }
    }
  }

  static func run(options: Options) throws {
    let fm = FileManager.default
    try? fm.removeItem(atPath: "/tmp/snapview")
    try fm.createDirectory(atPath: "/tmp/snapview", withIntermediateDirectories: true)

    let simulator = options.simulator ?? "iPhone 16 Pro"

    var args = ["xcodebuild", "test"]

    if let workspace = options.project.workspacePath {
      args += ["-workspace", workspace]
    } else {
      args += ["-project", options.project.projectPath]
    }

    args += [
      "-scheme", options.scheme,
      "-destination", "platform=iOS Simulator,name=\(simulator)",
      "-only-testing:\(options.project.testTargetName)/SnapViewRenderer/test_render",
    ]

    // Write config to JSON file that the renderer reads at runtime.
    // Environment variables on the xcodebuild process are NOT forwarded
    // to the test runner, so we use a file-based config instead.
    let config: [String: String] = [
      "SNAPVIEW_VIEWS": options.viewNames.joined(separator: ","),
      "SNAPVIEW_SCALE": String(options.scale),
      "SNAPVIEW_WIDTH": String(options.width),
      "SNAPVIEW_HEIGHT": String(options.height),
      "SNAPVIEW_RTL": options.rtl ? "1" : "0",
      "SNAPVIEW_LOCALE": options.locale,
    ]
    let configPath = "/tmp/snapview/config.json"
    let configData = try JSONSerialization.data(
      withJSONObject: config, options: [.prettyPrinted, .sortedKeys]
    )
    try configData.write(to: URL(filePath: configPath))

    let process = Process()
    process.executableURL = URL(filePath: "/usr/bin/xcrun")
    process.arguments = args
    process.environment = ProcessInfo.processInfo.environment

    let pipe = Pipe()
    process.standardOutput = options.verbose ? FileHandle.standardOutput : pipe
    process.standardError = options.verbose ? FileHandle.standardError : pipe

    try process.run()
    process.waitUntilExit()

    if process.terminationStatus != 0 {
      let output: String
      if options.verbose {
        output = "(see verbose output above)"
      } else {
        output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
      }
      throw Error.buildFailed(process.terminationStatus, output)
    }
  }
}
