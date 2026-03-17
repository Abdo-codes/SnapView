// Tests/SnapviewTests/PreviewMatcherTests.swift
import Foundation
import Testing
@testable import snapview

@Suite("PreviewMatcher")
struct PreviewMatcherTests {

  let entries: [PreviewEntry] = [
    PreviewEntry(name: "Welcome", body: "OnboardingView(store: ...)", filePath: "OnboardingView.swift"),
    PreviewEntry(name: "Features", body: "OnboardingView(store: ...)", filePath: "OnboardingView.swift"),
    PreviewEntry(name: "Dark Mode", body: "SettingsView(store: ...)", filePath: "SettingsView.swift"),
    PreviewEntry(name: "HistoryView", body: "HistoryView(store: ...)", filePath: "HistoryView.swift"),
  ]

  @Test("matches by filename")
  func matchByFilename() {
    let matched = PreviewMatcher.match(viewName: "OnboardingView", entries: entries)
    #expect(matched.count == 2)
    #expect(matched[0].name == "Welcome")
    #expect(matched[1].name == "Features")
  }

  @Test("matches by body content when filename doesn't match")
  func matchByBody() {
    // filePath is "Settings.swift" not "SettingsView.swift" — forces body fallback
    let entriesWithDifferentFilename: [PreviewEntry] = [
      PreviewEntry(name: "Dark Mode", body: "SettingsView(store: ...)", filePath: "Settings.swift"),
    ]
    let matched = PreviewMatcher.match(viewName: "SettingsView", entries: entriesWithDifferentFilename)
    #expect(matched.count == 1)
    #expect(matched[0].name == "Dark Mode")
  }

  @Test("matches by exact preview name as last resort")
  func matchByPreviewName() {
    let matched = PreviewMatcher.match(viewName: "Dark Mode", entries: entries)
    #expect(matched.count == 1)
    #expect(matched[0].name == "Dark Mode")
  }

  @Test("returns empty when no match")
  func noMatch() {
    let matched = PreviewMatcher.match(viewName: "NonexistentView", entries: entries)
    #expect(matched.isEmpty)
  }

  @Test("matches filename case-insensitively")
  func caseInsensitiveFilename() {
    let matched = PreviewMatcher.match(viewName: "onboardingview", entries: entries)
    #expect(matched.count == 2)
    #expect(matched.allSatisfy { $0.filePath == "OnboardingView.swift" })
  }

  @Test("matches when view name is a substring of the filename")
  func substringFilenameMatch() {
    let matched = PreviewMatcher.match(viewName: "View", entries: entries)
    // All entries whose filename contains "View" (case-insensitive) are returned
    #expect(!matched.isEmpty)
    #expect(matched.allSatisfy {
      URL(filePath: $0.filePath)
        .deletingPathExtension().lastPathComponent
        .localizedCaseInsensitiveContains("View")
    })
  }

  @Test("returns empty for empty entries")
  func emptyEntries() {
    let matched = PreviewMatcher.match(viewName: "Foo", entries: [])
    #expect(matched.isEmpty)
  }

  @Test("empty view name matches all entries via substring")
  func emptyViewName() {
    // An empty string is a substring of every string, so all entries match by filename
    let matched = PreviewMatcher.match(viewName: "", entries: entries)
    #expect(matched.count == entries.count)
  }

  @Test("body match requires constructor call — comment without parenthesis is ignored")
  func bodyMatchIgnoresNonConstructorOccurrences() {
    let commentOnly: [PreviewEntry] = [
      PreviewEntry(name: "Settings", body: "// SettingsView is great", filePath: "Other.swift"),
    ]
    let matched = PreviewMatcher.match(viewName: "SettingsView", entries: commentOnly)
    #expect(matched.isEmpty)
  }
}
