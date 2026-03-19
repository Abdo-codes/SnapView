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

  static func stateFilePath(sourceRoot: String) -> String {
    "\(sourceRoot)/.snapview/prepare.json"
  }

  static func validate(
    _ state: PreparedRenderState,
    project: ProjectInfo,
    scheme: String
  ) throws {
    guard state.scheme == scheme else {
      throw Error.staleState("prepared scheme \(state.scheme) does not match \(scheme)")
    }
    guard state.projectPath == project.projectPath else {
      throw Error.staleState("prepared project path does not match the current project")
    }
    guard state.testTargetName == project.testTargetName else {
      throw Error.staleState("prepared test target \(state.testTargetName) does not match \(project.testTargetName)")
    }
    guard FileManager.default.fileExists(atPath: state.xctestrunPath) else {
      throw Error.staleState("cached .xctestrun is missing")
    }
  }
}
