import ArgumentParser
import Foundation

struct ListCommand: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "list",
    abstract: "List all discovered #Preview blocks that snapview can render."
  )

  @OptionGroup var globalOptions: GlobalOptions

  @Option(name: .long) var project: String?
  @Option(name: .long) var workspace: String?

  func run() throws {
    let projectInfo = try ProjectDetector.detect(
      projectPath: project, workspacePath: workspace
    )
    let entries = RenderCommand.scanProject(
      sourceRoot: projectInfo.sourceRoot, appName: projectInfo.appName
    )

    if globalOptions.json {
      let items = entries.map { ListJSONEntry(name: $0.name, filePath: $0.filePath) }
      let data = ListJSONData(previewCount: entries.count, previews: items)
      print(JSONOutput.success(command: "list", data: data))
      return
    }

    if entries.isEmpty {
      print(RenderMessaging.noPreviewsFoundList())
      return
    }

    print("Found \(entries.count) preview(s):\n")
    let grouped = Dictionary(grouping: entries, by: \.filePath)
    for (file, previews) in grouped.sorted(by: { $0.key < $1.key }) {
      print("  \(file)")
      for preview in previews {
        print("    - \(preview.name)")
      }
    }
  }
}

struct ListJSONEntry: Encodable {
  let name: String
  let filePath: String
}

struct ListJSONData: Encodable {
  let previewCount: Int
  let previews: [ListJSONEntry]
}
