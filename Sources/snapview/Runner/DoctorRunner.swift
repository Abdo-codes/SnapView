import Foundation

enum DoctorRunner {

  static func run(
    project: ProjectInfo,
    scheme: String? = nil,
    previewEntries: [PreviewEntry],
    buildSettings: ProjectValidator.TestTargetBuildSettings,
    preparedState: PreparedRenderState?,
    hostState: HostedRenderState?,
    outputWritable: Bool
  ) throws -> ProjectHealth {
    let expectedScheme = scheme ?? project.appName
    let findings = [
      previewCountFinding(previewEntries: previewEntries, project: project, scheme: expectedScheme),
      ProjectValidator.infoPlistFinding(
        buildSettings: buildSettings,
        testTargetName: project.testTargetName
      ),
      PreparationStore.driftFinding(
        preparedState,
        project: project,
        scheme: expectedScheme
      ),
      HostStore.driftFinding(
        hostState,
        project: project,
        scheme: expectedScheme
      ),
      outputDirectoryFinding(isWritable: outputWritable),
    ].compactMap { $0 }

    return ProjectHealth(
      project: project,
      scheme: expectedScheme,
      previewCount: previewEntries.count,
      outputWritable: outputWritable,
      findings: findings
    )
  }

  private static func previewCountFinding(
    previewEntries: [PreviewEntry],
    project: ProjectInfo,
    scheme: String
  ) -> HealthFinding? {
    guard previewEntries.isEmpty else {
      return nil
    }

    return HealthFinding(
      severity: .error,
      code: .missingPreviews,
      message: "No #Preview entries were found under \(project.appName).",
      fix: "Add #Preview blocks, then run: snapview list --scheme \(scheme)"
    )
  }

  private static func outputDirectoryFinding(isWritable: Bool) -> HealthFinding? {
    guard !isWritable else {
      return nil
    }

    return HealthFinding(
      severity: .warning,
      code: .outputDirectoryNotWritable,
      message: "The output directory is not writable, so snapview will reuse runtime PNGs instead of copying them back.",
      fix: "Choose a writable output path or make .snapview writable."
    )
  }
}
