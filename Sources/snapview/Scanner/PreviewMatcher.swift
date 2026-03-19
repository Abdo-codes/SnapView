// Sources/snapview/Scanner/PreviewMatcher.swift
import Foundation

enum PreviewMatcher {
  static func match(viewName: String, entries: [PreviewEntry]) -> [PreviewEntry] {
    // 1. Filename match (primary): files containing the view name
    let byFilename = entries.filter { entry in
      let filename = URL(filePath: entry.filePath).deletingPathExtension().lastPathComponent
      return filename.localizedCaseInsensitiveContains(viewName)
    }
    if !byFilename.isEmpty { return byFilename }

    // 2. Body search fallback: preview body contains "ViewName("
    let byBody = entries.filter { $0.body.contains("\(viewName)(") }
    if !byBody.isEmpty { return byBody }

    // 3. Direct preview name match
    let byName = entries.filter { $0.name == viewName }
    if !byName.isEmpty { return byName }

    return []
  }
}
