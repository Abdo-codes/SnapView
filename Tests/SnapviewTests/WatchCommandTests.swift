import Foundation
import Testing
@testable import snapview

@Suite("WatchCommand")
struct WatchCommandTests {

  @Test("stale preparation state is recoverable during watch startup")
  func stalePreparationStateIsRecoverable() {
    let health = ProjectHealth(
      project: .fixture(),
      scheme: "App",
      previewCount: 1,
      outputWritable: true,
      findings: [
        .init(
          severity: .error,
          code: .stalePreparationState,
          message: "Prepared artifacts are stale.",
          fix: "Run: snapview prepare --scheme App"
        )
      ]
    )

    let blocking = WatchCommand.startupBlockingFindings(health)

    #expect(blocking.isEmpty)
  }

  @Test("real project errors still block watch startup")
  func blockingErrorsStillStopWatchStartup() {
    let health = ProjectHealth(
      project: .fixture(),
      scheme: "App",
      previewCount: 0,
      outputWritable: true,
      findings: [
        .init(
          severity: .error,
          code: .missingPreviews,
          message: "No #Preview entries were found.",
          fix: "Add #Preview blocks."
        ),
        .init(
          severity: .warning,
          code: .staleHostState,
          message: "Host is stale.",
          fix: nil
        )
      ]
    )

    let blocking = WatchCommand.startupBlockingFindings(health)

    #expect(blocking.count == 1)
    #expect(blocking.first?.code == .missingPreviews)
  }
}

private extension ProjectInfo {
  static func fixture(
    projectPath: String = "/tmp/App/App.xcodeproj",
    workspacePath: String? = nil,
    appName: String = "App",
    moduleName: String = "App",
    testTargetName: String = "AppTests",
    sourceRoot: String = "/tmp/App"
  ) -> Self {
    ProjectInfo(
      projectPath: projectPath,
      workspacePath: workspacePath,
      appName: appName,
      moduleName: moduleName,
      testTargetName: testTargetName,
      sourceRoot: sourceRoot
    )
  }
}
