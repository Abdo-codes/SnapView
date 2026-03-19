import Darwin
import Foundation

enum HostRunner {

  enum Error: Swift.Error, CustomStringConvertible {
    case failedToStart(String)
    case failedToBecomeReady(String)

    var description: String {
      switch self {
      case .failedToStart(let detail):
        return "[snapview:error] Failed to start persistent host: \(detail)"
      case .failedToBecomeReady(let detail):
        return "[snapview:error] Persistent host did not become ready: \(detail)"
      }
    }
  }

  static func startArguments(prepared: PreparedRenderState) -> [String] {
    startArguments(
      xctestrunPath: prepared.xctestrunPath,
      destinationSpecifier: prepared.destinationSpecifier,
      testTargetName: prepared.testTargetName
    )
  }

  static func start(
    prepared: PreparedRenderState,
    runtimeDirectory: String,
    logPath: String
  ) throws -> Int {
    let logURL = URL(filePath: logPath)
    try FileManager.default.createDirectory(
      at: logURL.deletingLastPathComponent(),
      withIntermediateDirectories: true
    )
    FileManager.default.createFile(atPath: logPath, contents: nil)
    let logHandle = try FileHandle(forWritingTo: logURL)
    let scopedXCTestRunPath = XCTestRunConfigurator.scopedXCTestRunPath(
      from: prepared.xctestrunPath,
      name: "host-\(prepared.testTargetName)"
    )
    try XCTestRunConfigurator.writeScopedXCTestRun(
      from: prepared.xctestrunPath,
      to: scopedXCTestRunPath,
      runtimeDirectory: runtimeDirectory
    )

    let process = Process()
    process.executableURL = URL(filePath: "/usr/bin/xcrun")
    process.arguments = startArguments(
      xctestrunPath: scopedXCTestRunPath,
      destinationSpecifier: prepared.destinationSpecifier,
      testTargetName: prepared.testTargetName
    )
    process.standardOutput = logHandle
    process.standardError = logHandle

    try process.run()
    return Int(process.processIdentifier)
  }

  static func waitUntilReady(
    _ state: HostedRenderState,
    timeout: TimeInterval
  ) throws {
    let deadline = Date().addingTimeInterval(timeout)
    while Date() < deadline {
      if HostStore.isActive(state) {
        return
      }
      if !HostStore.isProcessAlive(pid: state.pid) {
        throw Error.failedToStart(logSummary(at: state.logPath))
      }
      Thread.sleep(forTimeInterval: 0.1)
    }

    throw Error.failedToBecomeReady(logSummary(at: state.logPath))
  }

  static func stop(_ state: HostedRenderState, timeout: TimeInterval) throws {
    try Data().write(
      to: URL(filePath: HostRuntime.stopPath(runtimeDirectory: state.runtimeDirectory)),
      options: .atomic
    )

    let deadline = Date().addingTimeInterval(timeout)
    while Date() < deadline {
      if !HostStore.isProcessAlive(pid: state.pid) {
        try cleanupRuntimeFiles(runtimeDirectory: state.runtimeDirectory)
        return
      }
      Thread.sleep(forTimeInterval: 0.1)
    }

    _ = kill(pid_t(state.pid), SIGTERM)
    Thread.sleep(forTimeInterval: 0.2)
    try cleanupRuntimeFiles(runtimeDirectory: state.runtimeDirectory)
  }

  private static func cleanupRuntimeFiles(runtimeDirectory: String) throws {
    for path in [
      HostRuntime.requestPath(runtimeDirectory: runtimeDirectory),
      HostRuntime.responsePath(runtimeDirectory: runtimeDirectory),
      HostRuntime.readyPath(runtimeDirectory: runtimeDirectory),
      HostRuntime.stopPath(runtimeDirectory: runtimeDirectory),
    ] {
      try? FileManager.default.removeItem(atPath: path)
    }
  }

  private static func logSummary(at path: String) -> String {
    guard let data = try? Data(contentsOf: URL(filePath: path)),
      let contents = String(data: data, encoding: .utf8)?
        .split(separator: "\n")
        .suffix(5)
        .joined(separator: "\n"),
      !contents.isEmpty
    else {
      return "see \(path)"
    }
    return contents
  }

  private static func startArguments(
    xctestrunPath: String,
    destinationSpecifier: String,
    testTargetName: String
  ) -> [String] {
    BuildRunner.testWithoutBuildingArguments(
      xctestrunPath: xctestrunPath,
      destinationSpecifier: destinationSpecifier,
      onlyTesting: "\(testTargetName)/SnapViewRenderer/test_host"
    )
  }
}
