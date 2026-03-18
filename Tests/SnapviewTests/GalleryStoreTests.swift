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
          renderKind: .capture,
          captureStrategy: .deeplink,
          warnings: ["copy-back failed"],
          updatedAt: Date(timeIntervalSince1970: 1_710_000_000)
        )
      ]
    )

    try GalleryStore.save(state, sourceRoot: tempRoot.path)
    let loaded = try GalleryStore.load(sourceRoot: tempRoot.path)

    #expect(loaded == state)
  }

  @Test("upserts rendered entries and regenerates gallery page")
  func upsertsEntriesAndWritesGalleryPage() throws {
    let tempRoot = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer { try? FileManager.default.removeItem(at: tempRoot) }

    let existing = GalleryState(
      projectPath: "/tmp/App/App.xcodeproj",
      scheme: "App",
      entries: [
        .init(
          previewName: "Settings",
          sourceFile: "Features/Settings/SettingsView.swift",
          imagePath: "/tmp/runtime/Settings.png",
          source: .copied,
          renderKind: .preview,
          captureStrategy: nil,
          warnings: [],
          updatedAt: Date(timeIntervalSince1970: 1_710_000_000)
        )
      ]
    )
    try GalleryStore.save(existing, sourceRoot: tempRoot.path)

    let updated = try GalleryStore.persist(
      entries: [
        .init(
          previewName: "Dashboard",
          sourceFile: "Features/Dashboard/DashboardView.swift",
          imagePath: "/tmp/runtime/Dashboard.png",
          source: .runtimeFallback,
          renderKind: .capture,
          captureStrategy: .launch,
          warnings: ["copy-back failed"],
          updatedAt: Date(timeIntervalSince1970: 1_710_000_100)
        )
      ],
      projectPath: "/tmp/App/App.xcodeproj",
      scheme: "App",
      sourceRoot: tempRoot.path
    )

    #expect(updated.entries.count == 2)
    #expect(updated.entries.first(where: { $0.previewName == "Dashboard" })?.renderKind == .capture)
    #expect(updated.entries.first(where: { $0.previewName == "Dashboard" })?.captureStrategy == .launch)
    #expect(updated.entries.first(where: { $0.previewName == "Settings" })?.renderKind == .preview)
    #expect(updated.entries.first(where: { $0.previewName == "Settings" })?.captureStrategy == nil)
    let html = try String(contentsOfFile: GalleryStore.pagePath(sourceRoot: tempRoot.path))
    #expect(html.contains("Dashboard"))
    #expect(html.contains("Settings"))
  }
}
