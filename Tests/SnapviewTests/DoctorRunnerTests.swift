import Foundation
import Testing
@testable import snapview

@Suite("DoctorRunner")
struct DoctorRunnerTests {

  @Test("formats grouped doctor findings for CLI output")
  func doctorFormatsGroupedFindings() {
    let text = DoctorCommandRenderer.render(
      .fixture(findings: [
        .init(
          severity: .error,
          code: .missingTestTargetInfoPlist,
          message: "Missing Info.plist",
          fix: "Set GENERATE_INFOPLIST_FILE = YES"
        )
      ])
    )

    #expect(text.contains("[error]"))
    #expect(text.contains("GENERATE_INFOPLIST_FILE"))
  }

  @Test("reports a missing generated Info.plist as a structured error")
  func doctorReportsMissingGeneratedInfoPlist() throws {
    let health = try DoctorRunner.run(
      project: .fixture(
        projectPath: "/tmp/App/App.xcodeproj",
        testTargetName: "AppTests",
        sourceRoot: "/tmp/App"
      ),
      scheme: "App",
      previewEntries: [.fixture(name: "Dashboard")],
      buildSettings: .fixture(generateInfoPlist: false, infoPlistPath: nil),
      preparedState: nil,
      hostState: nil,
      outputWritable: true
    )

    let finding = health.findings.first {
      $0.code == HealthFinding.Code.missingTestTargetInfoPlist
    }
    #expect(finding?.severity == HealthFinding.Severity.error)
  }

  @Test("reports stale preparation metadata as a structured finding")
  func doctorReportsStalePreparationMetadata() throws {
    let health = try DoctorRunner.run(
      project: .fixture(),
      scheme: "App",
      previewEntries: [.fixture(name: "Dashboard")],
      buildSettings: .fixture(),
      preparedState: .fixture(scheme: "Other"),
      hostState: nil,
      outputWritable: true
    )

    let finding = health.findings.first {
      $0.code == HealthFinding.Code.stalePreparationState
    }
    #expect(finding?.severity == HealthFinding.Severity.error)
  }

  @Test("reports missing previews as a structured finding")
  func doctorReportsMissingPreviews() throws {
    let health = try DoctorRunner.run(
      project: .fixture(),
      scheme: "App",
      previewEntries: [],
      buildSettings: .fixture(),
      preparedState: nil,
      hostState: nil,
      outputWritable: true
    )

    #expect(health.findings.contains { $0.code == HealthFinding.Code.missingPreviews })
  }

  @Test("reports stale host metadata as a structured warning")
  func doctorReportsStaleHostMetadata() throws {
    let health = try DoctorRunner.run(
      project: .fixture(),
      scheme: "App",
      previewEntries: [.fixture(name: "Dashboard")],
      buildSettings: .fixture(),
      preparedState: nil,
      hostState: .fixture(scheme: "Other"),
      outputWritable: true
    )

    #expect(
      health.findings.contains {
        $0.code == HealthFinding.Code.staleHostState
          && $0.severity == HealthFinding.Severity.warning
      })
  }

  @Test("downgrades unwritable output fallback to a warning")
  func doctorWarnsWhenOutputDirectoryIsNotWritable() throws {
    let health = try DoctorRunner.run(
      project: .fixture(),
      scheme: "App",
      previewEntries: [.fixture(name: "Dashboard")],
      buildSettings: .fixture(),
      preparedState: nil,
      hostState: nil,
      outputWritable: false
    )

    let finding = health.findings.first {
      $0.code == HealthFinding.Code.outputDirectoryNotWritable
    }
    #expect(finding?.severity == HealthFinding.Severity.warning)
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

private extension HostedRenderState {
  static func fixture(
    scheme: String = "App",
    projectPath: String = "/tmp/App/App.xcodeproj",
    testTargetName: String = "AppTests",
    runtimeDirectory: String = "/tmp/App/.snapview/runtime/host",
    logPath: String = "/tmp/App/.snapview/host.log",
    pid: Int = 42
  ) -> Self {
    HostedRenderState(
      scheme: scheme,
      projectPath: projectPath,
      testTargetName: testTargetName,
      runtimeDirectory: runtimeDirectory,
      logPath: logPath,
      pid: pid
    )
  }
}

private extension PreviewEntry {
  static func fixture(
    name: String = "Dashboard",
    body: String = "DashboardView()",
    filePath: String = "DashboardView.swift"
  ) -> Self {
    PreviewEntry(name: name, body: body, filePath: filePath)
  }
}

private extension PreparedRenderState {
  static func fixture(
    scheme: String = "App",
    projectPath: String = "/tmp/App/App.xcodeproj",
    workspacePath: String? = nil,
    testTargetName: String = "AppTests",
    destinationSpecifier: String = "platform=iOS Simulator,name=iPhone 15",
    derivedDataPath: String = "/tmp/App/.snapview/DerivedData",
    xctestrunPath: String = "/tmp/App/.snapview/AppTests.xctestrun"
  ) -> Self {
    PreparedRenderState(
      scheme: scheme,
      projectPath: projectPath,
      workspacePath: workspacePath,
      testTargetName: testTargetName,
      destinationSpecifier: destinationSpecifier,
      derivedDataPath: derivedDataPath,
      xctestrunPath: xctestrunPath
    )
  }
}

private extension ProjectValidator.TestTargetBuildSettings {
  static func fixture(
    generateInfoPlist: Bool = true,
    infoPlistPath: String? = "AppTests/Info.plist"
  ) -> Self {
    Self(generateInfoPlist: generateInfoPlist, infoPlistPath: infoPlistPath)
  }
}

private extension ProjectHealth {
  static func fixture(
    project: ProjectInfo = .fixture(),
    scheme: String = "App",
    previewCount: Int = 1,
    outputWritable: Bool = true,
    findings: [HealthFinding] = []
  ) -> Self {
    ProjectHealth(
      project: project,
      scheme: scheme,
      previewCount: previewCount,
      outputWritable: outputWritable,
      findings: findings
    )
  }
}
