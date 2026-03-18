import Foundation
import Testing
@testable import snapview

@Suite("GalleryStore")
struct GalleryStoreTests {

  @Test("round-trips gallery manifest state")
  func galleryStoreRoundTripsManifest() throws {
    let tempRoot = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer { try? FileManager.default.removeItem(at: tempRoot) }

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

    try GalleryStore.save(state, sourceRoot: tempRoot.path)
    let loaded = try GalleryStore.load(sourceRoot: tempRoot.path)

    #expect(loaded == state)
  }
}
