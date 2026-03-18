import Foundation
import Testing
@testable import snapview

@Suite("RenderedOutputFinalizer")
struct RenderedOutputFinalizerTests {

  @Test("reuses runtime PNGs when extraction fails")
  func reusesRuntimeOutputOnExtractionFailure() throws {
    let root = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let rendered = root.appendingPathComponent("runtime", isDirectory: true)
    try FileManager.default.createDirectory(at: rendered, withIntermediateDirectories: true)
    let png = rendered.appendingPathComponent("Welcome.png")
    try Data("image".utf8).write(to: png)

    let result = try RenderedOutputFinalizer.finalize(
      renderedOutputPath: rendered.path(percentEncoded: false),
      outputDir: rendered.appendingPathComponent("blocked").path(percentEncoded: false),
      extractor: { _, _ in throw CocoaError(.fileWriteNoPermission) }
    )

    switch result {
    case .copied:
      Issue.record("Expected runtime reuse fallback")
    case let .reused(paths, error):
      #expect(paths == [png.path(percentEncoded: false)])
      #expect(error is CocoaError)
    }
  }

  @Test("returns copied paths when extraction succeeds")
  func returnsCopiedPaths() throws {
    let result = try RenderedOutputFinalizer.finalize(
      renderedOutputPath: "/tmp/rendered",
      outputDir: "/tmp/output",
      extractor: { _, _ in ["/tmp/output/Welcome.png"] }
    )

    switch result {
    case let .copied(paths):
      #expect(paths == ["/tmp/output/Welcome.png"])
    case .reused:
      Issue.record("Expected copied result")
    }
  }
}
