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

  // MARK: - Edge case tests

  @Test("line comments in body are handled")
  func lineCommentsInBody() throws {
    let source = """
    #Preview("Commented") {
      Text("hi") // a comment
    }
    """
    let results = PreviewScanner.scan(source: source, filePath: "Test.swift")
    #expect(results.count == 1)
    #expect(results[0].name == "Commented")
    #expect(results[0].body.contains("Text(\"hi\")"))
  }

  @Test("block comments in body are handled")
  func blockCommentsInBody() throws {
    let source = """
    #Preview("Block") {
      /* skip */ Text("hi")
    }
    """
    let results = PreviewScanner.scan(source: source, filePath: "Test.swift")
    #expect(results.count == 1)
    #expect(results[0].name == "Block")
    #expect(results[0].body.contains("Text(\"hi\")"))
  }

  @Test("unclosed brace returns empty")
  func unclosedBrace() throws {
    let source = """
    #Preview("Bad") { VStack { Text("hi") }
    """
    let results = PreviewScanner.scan(source: source, filePath: "Test.swift")
    #expect(results.isEmpty)
  }

  @Test("empty preview body returns entry with empty body")
  func emptyPreviewBody() throws {
    let source = """
    #Preview("Empty") { }
    """
    let results = PreviewScanner.scan(source: source, filePath: "Test.swift")
    #expect(results.count == 1)
    #expect(results[0].name == "Empty")
    #expect(results[0].body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
  }

  @Test("preview name with escaped quotes")
  func escapedQuotesInName() throws {
    let source = """
    #Preview("Say \\"Hello\\"") {
      Text("hi")
    }
    """
    let results = PreviewScanner.scan(source: source, filePath: "Test.swift")
    #expect(results.count == 1)
    #expect(results[0].name.contains("Hello"))
  }

  @Test("lowercase #preview does not match")
  func caseSensitivity() throws {
    let source = """
    #preview {
      Text("hi")
    }
    """
    let results = PreviewScanner.scan(source: source, filePath: "Test.swift")
    #expect(results.isEmpty)
  }

  @Test("deeply nested braces (5 levels) are captured")
  func deepNesting() throws {
    let source = """
    #Preview("Deep") {
      A {
        B {
          C {
            D {
              E {
                Text("deep")
              }
            }
          }
        }
      }
    }
    """
    let results = PreviewScanner.scan(source: source, filePath: "Test.swift")
    #expect(results.count == 1)
    #expect(results[0].body.contains("Text(\"deep\")"))
  }

  @Test("whitespace before #Preview is ignored")
  func whitespaceBeforePreview() throws {
    let source = """
       #Preview("Indented") {
      Text("hi")
    }
    """
    let results = PreviewScanner.scan(source: source, filePath: "Test.swift")
    #expect(results.count == 1)
    #expect(results[0].name == "Indented")
    #expect(results[0].body.contains("Text(\"hi\")"))
  }

  @Test("empty source returns empty array")
  func emptySource() throws {
    let results = PreviewScanner.scan(source: "", filePath: "Test.swift")
    #expect(results.isEmpty)
  }

  @Test("trailing content after preview is not captured in body")
  func trailingContentAfterPreview() throws {
    let source = """
    #Preview("A") {
      Text("a")
    }
    struct Foo {}
    """
    let results = PreviewScanner.scan(source: source, filePath: "Test.swift")
    #expect(results.count == 1)
    #expect(results[0].name == "A")
    #expect(!results[0].body.contains("struct Foo"))
  }
}
