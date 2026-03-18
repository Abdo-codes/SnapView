import Foundation

struct FinalizedRenderOutput: Equatable {
  let outputDirectory: String
  let imagePaths: [String]
  let usedRuntimeFallback: Bool
  let warnings: [String]
}

enum RenderedOutputFinalizer {
  static func finalize(
    renderedOutputPath: String,
    outputDir: String,
    extractor: (String, String) throws -> [String] = PNGExtractor.extract(from:to:)
  ) throws -> FinalizedRenderOutput {
    do {
      return FinalizedRenderOutput(
        outputDirectory: outputDir,
        imagePaths: try extractor(renderedOutputPath, outputDir),
        usedRuntimeFallback: false,
        warnings: []
      )
    } catch {
      let runtimePaths = try runtimePNGPaths(in: renderedOutputPath)
      guard !runtimePaths.isEmpty else {
        throw error
      }
      return FinalizedRenderOutput(
        outputDirectory: renderedOutputPath,
        imagePaths: runtimePaths,
        usedRuntimeFallback: true,
        warnings: [error.localizedDescription]
      )
    }
  }

  private static func runtimePNGPaths(in renderedOutputPath: String) throws -> [String] {
    let renderedURL = URL(filePath: renderedOutputPath)
    let pngs = try FileManager.default.contentsOfDirectory(atPath: renderedOutputPath)
      .filter { $0.hasSuffix(".png") }
      .sorted()
    return pngs.map { renderedURL.appendingPathComponent($0).path(percentEncoded: false) }
  }
}
