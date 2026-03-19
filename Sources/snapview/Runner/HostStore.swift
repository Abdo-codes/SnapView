import Darwin
import Foundation

struct HostedRenderState: Codable, Equatable {
  let scheme: String
  let projectPath: String
  let testTargetName: String
  let runtimeDirectory: String
  let logPath: String
  let pid: Int
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

  static func isProcessAlive(pid: Int) -> Bool {
    let result = kill(pid_t(pid), 0)
    return result == 0 || errno == EPERM
  }
}
