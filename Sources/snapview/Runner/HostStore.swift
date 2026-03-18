import Darwin
import Foundation

struct HostedRenderState: Codable, Equatable {
  let scheme: String
  let projectPath: String
  let testTargetName: String
  let runtimeDirectory: String
  let logPath: String
  let destinationSpecifier: String
  let xctestrunPath: String
  let pid: Int

  private enum CodingKeys: String, CodingKey {
    case scheme
    case projectPath
    case testTargetName
    case runtimeDirectory
    case logPath
    case destinationSpecifier
    case xctestrunPath
    case pid
  }

  init(
    scheme: String,
    projectPath: String,
    testTargetName: String,
    runtimeDirectory: String,
    logPath: String,
    destinationSpecifier: String,
    xctestrunPath: String,
    pid: Int
  ) {
    self.scheme = scheme
    self.projectPath = projectPath
    self.testTargetName = testTargetName
    self.runtimeDirectory = runtimeDirectory
    self.logPath = logPath
    self.destinationSpecifier = destinationSpecifier
    self.xctestrunPath = xctestrunPath
    self.pid = pid
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    scheme = try container.decode(String.self, forKey: .scheme)
    projectPath = try container.decode(String.self, forKey: .projectPath)
    testTargetName = try container.decode(String.self, forKey: .testTargetName)
    runtimeDirectory = try container.decode(String.self, forKey: .runtimeDirectory)
    logPath = try container.decode(String.self, forKey: .logPath)
    destinationSpecifier = try container.decodeIfPresent(String.self, forKey: .destinationSpecifier) ?? ""
    xctestrunPath = try container.decodeIfPresent(String.self, forKey: .xctestrunPath) ?? ""
    pid = try container.decode(Int.self, forKey: .pid)
  }
}

enum HostStore {

  static func save(_ state: HostedRenderState, sourceRoot: String) throws {
    let path = stateFilePath(sourceRoot: sourceRoot)
    let directory = URL(filePath: path).deletingLastPathComponent()
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let data = try JSONEncoder().encode(state)
    try data.write(to: URL(filePath: path), options: .atomic)
  }

  static func load(sourceRoot: String) throws -> HostedRenderState {
    let data = try Data(contentsOf: URL(filePath: stateFilePath(sourceRoot: sourceRoot)))
    return try JSONDecoder().decode(HostedRenderState.self, from: data)
  }

  static func loadIfPresent(sourceRoot: String) throws -> HostedRenderState? {
    let path = stateFilePath(sourceRoot: sourceRoot)
    guard FileManager.default.fileExists(atPath: path) else {
      return nil
    }
    return try load(sourceRoot: sourceRoot)
  }

  static func loadActive(sourceRoot: String) throws -> HostedRenderState? {
    guard let state = try loadIfPresent(sourceRoot: sourceRoot) else {
      return nil
    }
    return isActive(state) ? state : nil
  }

  static func remove(sourceRoot: String) throws {
    let path = stateFilePath(sourceRoot: sourceRoot)
    if FileManager.default.fileExists(atPath: path) {
      try FileManager.default.removeItem(atPath: path)
    }
  }

  static func stateFilePath(sourceRoot: String) -> String {
    "\(sourceRoot)/.snapview/host.json"
  }

  static func isActive(_ state: HostedRenderState) -> Bool {
    isProcessAlive(pid: state.pid) && FileManager.default.fileExists(
      atPath: HostRuntime.readyPath(runtimeDirectory: state.runtimeDirectory)
    )
  }

  static func staleReason(
    _ state: HostedRenderState?,
    project: ProjectInfo,
    scheme: String
  ) -> String? {
    guard let state else {
      return nil
    }
    guard state.scheme == scheme else {
      return "host scheme \(state.scheme) does not match \(scheme)"
    }
    guard state.projectPath == project.projectPath else {
      return "host project path does not match the current project"
    }
    guard state.testTargetName == project.testTargetName else {
      return "host test target \(state.testTargetName) does not match \(project.testTargetName)"
    }
    guard FileManager.default.fileExists(atPath: state.runtimeDirectory) else {
      return "host runtime directory is missing"
    }
    guard isProcessAlive(pid: state.pid) else {
      return "host process is not running"
    }
    guard FileManager.default.fileExists(
      atPath: HostRuntime.readyPath(runtimeDirectory: state.runtimeDirectory)
    ) else {
      return "host ready marker is missing"
    }
    return nil
  }

  static func driftFinding(
    _ state: HostedRenderState?,
    project: ProjectInfo,
    scheme: String
  ) -> HealthFinding? {
    guard let reason = staleReason(state, project: project, scheme: scheme) else {
      return nil
    }

    return HealthFinding(
      severity: .warning,
      code: .staleHostState,
      message: "Persistent host state is stale: \(reason)",
      fix: "Run: snapview host stop --project \(project.projectPath) && snapview host start --scheme \(scheme) --project \(project.projectPath)"
    )
  }

  static func isProcessAlive(pid: Int) -> Bool {
    let result = kill(pid_t(pid), 0)
    return result == 0 || errno == EPERM
  }
}
