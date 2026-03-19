import Foundation

enum BuildRunner {

  struct Destination {
    let platform: String
    let simulator: String
    let osVersion: String?

    var destinationSpecifier: String {
      var specifier = "platform=\(platform) Simulator"
      if let osVersion {
        specifier += ",OS=\(osVersion)"
      }
      specifier += ",name=\(simulator)"
      return specifier
    }
  }

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
    case noSimulatorDestination(String)
    case xctestrunNotFound(String)

    var description: String {
      switch self {
      case .buildFailed(let code, let output):
        let firstLine = output.split(separator: "\n").first.map(String.init) ?? "unknown"
        return "[snapview:error] xcodebuild failed (exit \(code)): \(firstLine)"
      case .noSimulatorDestination(let scheme):
        return "[snapview:error] No simulator destination found for scheme '\(scheme)'."
      case .xctestrunNotFound(let path):
        return "[snapview:error] No .xctestrun file found under \(path)."
      }
    }
  }

  static func run(options: Options) throws {
    let runtimeDirectory = HostRuntime.oneShotRuntimeDirectory(
      projectPath: options.project.projectPath,
      scheme: options.scheme,
      testTargetName: options.project.testTargetName
    )
    try HostRuntime.prepare(runtimeDirectory: runtimeDirectory)
    try HostRuntime.clearOutputDirectory(runtimeDirectory: runtimeDirectory)
    try writeConfig(options: options, runtimeDirectory: runtimeDirectory)

    let showDestinationsOutput = runXcodebuildShowDestinations(
      scheme: options.scheme,
      project: options.project
    )
    let resolvedDestination = try resolveDestination(
      fromShowDestinations: showDestinationsOutput,
      requestedSimulator: options.simulator,
      scheme: options.scheme
    )
    let destination = resolvedDestination.destinationSpecifier

    let args = testArguments(
      scheme: options.scheme,
      project: options.project,
      destinationSpecifier: destination
    ) + ["-only-testing:\(options.project.testTargetName)/SnapViewRenderer/test_render"]
    try runXcodebuild(arguments: args, verbose: options.verbose)
  }

  static func prepare(
    scheme: String,
    project: ProjectInfo,
    simulator: String?,
    verbose: Bool
  ) throws -> PreparedRenderState {
    let showDestinationsOutput = runXcodebuildShowDestinations(
      scheme: scheme,
      project: project
    )
    let destination = try resolveDestination(
      fromShowDestinations: showDestinationsOutput,
      requestedSimulator: simulator,
      scheme: scheme
    )
    let derivedDataPath = "\(project.sourceRoot)/.snapview/DerivedData"
    let args = buildForTestingArguments(
      scheme: scheme,
      project: project,
      destination: destination,
      derivedDataPath: derivedDataPath
    )
    try runXcodebuild(arguments: args, verbose: verbose)
    let xctestrunPath = try findXCTestRun(inDerivedDataPath: derivedDataPath)

    return PreparedRenderState(
      scheme: scheme,
      projectPath: project.projectPath,
      workspacePath: project.workspacePath,
      testTargetName: project.testTargetName,
      destinationSpecifier: destination.destinationSpecifier,
      derivedDataPath: derivedDataPath,
      xctestrunPath: xctestrunPath
    )
  }

  static func runPrepared(
    options: Options,
    prepared: PreparedRenderState
  ) throws -> String {
    let runtimeDirectory = HostRuntime.oneShotRuntimeDirectory(for: prepared)
    try HostRuntime.prepare(runtimeDirectory: runtimeDirectory)
    try HostRuntime.clearOutputDirectory(runtimeDirectory: runtimeDirectory)
    try writeConfig(options: options, runtimeDirectory: runtimeDirectory)
    let scopedXCTestRunPath = XCTestRunConfigurator.scopedXCTestRunPath(
      from: prepared.xctestrunPath,
      name: "oneshot-\(UUID().uuidString)"
    )
    try XCTestRunConfigurator.writeScopedXCTestRun(
      from: prepared.xctestrunPath,
      to: scopedXCTestRunPath,
      runtimeDirectory: runtimeDirectory
    )
    let args = testWithoutBuildingArguments(
      xctestrunPath: scopedXCTestRunPath,
      destinationSpecifier: prepared.destinationSpecifier,
      onlyTesting: "\(options.project.testTargetName)/SnapViewRenderer/test_render"
    )
    try runXcodebuild(arguments: args, verbose: options.verbose)
    try? FileManager.default.removeItem(atPath: scopedXCTestRunPath)
    return HostRuntime.outputDirectory(runtimeDirectory: runtimeDirectory)
  }

  private static func writeConfig(options: Options, runtimeDirectory: String) throws {
    let fm = FileManager.default
    if !fm.fileExists(atPath: runtimeDirectory) {
      try fm.createDirectory(atPath: runtimeDirectory, withIntermediateDirectories: true)
    }

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
    let configData = try JSONSerialization.data(
      withJSONObject: config, options: [.prettyPrinted, .sortedKeys]
    )
    try configData.write(
      to: URL(filePath: HostRuntime.configPath(runtimeDirectory: runtimeDirectory)),
      options: .atomic
    )
  }

  static func resolveDestination(
    fromShowDestinations output: String,
    requestedSimulator: String?,
    scheme: String = "selected scheme"
  ) throws -> Destination {
    if let requestedSimulator {
      if let exactMatch = findCandidate(named: requestedSimulator, inShowDestinations: output) {
        return exactMatch
      }
      let platform = try detectPlatform(fromShowDestinations: output, scheme: scheme)
      return Destination(platform: platform, simulator: requestedSimulator, osVersion: nil)
    }
    return try detectDestination(fromShowDestinations: output, scheme: scheme)
  }

  static func buildForTestingArguments(
    scheme: String,
    project: ProjectInfo,
    destination: Destination,
    derivedDataPath: String
  ) -> [String] {
    projectArguments(project: project) + [
      "build-for-testing",
      "-scheme", scheme,
      "-destination", destination.destinationSpecifier,
      "-derivedDataPath", derivedDataPath,
      "-skipMacroValidation",
      "CODE_SIGNING_ALLOWED=NO",
    ]
  }

  static func testWithoutBuildingArguments(
    xctestrunPath: String,
    destinationSpecifier: String,
    onlyTesting: String
  ) -> [String] {
    [
      "xcodebuild",
      "test-without-building",
      "-xctestrun", xctestrunPath,
      "-destination", destinationSpecifier,
      "-only-testing:\(onlyTesting)",
      "-skipMacroValidation",
      "CODE_SIGNING_ALLOWED=NO",
    ]
  }

  static func findXCTestRun(inDerivedDataPath derivedDataPath: String) throws -> String {
    let fm = FileManager.default
    guard let enumerator = fm.enumerator(atPath: derivedDataPath) else {
      throw Error.xctestrunNotFound(derivedDataPath)
    }

    while let file = enumerator.nextObject() as? String {
      if file.hasSuffix(".xctestrun") {
        return "\(derivedDataPath)/\(file)"
      }
    }

    throw Error.xctestrunNotFound(derivedDataPath)
  }

  private static func detectPlatform(
    fromShowDestinations output: String,
    scheme: String
  ) throws -> String {
    if output.contains("tvOS Simulator") { return "tvOS" }
    if output.contains("watchOS Simulator") { return "watchOS" }
    if output.contains("visionOS Simulator") { return "visionOS" }
    if output.contains("iOS Simulator") { return "iOS" }
    throw Error.noSimulatorDestination(scheme)
  }

  private static func detectDestination(
    fromShowDestinations output: String,
    scheme: String
  ) throws -> Destination {
    let lines = output.components(separatedBy: .newlines)
    var candidates: [Destination] = []

    for line in lines {
      guard line.contains("Simulator") && line.contains("name:") else { continue }
      guard !line.contains("placeholder") && !line.contains("Any ") else { continue }
      guard !line.contains("BAZEL_TEST") && !line.contains("TEST_") else { continue }

      if line.contains("tvOS Simulator"), let name = extractName(from: line) {
        candidates.append(Destination(platform: "tvOS", simulator: name, osVersion: extractOS(from: line)))
      } else if line.contains("iOS Simulator"), let name = extractName(from: line) {
        candidates.append(Destination(platform: "iOS", simulator: name, osVersion: extractOS(from: line)))
      } else if line.contains("watchOS Simulator"), let name = extractName(from: line) {
        candidates.append(Destination(platform: "watchOS", simulator: name, osVersion: extractOS(from: line)))
      } else if line.contains("visionOS Simulator"), let name = extractName(from: line) {
        candidates.append(Destination(platform: "visionOS", simulator: name, osVersion: extractOS(from: line)))
      }
    }

    if let iphone = candidates.first(where: { $0.simulator.contains("iPhone") }) {
      return iphone
    }
    if let tv = candidates.first(where: { $0.simulator.contains("Apple TV") }) {
      return tv
    }
    if let first = candidates.first { return first }

    throw Error.noSimulatorDestination(scheme)
  }

  private static func findCandidate(
    named simulatorName: String,
    inShowDestinations output: String
  ) -> Destination? {
    let candidates = output.components(separatedBy: .newlines).compactMap { line -> Destination? in
      guard line.contains("Simulator") && line.contains("name:") else { return nil }
      guard !line.contains("placeholder") && !line.contains("Any ") else { return nil }
      guard !line.contains("BAZEL_TEST") && !line.contains("TEST_") else { return nil }

      let platform: String
      if line.contains("tvOS Simulator") {
        platform = "tvOS"
      } else if line.contains("iOS Simulator") {
        platform = "iOS"
      } else if line.contains("watchOS Simulator") {
        platform = "watchOS"
      } else if line.contains("visionOS Simulator") {
        platform = "visionOS"
      } else {
        return nil
      }

      guard let name = extractName(from: line) else { return nil }
      return Destination(platform: platform, simulator: name, osVersion: extractOS(from: line))
    }

    return candidates.first {
      $0.simulator.compare(simulatorName, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
    }
  }

  private static func extractName(from destinationLine: String) -> String? {
    guard let nameRange = destinationLine.range(of: "name:") else { return nil }
    let afterName = destinationLine[nameRange.upperBound...]
    let name = afterName.trimmingCharacters(in: .whitespaces)
      .replacingOccurrences(of: " }", with: "")
      .trimmingCharacters(in: .whitespaces)
    return name.isEmpty ? nil : name
  }

  private static func extractOS(from destinationLine: String) -> String? {
    guard let osRange = destinationLine.range(of: "OS:") else { return nil }
    let afterOS = destinationLine[osRange.upperBound...]
    let os = afterOS.split(separator: ",", maxSplits: 1).first.map(String.init)?
      .trimmingCharacters(in: .whitespaces)
    return os?.isEmpty == false ? os : nil
  }

  private static func runXcodebuildShowDestinations(scheme: String, project: ProjectInfo) -> String {
    var args = ["xcodebuild", "-showdestinations", "-scheme", scheme]
    if let workspace = project.workspacePath {
      args += ["-workspace", workspace]
    } else {
      args += ["-project", project.projectPath]
    }
    let result = try? ProcessRunner.run(
      executableURL: URL(filePath: "/usr/bin/xcrun"),
      arguments: args,
      verbose: false
    )
    return result?.output ?? ""
  }

  private static func runXcodebuild(arguments: [String], verbose: Bool) throws {
    let result = try ProcessRunner.run(
      executableURL: URL(filePath: "/usr/bin/xcrun"),
      arguments: arguments,
      verbose: verbose
    )

    if result.terminationStatus != 0 {
      throw Error.buildFailed(result.terminationStatus, result.output)
    }
  }

  private static func projectArguments(project: ProjectInfo) -> [String] {
    var args = ["xcodebuild"]
    if let workspace = project.workspacePath {
      args += ["-workspace", workspace]
    } else {
      args += ["-project", project.projectPath]
    }
    return args
  }

  private static func testArguments(
    scheme: String,
    project: ProjectInfo,
    destinationSpecifier: String
  ) -> [String] {
    projectArguments(project: project) + [
      "test",
      "-scheme", scheme,
      "-destination", destinationSpecifier,
      "-skipMacroValidation",
      "CODE_SIGNING_ALLOWED=NO",
    ]
  }
}
