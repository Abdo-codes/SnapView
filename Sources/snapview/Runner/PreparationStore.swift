import Foundation

struct PreparedRenderState: Codable, Equatable {
  let scheme: String
  let projectPath: String
  let workspacePath: String?
  let testTargetName: String
  let destinationSpecifier: String
  let derivedDataPath: String
  let xctestrunPath: String
}

enum PreparationStore {

  enum Error: Swift.Error, CustomStringConvertible {
    case missingState(String)
    case staleState(String)

    var description: String {
      switch self {
      case .missingState(let path):
        return "[snapview:error] Preparation metadata not found at \(path). Run: snapview prepare --scheme <Scheme>"
      case .staleState(let detail):
        return "[snapview:error] Preparation is stale: \(detail). Run: snapview prepare --scheme <Scheme>"
      }
    }
  }

  static func save(_ state: PreparedRenderState, sourceRoot: String) throws {
    let path = stateFilePath(sourceRoot: sourceRoot)
    let directory = URL(filePath: path).deletingLastPathComponent()
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let data = try JSONEncoder().encode(state)
    try data.write(to: URL(filePath: path))
  }

  static func load(sourceRoot: String) throws -> PreparedRenderState {
    let path = stateFilePath(sourceRoot: sourceRoot)
    guard FileManager.default.fileExists(atPath: path) else {
      throw Error.missingState(path)
    }
    let data = try Data(contentsOf: URL(filePath: path))
    return try JSONDecoder().decode(PreparedRenderState.self, from: data)
  }

  static func loadIfPresent(sourceRoot: String) throws -> PreparedRenderState? {
    let path = stateFilePath(sourceRoot: sourceRoot)
    guard FileManager.default.fileExists(atPath: path) else {
      return nil
    }
    return try load(sourceRoot: sourceRoot)
  }

  static func stateFilePath(sourceRoot: String) -> String {
    "\(sourceRoot)/.snapview/prepare.json"
  }

  static func validate(
    _ state: PreparedRenderState,
    project: ProjectInfo,
    scheme: String
  ) throws {
    if let reason = staleReason(state, project: project, scheme: scheme) {
      throw Error.staleState(reason)
    }
  }

  static func staleReason(
    _ state: PreparedRenderState?,
    project: ProjectInfo,
    scheme: String
  ) -> String? {
    guard let state else {
      return "preparation metadata is missing"
    }
    guard state.scheme == scheme else {
      return "prepared scheme \(state.scheme) does not match \(scheme)"
    }
    guard state.projectPath == project.projectPath else {
      return "prepared project path does not match the current project"
    }
    guard state.testTargetName == project.testTargetName else {
      return "prepared test target \(state.testTargetName) does not match \(project.testTargetName)"
    }
    guard FileManager.default.fileExists(atPath: state.xctestrunPath) else {
      return "cached .xctestrun is missing"
    }
    return nil
  }

  static func driftFinding(
    _ state: PreparedRenderState?,
    project: ProjectInfo,
    scheme: String
  ) -> HealthFinding? {
    guard let reason = staleReason(state, project: project, scheme: scheme) else {
      return nil
    }

    return HealthFinding(
      severity: .error,
      code: .stalePreparationState,
      message: "Prepared artifacts are stale: \(reason)",
      fix: "Run: snapview prepare --scheme \(scheme)"
    )
  }
}
