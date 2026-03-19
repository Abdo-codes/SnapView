// Tests/SnapviewTests/RegistryGeneratorTests.swift
import Testing
@testable import snapview

@Suite("RegistryGenerator")
struct RegistryGeneratorTests {

  @Test("generates valid registry with imports")
  func generatesRegistry() {
    let entries: [PreviewEntry] = [
      PreviewEntry(name: "Welcome", body: "OnboardingView()", filePath: "OnboardingView.swift"),
    ]
    let imports = ["import SwiftUI", "import ComposableArchitecture"]
    let output = RegistryGenerator.generate(
      entries: entries, imports: imports, appModule: "Dawasah"
    )
    #expect(output.contains("@testable import Dawasah"))
    #expect(output.contains("import ComposableArchitecture"))
    #expect(output.contains("import SwiftUI"))
    #expect(output.contains("Entry(name: \"Welcome\")"))
    #expect(output.contains("OnboardingView()"))
  }

  @Test("deduplicates imports")
  func deduplicatesImports() {
    let imports = ["import SwiftUI", "import SwiftUI", "import Foundation"]
    let output = RegistryGenerator.generate(entries: [], imports: imports, appModule: "Dawasah")
    let swiftUICount = output.components(separatedBy: "import SwiftUI").count - 1
    #expect(swiftUICount == 1)
  }

  @Test("sanitizes entry names for Swift identifiers")
  func sanitizesNames() {
    let entries: [PreviewEntry] = [
      PreviewEntry(name: "Dark Mode", body: "Text(\"hi\")", filePath: "Test.swift"),
    ]
    let output = RegistryGenerator.generate(entries: entries, imports: [], appModule: "App")
    #expect(output.contains("Entry(name: \"Dark Mode\")"))
  }
}
