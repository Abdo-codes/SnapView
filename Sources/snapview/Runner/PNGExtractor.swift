import Foundation

enum PNGExtractor {

  static func extract(to outputDir: String) throws -> [String] {
    let fm = FileManager.default
    let sourcePath = "/tmp/snapview"

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
      let src = "\(sourcePath)/\(png)"
      let dst = "\(outputDir)/\(png)"
      if fm.fileExists(atPath: dst) { try fm.removeItem(atPath: dst) }
      try fm.copyItem(atPath: src, toPath: dst)
      outputPaths.append(dst)
    }

    return outputPaths.sorted()
  }
}
