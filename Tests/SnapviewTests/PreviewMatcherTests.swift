// Tests/SnapviewTests/PreviewMatcherTests.swift
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
}
