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

  @Test("empty entries generates valid registry")
  func emptyEntriesGeneratesValidRegistry() {
    let output = RegistryGenerator.generate(entries: [], imports: ["import SwiftUI"], appModule: "App")
    #expect(output.contains("static let all: [Entry] = ["))
    #expect(output.contains("import SwiftUI"))
    #expect(output.contains("@testable import App"))
    // The all array should be empty — no Entry items
    #expect(!output.contains("Entry(name:"))
  }

  @Test("appModule in imports gets deduplicated")
  func appModuleImportGetsDeduplicated() {
    let imports = ["import SwiftUI", "import Dawasah"]
    let output = RegistryGenerator.generate(entries: [], imports: imports, appModule: "Dawasah")
    #expect(output.contains("@testable import Dawasah"))
    // Plain "import Dawasah" must not appear — only the @testable variant
    let plainImportCount = output.components(separatedBy: "import Dawasah").count - 1
    let testableImportCount = output.components(separatedBy: "@testable import Dawasah").count - 1
    #expect(plainImportCount == testableImportCount)
  }

  @Test("@testable import of appModule gets deduplicated")
  func testableImportOfAppModuleGetsDeduplicated() {
    let imports = ["import SwiftUI", "@testable import Dawasah"]
    let output = RegistryGenerator.generate(entries: [], imports: imports, appModule: "Dawasah")
    let testableCount = output.components(separatedBy: "@testable import Dawasah").count - 1
    #expect(testableCount == 1)
  }

  @Test("multiple entries generate multiple registry items")
  func multipleEntriesGenerateMultipleItems() {
    let entries: [PreviewEntry] = [
      PreviewEntry(name: "Alpha", body: "Text(\"A\")", filePath: "A.swift"),
      PreviewEntry(name: "Beta",  body: "Text(\"B\")", filePath: "B.swift"),
      PreviewEntry(name: "Gamma", body: "Text(\"C\")", filePath: "C.swift"),
    ]
    let output = RegistryGenerator.generate(entries: entries, imports: ["import SwiftUI"], appModule: "App")
    let entryCount = output.components(separatedBy: "Entry(name:").count - 1
    #expect(entryCount == 3)
  }

  @Test("body with multiline code preserves structure")
  func multilineBodyPreservesStructure() {
    let body = "VStack {\n  Text(\"hi\")\n}"
    let entries: [PreviewEntry] = [
      PreviewEntry(name: "MultiLine", body: body, filePath: "Multi.swift"),
    ]
    let output = RegistryGenerator.generate(entries: entries, imports: ["import SwiftUI"], appModule: "App")
    #expect(output.contains("VStack {"))
    #expect(output.contains("Text(\"hi\")"))
  }

  @Test("no imports except SwiftUI still produces required imports")
  func noImportsStillHasRequiredImports() {
    let entries: [PreviewEntry] = [
      PreviewEntry(name: "Solo", body: "EmptyView()", filePath: "Solo.swift"),
    ]
    let output = RegistryGenerator.generate(entries: entries, imports: [], appModule: "App")
    #expect(output.contains("import SwiftUI"))
    #expect(output.contains("@testable import App"))
  }
}
