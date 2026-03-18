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
  let renderKind: GalleryRenderKind
  let captureStrategy: GalleryCaptureStrategy?
  let warnings: [String]
  let updatedAt: Date

  init(
    previewName: String,
    sourceFile: String,
    imagePath: String,
    source: GalleryImageSource,
    renderKind: GalleryRenderKind = .preview,
    captureStrategy: GalleryCaptureStrategy? = nil,
    warnings: [String],
    updatedAt: Date
  ) {
    self.previewName = previewName
    self.sourceFile = sourceFile
    self.imagePath = imagePath
    self.source = source
    self.renderKind = renderKind
    self.captureStrategy = captureStrategy
    self.warnings = warnings
    self.updatedAt = updatedAt
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    previewName = try container.decode(String.self, forKey: .previewName)
    sourceFile = try container.decode(String.self, forKey: .sourceFile)
    imagePath = try container.decode(String.self, forKey: .imagePath)
    source = try container.decode(GalleryImageSource.self, forKey: .source)
    renderKind = try container.decodeIfPresent(GalleryRenderKind.self, forKey: .renderKind) ?? .preview
    captureStrategy = try container.decodeIfPresent(GalleryCaptureStrategy.self, forKey: .captureStrategy)
    warnings = try container.decode([String].self, forKey: .warnings)
    updatedAt = try container.decode(Date.self, forKey: .updatedAt)
  }
}

enum GalleryImageSource: String, Codable, Equatable {
  case copied
  case runtimeFallback
}

enum GalleryRenderKind: String, Codable, Equatable {
  case preview
  case capture
}

enum GalleryCaptureStrategy: String, Codable, Equatable {
  case preview
  case deeplink
  case launch
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

  @discardableResult
  static func persist(
    entries: [GalleryEntry],
    projectPath: String,
    scheme: String,
    sourceRoot: String,
    mergeWithExisting: Bool = true
  ) throws -> GalleryState {
    let existing = try? load(sourceRoot: sourceRoot)
    let state: GalleryState

    if mergeWithExisting, let existing {
      var merged = Dictionary(uniqueKeysWithValues: existing.entries.map { ($0.previewName, $0) })
      for entry in entries {
        merged[entry.previewName] = entry
      }
      state = GalleryState(
        projectPath: projectPath,
        scheme: scheme,
        entries: merged.values.sorted { $0.previewName < $1.previewName }
      )
    } else {
      state = GalleryState(
        projectPath: projectPath,
        scheme: scheme,
        entries: entries.sorted { $0.previewName < $1.previewName }
      )
    }

    try save(state, sourceRoot: sourceRoot)
    try writePage(for: state, sourceRoot: sourceRoot)
    return state
  }

  static func path(sourceRoot: String) -> String {
    "\(sourceRoot)/.snapview/gallery.json"
  }

  static func pagePath(sourceRoot: String) -> String {
    "\(sourceRoot)/.snapview/gallery.html"
  }

  static func writePage(for state: GalleryState, sourceRoot: String) throws {
    let html = try GalleryPageGenerator.render(state: state)
    try html.write(toFile: pagePath(sourceRoot: sourceRoot), atomically: true, encoding: .utf8)
  }
}
