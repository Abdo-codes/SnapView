import Foundation

struct HostRenderRequest: Codable, Equatable {
  let requestID: String
  let viewNames: [String]
  let scale: Double
  let width: Double
  let height: Double
  let rtl: Bool
  let locale: String
}

struct HostRenderResponse: Codable, Equatable {
  let requestID: String
  let renderedViewNames: [String]
  let errorMessage: String?
}

extension HostRenderRequest {
  init(viewNames: [String], options: BuildRunner.Options) {
    self.init(
      requestID: UUID().uuidString,
      viewNames: viewNames,
      scale: options.scale,
      width: options.width,
      height: options.height,
      rtl: options.rtl,
      locale: options.locale
    )
  }
}

enum HostRuntime {

  enum Error: Swift.Error, CustomStringConvertible {
    case responseTimedOut(String)
    case responseReadFailed(String)

    var description: String {
      switch self {
      case .responseTimedOut(let requestID):
        return "[snapview:error] Persistent host did not respond to request \(requestID) before timing out."
      case .responseReadFailed(let path):
        return "[snapview:error] Failed to read host response from \(path)."
      }
    }
  }

  static let rootDirectory = "/tmp/snapview/runtimes"

  static func hostRuntimeDirectory(for prepared: PreparedRenderState) -> String {
    "\(rootDirectory)/\(runtimeKey(for: prepared))/host"
  }

  static func oneShotRuntimeDirectory(for prepared: PreparedRenderState) -> String {
    oneShotRuntimeDirectory(
      projectPath: prepared.projectPath,
      scheme: prepared.scheme,
      testTargetName: prepared.testTargetName
    )
  }

  static func oneShotRuntimeDirectory(
    projectPath: String,
    scheme: String,
    testTargetName: String
  ) -> String {
    "\(rootDirectory)/\(runtimeKey(projectPath: projectPath, scheme: scheme, testTargetName: testTargetName))/oneshot-\(UUID().uuidString)"
  }

  static func outputDirectory(runtimeDirectory: String) -> String {
    "\(runtimeDirectory)/output"
  }

  static func configPath(runtimeDirectory: String) -> String {
    "\(runtimeDirectory)/config.json"
  }

  static func requestPath(runtimeDirectory: String) -> String {
    "\(runtimeDirectory)/request.json"
  }

  static func responsePath(runtimeDirectory: String) -> String {
    "\(runtimeDirectory)/response.json"
  }

  static func readyPath(runtimeDirectory: String) -> String {
    "\(runtimeDirectory)/ready.json"
  }

  static func stopPath(runtimeDirectory: String) -> String {
    "\(runtimeDirectory)/stop"
  }

  static func prepare(runtimeDirectory: String) throws {
    try FileManager.default.createDirectory(atPath: rootDirectory, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(atPath: runtimeDirectory, withIntermediateDirectories: true)

    for path in [
      configPath(runtimeDirectory: runtimeDirectory),
      requestPath(runtimeDirectory: runtimeDirectory),
      responsePath(runtimeDirectory: runtimeDirectory),
      readyPath(runtimeDirectory: runtimeDirectory),
      stopPath(runtimeDirectory: runtimeDirectory),
    ] {
      try? FileManager.default.removeItem(atPath: path)
    }
  }

  static func clearOutputDirectory(runtimeDirectory: String) throws {
    let fm = FileManager.default
    let outputDirectory = outputDirectory(runtimeDirectory: runtimeDirectory)
    if fm.fileExists(atPath: outputDirectory) {
      try fm.removeItem(atPath: outputDirectory)
    }
    try fm.createDirectory(atPath: outputDirectory, withIntermediateDirectories: true)
  }

  static func writeRequest(_ request: HostRenderRequest, runtimeDirectory: String) throws {
    let responsePath = responsePath(runtimeDirectory: runtimeDirectory)
    if FileManager.default.fileExists(atPath: responsePath) {
      try FileManager.default.removeItem(atPath: responsePath)
    }

    let data = try JSONEncoder().encode(request)
    try data.write(to: URL(filePath: requestPath(runtimeDirectory: runtimeDirectory)), options: .atomic)
  }

  static func waitForResponse(
    requestID: String,
    runtimeDirectory: String,
    timeout: TimeInterval
  ) throws -> HostRenderResponse {
    let deadline = Date().addingTimeInterval(timeout)
    let path = responsePath(runtimeDirectory: runtimeDirectory)

    while Date() < deadline {
      if FileManager.default.fileExists(atPath: path) {
        do {
          let data = try Data(contentsOf: URL(filePath: path))
          let response = try JSONDecoder().decode(HostRenderResponse.self, from: data)
          if response.requestID == requestID {
            return response
          }
        } catch {
          throw Error.responseReadFailed(path)
        }
      }
      Thread.sleep(forTimeInterval: 0.1)
    }

    throw Error.responseTimedOut(requestID)
  }

  static func requestRender(
    _ request: HostRenderRequest,
    runtimeDirectory: String,
    timeout: TimeInterval = 5
  ) throws -> HostRenderResponse {
    try writeRequest(request, runtimeDirectory: runtimeDirectory)
    return try waitForResponse(
      requestID: request.requestID,
      runtimeDirectory: runtimeDirectory,
      timeout: timeout
    )
  }

  private static func runtimeKey(for prepared: PreparedRenderState) -> String {
    runtimeKey(
      projectPath: prepared.projectPath,
      scheme: prepared.scheme,
      testTargetName: prepared.testTargetName
    )
  }

  private static func runtimeKey(
    projectPath: String,
    scheme: String,
    testTargetName: String
  ) -> String {
    stableKey("\(projectPath)|\(scheme)|\(testTargetName)")
  }

  private static func stableKey(_ value: String) -> String {
    let bytes = Array(value.utf8)
    var hash: UInt64 = 14_695_981_039_346_656_037
    for byte in bytes {
      hash ^= UInt64(byte)
      hash = hash &* 1_099_511_628_211
    }
    return String(format: "%016llx", hash)
  }
}
