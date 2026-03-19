import Foundation
import Testing
@testable import snapview

@Suite("JSONOutput")
struct JSONOutputTests {

  @Test("success envelope contains command, success flag, and data")
  func successEnvelopeStructure() throws {
    let json = JSONOutput.success(command: "doctor", data: SampleData(value: "test"))
    let parsed = try decode(json)

    #expect(parsed["command"] as? String == "doctor")
    #expect(parsed["success"] as? Bool == true)
    #expect(parsed["error"] is NSNull || parsed["error"] == nil)

    let data = parsed["data"] as? [String: Any]
    #expect(data?["value"] as? String == "test")
  }

  @Test("failure envelope contains command, success false, and error message")
  func failureEnvelopeStructure() throws {
    let json = JSONOutput.failure(command: "render", error: "No preview found")
    let parsed = try decode(json)

    #expect(parsed["command"] as? String == "render")
    #expect(parsed["success"] as? Bool == false)
    #expect(parsed["error"] as? String == "No preview found")
  }

  @Test("doctor JSON data encodes all fields")
  func doctorJSONDataEncodesAllFields() throws {
    let data = DoctorJSONData(
      scheme: "MyApp",
      previewCount: 5,
      outputWritable: true,
      healthy: true,
      findings: [
        HealthFinding(
          severity: .warning,
          code: .staleHostState,
          message: "Host is stale",
          fix: "Restart host"
        )
      ]
    )
    let json = JSONOutput.success(command: "doctor", data: data)
    let parsed = try decode(json)
    let inner = parsed["data"] as? [String: Any]

    #expect(inner?["scheme"] as? String == "MyApp")
    #expect(inner?["previewCount"] as? Int == 5)
    #expect(inner?["outputWritable"] as? Bool == true)
    #expect(inner?["healthy"] as? Bool == true)

    let findings = inner?["findings"] as? [[String: Any]]
    #expect(findings?.count == 1)
    #expect(findings?[0]["severity"] as? String == "warning")
    #expect(findings?[0]["code"] as? String == "staleHostState")
    #expect(findings?[0]["message"] as? String == "Host is stale")
    #expect(findings?[0]["fix"] as? String == "Restart host")
  }

  @Test("list JSON data encodes preview entries")
  func listJSONDataEncodesEntries() throws {
    let data = ListJSONData(
      previewCount: 2,
      previews: [
        ListJSONEntry(name: "Dashboard", filePath: "DashboardView.swift"),
        ListJSONEntry(name: "Settings", filePath: "SettingsView.swift"),
      ]
    )
    let json = JSONOutput.success(command: "list", data: data)
    let parsed = try decode(json)
    let inner = parsed["data"] as? [String: Any]

    #expect(inner?["previewCount"] as? Int == 2)
    let previews = inner?["previews"] as? [[String: Any]]
    #expect(previews?.count == 2)
    #expect(previews?[0]["name"] as? String == "Dashboard")
  }

  @Test("render JSON data encodes image paths and metadata")
  func renderJSONDataEncodesFields() throws {
    let data = RenderJSONData(
      viewName: "Dashboard",
      matchedPreviews: ["Dashboard", "Dashboard - Empty"],
      imagePaths: ["/tmp/.snapview/Dashboard.png", "/tmp/.snapview/Dashboard_-_Empty.png"],
      elapsed: "1.2",
      usedRuntimeFallback: false,
      warnings: []
    )
    let json = JSONOutput.success(command: "render", data: data)
    let parsed = try decode(json)
    let inner = parsed["data"] as? [String: Any]

    #expect(inner?["viewName"] as? String == "Dashboard")
    #expect((inner?["matchedPreviews"] as? [String])?.count == 2)
    #expect((inner?["imagePaths"] as? [String])?.count == 2)
    #expect(inner?["elapsed"] as? String == "1.2")
    #expect(inner?["usedRuntimeFallback"] as? Bool == false)
  }

  @Test("render-all JSON data encodes fields")
  func renderAllJSONDataEncodesFields() throws {
    let data = RenderAllJSONData(
      previewCount: 3,
      imagePaths: ["/a.png", "/b.png", "/c.png"],
      elapsed: "4.5"
    )
    let json = JSONOutput.success(command: "render-all", data: data)
    let parsed = try decode(json)
    let inner = parsed["data"] as? [String: Any]

    #expect(inner?["previewCount"] as? Int == 3)
    #expect((inner?["imagePaths"] as? [String])?.count == 3)
    #expect(inner?["elapsed"] as? String == "4.5")
  }

