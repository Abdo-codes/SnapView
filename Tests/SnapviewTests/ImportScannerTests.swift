// Tests/SnapviewTests/ImportScannerTests.swift
import Testing
@testable import snapview

@Suite("ImportScanner")
struct ImportScannerTests {

  @Test("collects standard imports")
  func standardImports() {
    let source = """
    import SwiftUI
    import ComposableArchitecture

    struct MyView: View { }
    """
    let imports = ImportScanner.scan(source: source)
    #expect(imports == ["import SwiftUI", "import ComposableArchitecture"])
  }

  @Test("handles @testable import")
  func testableImport() {
    let source = """
    @testable import MyApp
    import SwiftUI
    """
    let imports = ImportScanner.scan(source: source)
    #expect(imports.contains("@testable import MyApp"))
    #expect(imports.contains("import SwiftUI"))
  }

  @Test("ignores commented imports")
  func commentedImport() {
    let source = """
    import SwiftUI
    // import Foundation
    /* import UIKit */
    """
    let imports = ImportScanner.scan(source: source)
    #expect(imports == ["import SwiftUI"])
  }

  @Test("returns empty for no imports")
  func noImports() {
    let source = "struct Foo { }"
    let imports = ImportScanner.scan(source: source)
    #expect(imports.isEmpty)
  }
}
