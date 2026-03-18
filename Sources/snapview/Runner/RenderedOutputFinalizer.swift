import Foundation

enum RenderedOutputFinalizer {
  enum Result {
    case copied([String])
    case reused([String], Error)

    var paths: [String] {
      switch self {
      case let .copied(paths), let .reused(paths, _):
        return paths
      }
    }
  }

  static func finalize(
    renderedOutputPath: String,
    outputDir: String,
    extractor: (String, String) throws -> [String] = PNGExtractor.extract(from:to:)
  ) throws -> Result {
    do {
      return .copied(try extractor(renderedOutputPath, outputDir))
    } catch {
      let runtimePaths = try runtimePNGPaths(in: renderedOutputPath)
      guard !runtimePaths.isEmpty else {
        throw error
      }
      return .reused(runtimePaths, error)
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
