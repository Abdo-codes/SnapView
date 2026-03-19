import Foundation
import Testing
@testable import snapview

@Suite("PNGExtractor")
struct PNGExtractorTests {

  @Test("overwrites existing PNGs without deleting the destination first")
  func overwritesExistingFiles() throws {
    let root = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let source = root.appendingPathComponent("source", isDirectory: true)
    let output = root.appendingPathComponent("output", isDirectory: true)

    try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)

    let sourcePNG = source.appendingPathComponent("Welcome.png")
    let outputPNG = output.appendingPathComponent("Welcome.png")

    try Data("new-image".utf8).write(to: sourcePNG)
    try Data("old-image".utf8).write(to: outputPNG)

    let paths = try PNGExtractor.extract(
      from: source.path(percentEncoded: false),
      to: output.path(percentEncoded: false)
    )

    #expect(paths == [outputPNG.path(percentEncoded: false)])
    let finalData = try Data(contentsOf: outputPNG)
    #expect(String(decoding: finalData, as: UTF8.self) == "new-image")
  }
}
