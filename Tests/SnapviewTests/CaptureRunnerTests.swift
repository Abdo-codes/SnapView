import Foundation
import Testing
@testable import snapview

@Suite("CaptureRunner")
struct CaptureRunnerTests {

  @Test("tries strategies in order and stops at the first success")
  func captureRunnerFallsThroughToDeeplinkAfterPreviewFailure() throws {
    let recorder = CallRecorder()
    let runner = CaptureRunner(
      renderPreview: { previewName in
        recorder.calls.append("preview:\(previewName)")
        throw CaptureRunner.Error.previewFailed("boom")
      },
      openURL: { url in
        recorder.calls.append("deeplink:\(url)")
      },
      launchApp: { arguments, environment, screenName in
        recorder.calls.append("launch:\(screenName):\(arguments):\(environment)")
      },
      takeScreenshot: {
        recorder.calls.append("screenshot")
        return "/tmp/Settings.png"
      },
      finalizeOutput: { path in
        recorder.calls.append("finalize:\(path)")
        return path
      }
    )

    let result = try runner.capture(
      screen: .fixture(
        name: "Settings",
        strategies: [
          .preview(previewName: "Settings"),
          .deeplink(url: "myapp://settings")
        ]
      )
    )

    #expect(result.captureStrategy == .deeplink)
    #expect(
      recorder.calls == [
        "preview:Settings",
        "deeplink:myapp://settings",
        "screenshot",
        "finalize:/tmp/Settings.png"
      ]
    )
  }

  @Test("successful capture results convert into capture gallery entries")
  func captureResultBuildsCaptureGalleryEntry() {
    let result = CaptureResult(
      screenName: "Settings",
      imagePath: "/tmp/Settings.png",
      captureStrategy: .launch,
      warnings: ["launch fallback used"]
    )

    let entry = result.galleryEntry(
      sourceFile: "snapview.capture.json",
      source: .runtimeFallback,
      updatedAt: Date(timeIntervalSince1970: 1_710_000_200)
    )

    #expect(entry.previewName == "Settings")
    #expect(entry.sourceFile == "snapview.capture.json")
    #expect(entry.imagePath == "/tmp/Settings.png")
    #expect(entry.source == .runtimeFallback)
    #expect(entry.renderKind == .capture)
    #expect(entry.captureStrategy == .launch)
    #expect(entry.warnings == ["launch fallback used"])
  }
}

private final class CallRecorder: @unchecked Sendable {
  var calls: [String] = []
}

private extension CaptureScreen {
  static func fixture(name: String, strategies: [CaptureStrategy]) -> Self {
    Self(name: name, strategies: strategies)
  }
}
