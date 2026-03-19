import Foundation
import Testing
@testable import snapview

@Suite("GalleryPageGenerator")
struct GalleryPageGeneratorTests {

  @Test("renders self-contained HTML with embedded entry data")
  func galleryPageEmbedsManifestData() throws {
    let state = GalleryState(
      projectPath: "/tmp/App/App.xcodeproj",
      scheme: "App",
      entries: [
        .init(
          previewName: "Dashboard",
          sourceFile: "Features/Dashboard/DashboardView.swift",
          imagePath: "/tmp/runtime/Dashboard.png",
          source: .runtimeFallback,
          warnings: ["copy-back failed"],
          updatedAt: Date(timeIntervalSince1970: 1_710_000_000)
        )
      ]
    )

    let html = try GalleryPageGenerator.render(state: state)

    #expect(html.contains("<html"))
    #expect(html.contains("Dashboard"))
    #expect(html.contains("/tmp/runtime/Dashboard.png"))
    #expect(html.contains("runtimeFallback"))
    #expect(!html.contains("fetch("))
  }
}
