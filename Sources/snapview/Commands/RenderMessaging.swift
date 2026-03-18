import Foundation

enum RenderMessaging {
  static func previewNotFound(viewName: String) -> String {
    "[snapview:error] No #Preview found for \"\(viewName)\" in project sources. snapview only renders #Preview-backed views. Add a #Preview for that screen or run: snapview list"
  }

  static func noPreviewsFound() -> String {
    "[snapview:error] No #Preview blocks found in project. render-all only renders discovered previews. Add #Preview blocks to the screens you want to render."
  }

  static func noPreviewsFoundList() -> String {
    "No #Preview blocks found. snapview only renders #Preview-backed views. Add #Preview blocks, then run snapview list again."
  }
}
