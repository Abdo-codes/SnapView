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

    let destination: String
    if let simulator = options.simulator {
      // Auto-detect platform from scheme's available destinations
      let platform = detectPlatform(scheme: options.scheme, project: options.project)
      destination = "platform=\(platform) Simulator,name=\(simulator)"
    } else {
      // Auto-detect both platform and simulator
      let (platform, simName) = detectDestination(scheme: options.scheme, project: options.project)
      destination = "platform=\(platform) Simulator,name=\(simName)"
    }

    var args = ["xcodebuild", "test"]

    if let workspace = options.project.workspacePath {
      args += ["-workspace", workspace]
    } else {
      args += ["-project", options.project.projectPath]
    }

    args += [
      "-scheme", options.scheme,
      "-destination", destination,
      "-only-testing:\(options.project.testTargetName)/SnapViewRenderer/test_render",
      "-skipMacroValidation",
      "CODE_SIGNING_ALLOWED=NO",
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

  // MARK: - Platform Detection

  private static func detectPlatform(scheme: String, project: ProjectInfo) -> String {
    let output = runXcodebuildShowDestinations(scheme: scheme, project: project)
    if output.contains("tvOS Simulator") { return "tvOS" }
    if output.contains("watchOS Simulator") { return "watchOS" }
    if output.contains("visionOS Simulator") { return "visionOS" }
    return "iOS"
  }

  private static func detectDestination(scheme: String, project: ProjectInfo) -> (platform: String, simulator: String) {
    let output = runXcodebuildShowDestinations(scheme: scheme, project: project)

    // Parse all valid simulator destinations
    let lines = output.components(separatedBy: .newlines)
    var candidates: [(platform: String, name: String)] = []

    for line in lines {
      guard line.contains("Simulator") && line.contains("name:") else { continue }
      guard !line.contains("placeholder") && !line.contains("Any ") else { continue }
      guard !line.contains("BAZEL_TEST") && !line.contains("TEST_") else { continue }

      if line.contains("tvOS Simulator"), let name = extractName(from: line) {
        candidates.append(("tvOS", name))
      } else if line.contains("iOS Simulator"), let name = extractName(from: line) {
        candidates.append(("iOS", name))
      } else if line.contains("watchOS Simulator"), let name = extractName(from: line) {
        candidates.append(("watchOS", name))
      } else if line.contains("visionOS Simulator"), let name = extractName(from: line) {
        candidates.append(("visionOS", name))
      }
    }

    // Prefer iPhone over iPad, Apple TV over generic
    if let iphone = candidates.first(where: { $0.name.contains("iPhone") }) {
      return (iphone.platform, iphone.name)
    }
    if let tv = candidates.first(where: { $0.name.contains("Apple TV") }) {
      return (tv.platform, tv.name)
    }
    if let first = candidates.first {
      return (first.platform, first.name)
    }

    return ("iOS", "iPhone 16 Pro")
  }

  private static func extractName(from destinationLine: String) -> String? {
    guard let nameRange = destinationLine.range(of: "name:") else { return nil }
    let afterName = destinationLine[nameRange.upperBound...]
    let name = afterName.trimmingCharacters(in: .whitespaces)
      .replacingOccurrences(of: " }", with: "")
      .trimmingCharacters(in: .whitespaces)
    return name.isEmpty ? nil : name
  }

  private static func runXcodebuildShowDestinations(scheme: String, project: ProjectInfo) -> String {
    let process = Process()
    process.executableURL = URL(filePath: "/usr/bin/xcrun")
    var args = ["xcodebuild", "-showdestinations", "-scheme", scheme]
    if let workspace = project.workspacePath {
      args += ["-workspace", workspace]
    } else {
      args += ["-project", project.projectPath]
    }
    process.arguments = args
    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = FileHandle.nullDevice
    try? process.run()
    process.waitUntilExit()
    return String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
  }
}