  @Test("host status JSON data encodes running state")
  func hostStatusJSONDataEncodesFields() throws {
    let data = HostStatusJSONData(running: true, pid: 12345, logPath: "/tmp/host.log")
    let json = JSONOutput.success(command: "host status", data: data)
    let parsed = try decode(json)
    let inner = parsed["data"] as? [String: Any]

    #expect(inner?["running"] as? Bool == true)
    #expect(inner?["pid"] as? Int == 12345)
    #expect(inner?["logPath"] as? String == "/tmp/host.log")
  }

  @Test("host start JSON data encodes decision and pid")
  func hostStartJSONDataEncodesFields() throws {
    let data = HostStartJSONData(decision: "start", pid: 999, logPath: "/tmp/host.log")
    let json = JSONOutput.success(command: "host start", data: data)
    let parsed = try decode(json)
    let inner = parsed["data"] as? [String: Any]

    #expect(inner?["decision"] as? String == "start")
    #expect(inner?["pid"] as? Int == 999)
  }

  @Test("host stop JSON data encodes stopped flag")
  func hostStopJSONDataEncodesFields() throws {
    let data = HostStopJSONData(stopped: true, reason: nil)
    let json = JSONOutput.success(command: "host stop", data: data)
    let parsed = try decode(json)
    let inner = parsed["data"] as? [String: Any]

    #expect(inner?["stopped"] as? Bool == true)
  }

  @Test("prepare JSON data encodes fields")
  func prepareJSONDataEncodesFields() throws {
    let data = PrepareJSONData(
      scheme: "MyApp",
      testTarget: "MyAppTests",
      xctestrunPath: "/tmp/MyAppTests.xctestrun",
      preparedAt: Date(timeIntervalSince1970: 0)
    )
    let json = JSONOutput.success(command: "prepare", data: data)
    let parsed = try decode(json)
    let inner = parsed["data"] as? [String: Any]

    #expect(inner?["scheme"] as? String == "MyApp")
    #expect(inner?["testTarget"] as? String == "MyAppTests")
    #expect(inner?["xctestrunPath"] as? String == "/tmp/MyAppTests.xctestrun")
  }

  @Test("init JSON data encodes fields")
  func initJSONDataEncodesFields() throws {
    let data = InitJSONData(projectPath: "/tmp/App.xcodeproj", testTarget: "AppTests")
    let json = JSONOutput.success(command: "init", data: data)
    let parsed = try decode(json)
    let inner = parsed["data"] as? [String: Any]

    #expect(inner?["projectPath"] as? String == "/tmp/App.xcodeproj")
    #expect(inner?["testTarget"] as? String == "AppTests")
  }

  @Test("gallery JSON data encodes fields")
  func galleryJSONDataEncodesFields() throws {
    let data = GalleryJSONData(pagePath: "/tmp/.snapview/gallery.html", regenerated: true)
    let json = JSONOutput.success(command: "gallery", data: data)
    let parsed = try decode(json)
    let inner = parsed["data"] as? [String: Any]

    #expect(inner?["pagePath"] as? String == "/tmp/.snapview/gallery.html")
    #expect(inner?["regenerated"] as? Bool == true)
  }

  @Test("clean JSON data encodes fields")
  func cleanJSONDataEncodesFields() throws {
    let data = CleanJSONData(removed: true, path: "/tmp/.snapview")
    let json = JSONOutput.success(command: "clean", data: data)
    let parsed = try decode(json)
    let inner = parsed["data"] as? [String: Any]

    #expect(inner?["removed"] as? Bool == true)
    #expect(inner?["path"] as? String == "/tmp/.snapview")
  }

  @Test("output is valid JSON")
  func outputIsValidJSON() throws {
    let json = JSONOutput.success(command: "test", data: SampleData(value: "hello"))
    let data = json.data(using: .utf8)!
    let parsed = try JSONSerialization.jsonObject(with: data)
    #expect(parsed is [String: Any])
  }

  // MARK: - Helpers

  private func decode(_ json: String) throws -> [String: Any] {
    let data = json.data(using: .utf8)!
    let object = try JSONSerialization.jsonObject(with: data)
    return object as! [String: Any]
  }
}

private struct SampleData: Encodable {
  let value: String
}
