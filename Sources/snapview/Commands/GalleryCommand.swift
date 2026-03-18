import ArgumentParser
import Foundation

struct GalleryCommand: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "gallery",
    abstract: "Print or regenerate the local gallery page path."
  )

  @Option(name: .long) var project: String?
  @Option(name: .long) var workspace: String?
  @Option(name: .long) var testTarget: String?

  func run() throws {
    let projectInfo = try ProjectDetector.detect(
      projectPath: project,
      workspacePath: workspace,
      testTarget: testTarget
    )
    let pagePath = GalleryStore.pagePath(sourceRoot: projectInfo.sourceRoot)
    var regenerated = false

    if !FileManager.default.fileExists(atPath: pagePath) {
      let state = try GalleryStore.load(sourceRoot: projectInfo.sourceRoot)
      try GalleryStore.writePage(for: state, sourceRoot: projectInfo.sourceRoot)
      regenerated = true
    }

    print(GalleryCommandRenderer.render(pagePath: pagePath, regenerated: regenerated))
  }
}

enum GalleryCommandRenderer {
  static func render(pagePath: String, regenerated: Bool) -> String {
    if regenerated {
      return """
      Gallery regenerated from .snapview/gallery.json.
      Gallery: \(pagePath)
      """
    }

    return "Gallery: \(pagePath)"
  }
}
