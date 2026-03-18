import Foundation

struct GalleryState: Codable, Equatable {
  let projectPath: String
  let scheme: String
  let entries: [GalleryEntry]
}

struct GalleryEntry: Codable, Equatable {
  let previewName: String
  let sourceFile: String
  let imagePath: String
  let source: GalleryImageSource
  let warnings: [String]
  let updatedAt: Date
}

enum GalleryImageSource: String, Codable, Equatable {
  case copied
  case runtimeFallback
}

enum GalleryStore {
  static func save(_ state: GalleryState, sourceRoot: String) throws {
    let path = path(sourceRoot: sourceRoot)
    let directory = URL(filePath: path).deletingLastPathComponent()
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let data = try encoder.encode(state)
    try data.write(to: URL(filePath: path), options: .atomic)
  }

  static func load(sourceRoot: String) throws -> GalleryState {
    let data = try Data(contentsOf: URL(filePath: path(sourceRoot: sourceRoot)))
    return try JSONDecoder().decode(GalleryState.self, from: data)
  }

  static func path(sourceRoot: String) -> String {
    "\(sourceRoot)/.snapview/gallery.json"
  }
}
