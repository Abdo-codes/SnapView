import Foundation
import Testing
@testable import snapview

@Suite("XCTestRunConfigurator")
struct XCTestRunConfiguratorTests {

  @Test("scoped xctestrun path stays next to the original products")
  func scopedPathStaysNextToOriginal() {
    let path = XCTestRunConfigurator.scopedXCTestRunPath(
      from: "/tmp/build/Products/Demo.xctestrun",
      name: "host"
    )

    #expect(path == "/tmp/build/Products/Demo-snapview-host.xctestrun")
  }

  @Test("injects runtime directory into scoped xctestrun copy")
  func injectsRuntimeDirectory() throws {
    let root = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer { try? FileManager.default.removeItem(at: root) }
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)

    let original = root.appendingPathComponent("Demo.xctestrun")
    let scoped = root.appendingPathComponent("scoped.xctestrun")
    try fixtureXCTestRun().write(to: original, atomically: true, encoding: .utf8)

    try XCTestRunConfigurator.writeScopedXCTestRun(
      from: original.path,
      to: scoped.path,
      runtimeDirectory: "/tmp/snapview/runtimes/demo"
    )

    let data = try Data(contentsOf: scoped)
    let plist = try #require(
      PropertyListSerialization.propertyList(from: data, options: [], format: nil)
        as? [String: Any]
    )
    let testTarget = try #require(plist["DemoTests"] as? [String: Any])
    let env = try #require(testTarget["EnvironmentVariables"] as? [String: String])
    let testingEnv = try #require(testTarget["TestingEnvironmentVariables"] as? [String: String])

    #expect(env["SNAPVIEW_RUNTIME_DIR"] == "/tmp/snapview/runtimes/demo")
    #expect(testingEnv["SNAPVIEW_RUNTIME_DIR"] == "/tmp/snapview/runtimes/demo")
    #expect(env["TERM"] == "dumb")
    #expect(testingEnv["XCODE_SCHEME_NAME"] == "Demo")
  }

  private func fixtureXCTestRun() -> String {
    """
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0">
    <dict>
      <key>DemoTests</key>
      <dict>
        <key>EnvironmentVariables</key>
        <dict>
          <key>TERM</key>
          <string>dumb</string>
        </dict>
        <key>TestingEnvironmentVariables</key>
        <dict>
          <key>XCODE_SCHEME_NAME</key>
          <string>Demo</string>
        </dict>
      </dict>
      <key>__xctestrun_metadata__</key>
      <dict>
        <key>FormatVersion</key>
        <integer>1</integer>
      </dict>
    </dict>
    </plist>
    """
  }
}
