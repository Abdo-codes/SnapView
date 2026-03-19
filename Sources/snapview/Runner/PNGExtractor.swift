import Foundation

enum PNGExtractor {

  static func extract(to outputDir: String) throws -> [String] {
    try extract(from: "/tmp/snapview/output", to: outputDir)
  }

  static func extract(from sourcePath: String, to outputDir: String) throws -> [String] {
    let fm = FileManager.default
    let sourceURL = URL(filePath: sourcePath)
    let outputURL = URL(filePath: outputDir)

    if !fm.fileExists(atPath: outputDir) {
      try fm.createDirectory(atPath: outputDir, withIntermediateDirectories: true)
    }

    // Write .gitignore if not present
    let gitignorePath = "\(outputDir)/.gitignore"
    if !fm.fileExists(atPath: gitignorePath) {
      try "*\n".write(toFile: gitignorePath, atomically: true, encoding: .utf8)
    }

    let contents = try fm.contentsOfDirectory(atPath: sourcePath)
    let pngs = contents.filter { $0.hasSuffix(".png") }

    var outputPaths: [String] = []
    for png in pngs {
      let src = sourceURL.appendingPathComponent(png)
      let dst = outputURL.appendingPathComponent(png)
      let data = try Data(contentsOf: src)
      try data.write(to: dst)
      outputPaths.append(dst.path(percentEncoded: false))
    }

    return outputPaths.sorted()
  }
}
