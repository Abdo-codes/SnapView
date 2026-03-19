import ArgumentParser
import Foundation

struct GalleryCommand: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "gallery",
    abstract: "Print the generated gallery page path."
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

    if !FileManager.default.fileExists(atPath: pagePath) {
      let state = try GalleryStore.load(sourceRoot: projectInfo.sourceRoot)
      try GalleryStore.writePage(for: state, sourceRoot: projectInfo.sourceRoot)
    }

    print(pagePath)
  }
}
