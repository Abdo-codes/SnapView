import Testing
@testable import snapview

@Suite("PreviewScanner")
struct PreviewScannerTests {

  @Test("finds named preview")
  func namedPreview() throws {
    let source = """
    import SwiftUI

    struct MyView: View {
      var body: some View { Text("Hello") }
    }

    #Preview("Hello") {
      MyView()
    }
    """
    let results = PreviewScanner.scan(source: source, filePath: "MyView.swift")
    #expect(results.count == 1)
    #expect(results[0].name == "Hello")
    #expect(results[0].body.contains("MyView()"))
    #expect(results[0].filePath == "MyView.swift")
  }

  @Test("finds unnamed preview — uses filename")
  func unnamedPreview() throws {
    let source = """
    #Preview {
      Text("Hi")
    }
    """
    let results = PreviewScanner.scan(source: source, filePath: "FooView.swift")
    #expect(results.count == 1)
    #expect(results[0].name == "FooView")
    #expect(results[0].body.contains("Text(\"Hi\")"))
  }

  @Test("handles nested braces")
  func nestedBraces() throws {
    let source = """
    #Preview("Nested") {
      VStack {
        ForEach(0..<3) { i in
          Text("\\(i)")
        }
      }
    }
    """
    let results = PreviewScanner.scan(source: source, filePath: "Test.swift")
    #expect(results.count == 1)
    #expect(results[0].body.contains("ForEach"))
  }

  @Test("finds multiple previews in one file")
  func multiplePreviews() throws {
    let source = """
    #Preview("One") {
      Text("1")
    }

    #Preview("Two") {
      Text("2")
    }
    """
    let results = PreviewScanner.scan(source: source, filePath: "Test.swift")
    #expect(results.count == 2)
    #expect(results[0].name == "One")
    #expect(results[1].name == "Two")
  }

  @Test("ignores strings containing braces")
  func stringWithBraces() throws {
    let source = """
    #Preview("Braces") {
      Text("{ hello }")
    }
    """
    let results = PreviewScanner.scan(source: source, filePath: "Test.swift")
    #expect(results.count == 1)
    #expect(results[0].body.contains("Text(\"{ hello }\")"))
  }

  @Test("returns empty for no previews")
  func noPreviews() throws {
    let source = "struct Foo: View { var body: some View { Text(\"Hi\") } }"
    let results = PreviewScanner.scan(source: source, filePath: "Foo.swift")
    #expect(results.isEmpty)
  }
}
