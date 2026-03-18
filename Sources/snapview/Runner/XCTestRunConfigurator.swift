import Foundation

enum XCTestRunConfigurator {

  enum Error: Swift.Error, CustomStringConvertible {
    case invalidPropertyList(String)

    var description: String {
      switch self {
      case .invalidPropertyList(let path):
        return "[snapview:error] Could not read .xctestrun property list at \(path)."
      }
    }
  }

  static func writeScopedXCTestRun(
    from originalPath: String,
    to scopedPath: String,
    runtimeDirectory: String
  ) throws {
    let data = try Data(contentsOf: URL(filePath: originalPath))
    guard let plist = try PropertyListSerialization.propertyList(
      from: data,
      options: [],
      format: nil
    ) as? [String: Any] else {
      throw Error.invalidPropertyList(originalPath)
    }

    let scoped = injectRuntimeDirectory(runtimeDirectory, into: plist)
    let scopedData = try PropertyListSerialization.data(
      fromPropertyList: scoped,
      format: .xml,
      options: 0
    )

    let url = URL(filePath: scopedPath)
    try FileManager.default.createDirectory(
      at: url.deletingLastPathComponent(),
      withIntermediateDirectories: true
    )
    try scopedData.write(to: url, options: .atomic)
  }

  static func scopedXCTestRunPath(from originalPath: String, name: String) -> String {
    let originalURL = URL(filePath: originalPath)
    let stem = originalURL.deletingPathExtension().lastPathComponent
    return originalURL
      .deletingLastPathComponent()
      .appendingPathComponent("\(stem)-snapview-\(name).xctestrun")
      .path
  }

  private static func injectRuntimeDirectory(
    _ runtimeDirectory: String,
    into plist: [String: Any]
  ) -> [String: Any] {
    var scoped = plist

    for key in plist.keys where key != "__xctestrun_metadata__" {
      guard var testTarget = scoped[key] as? [String: Any] else { continue }

      var environment = testTarget["EnvironmentVariables"] as? [String: String] ?? [:]
      environment["SNAPVIEW_RUNTIME_DIR"] = runtimeDirectory
      testTarget["EnvironmentVariables"] = environment

      var testingEnvironment = testTarget["TestingEnvironmentVariables"] as? [String: String] ?? [:]
      testingEnvironment["SNAPVIEW_RUNTIME_DIR"] = runtimeDirectory
      testTarget["TestingEnvironmentVariables"] = testingEnvironment

      scoped[key] = testTarget
    }

    return scoped
  }
}
