import ArgumentParser
import Foundation

struct DoctorCommand: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "doctor",
    abstract: "Inspect project health for snapview rendering prerequisites."
  )

  @Option(name: .long, help: "Xcode scheme to inspect.")
  var scheme: String

  @Option(name: .long) var project: String?
  @Option(name: .long) var workspace: String?
  @Option(name: .long) var testTarget: String?

  func run() throws {
    let projectInfo = try ProjectDetector.detect(
      projectPath: project,
      workspacePath: workspace,
      testTarget: testTarget
    )
    let previewEntries = RenderCommand.scanProject(
      sourceRoot: projectInfo.sourceRoot,
      appName: projectInfo.appName
    )
    let preparedState = try PreparationStore.loadIfPresent(sourceRoot: projectInfo.sourceRoot)
    let hostState = try HostStore.loadIfPresent(sourceRoot: projectInfo.sourceRoot)
    let outputWritable = Self.isOutputWritable(sourceRoot: projectInfo.sourceRoot)

    let health: ProjectHealth
    do {
      let buildSettings = try ProjectValidator.testTargetBuildSettings(project: projectInfo)
      health = try DoctorRunner.run(
        project: projectInfo,
        scheme: scheme,
        previewEntries: previewEntries,
        buildSettings: buildSettings,
        preparedState: preparedState,
        hostState: hostState,
        outputWritable: outputWritable
      )
    } catch ProjectValidator.Error.missingTestTarget(let targetName, _) {
      health = ProjectHealth(
        project: projectInfo,
        scheme: scheme,
        previewCount: previewEntries.count,
        outputWritable: outputWritable,
        findings: [
          .init(
            severity: .error,
            code: .missingTestTarget,
            message: "Test target '\(targetName)' is not part of this project.",
            fix: "Run: snapview init --scheme \(scheme)"
          )
        ]
      )
    }

    print(DoctorCommandRenderer.render(health))
  }

  private static func isOutputWritable(sourceRoot: String) -> Bool {
    let fm = FileManager.default
    let outputPath = "\(sourceRoot)/.snapview"
    if fm.fileExists(atPath: outputPath) {
      return fm.isWritableFile(atPath: outputPath)
    }
    return fm.isWritableFile(atPath: sourceRoot)
  }
}

enum DoctorCommandRenderer {
  static func render(_ health: ProjectHealth) -> String {
    guard !health.findings.isEmpty else {
      return """
      [ok] snapview doctor found no blocking issues.
      scheme: \(health.scheme)
      previews: \(health.previewCount)
      output: \(health.outputWritable ? "writable" : "runtime fallback")
      """
    }

    var lines = [
      "scheme: \(health.scheme)",
      "previews: \(health.previewCount)",
      "output: \(health.outputWritable ? "writable" : "runtime fallback")",
    ]

    for severity in [HealthFinding.Severity.error, .warning, .info] {
      let findings = health.findings.filter { $0.severity == severity }
      guard !findings.isEmpty else {
        continue
      }

      lines.append("[\(severity.rawValue)]")
      for finding in findings {
        lines.append("- \(finding.message)")
        if let fix = finding.fix {
          lines.append("  fix: \(fix)")
        }
      }
    }

    return lines.joined(separator: "\n")
  }
}
