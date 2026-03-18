import Foundation
import Testing
@testable import snapview

@Suite("CaptureManifest")
struct CaptureManifestTests {

  @Test("decodes manifest with ordered preview and deeplink strategies")
  func decodesManifestWithPreviewAndDeeplinkStrategies() throws {
    let manifest = try CaptureManifest.parse(
      Data(
        """
        {
          "appId": "com.example.app",
          "screens": [
            {
              "name": "Settings",
              "strategies": [
                { "type": "preview", "previewName": "Settings" },
                { "type": "deeplink", "url": "myapp://settings" }
              ]
            }
          ]
        }
        """.utf8)
    )

    #expect(manifest.appId == "com.example.app")
    #expect(manifest.screens.count == 1)
    #expect(manifest.screens[0].name == "Settings")
    #expect(manifest.screens[0].strategies == [
      .preview(previewName: "Settings"),
      .deeplink(url: "myapp://settings")
    ])
  }

  @Test("rejects duplicate screen names")
  func rejectsDuplicateScreenNames() {
    #expect(throws: CaptureManifest.Error.duplicateScreenNames(["Settings"])) {
      _ = try CaptureManifest.parse(
        Data(
          """
          {
            "appId": "com.example.app",
            "screens": [
              {
                "name": "Settings",
                "strategies": [
                  { "type": "preview", "previewName": "Settings" }
                ]
              },
              {
                "name": "Settings",
                "strategies": [
                  { "type": "deeplink", "url": "myapp://settings" }
                ]
              }
            ]
          }
          """.utf8)
      )
    }
  }

  @Test("rejects malformed deeplink strategy payloads")
  func rejectsMalformedDeeplinkStrategyPayloads() {
    #expect(throws: CaptureManifest.Error.invalidDeeplinkStrategy(screen: "Settings")) {
      _ = try CaptureManifest.parse(
        Data(
          """
          {
            "appId": "com.example.app",
            "screens": [
              {
                "name": "Settings",
                "strategies": [
                  { "type": "deeplink" }
                ]
              }
            ]
          }
          """.utf8)
      )
    }
  }

  @Test("rejects malformed launch strategy payloads")
  func rejectsMalformedLaunchStrategyPayloads() {
    #expect(throws: CaptureManifest.Error.invalidLaunchStrategy(screen: "Paywall")) {
      _ = try CaptureManifest.parse(
        Data(
          """
          {
            "appId": "com.example.app",
            "screens": [
              {
                "name": "Paywall",
                "strategies": [
                  { "type": "launch" }
                ]
              }
            ]
          }
          """.utf8)
      )
    }
  }
}
