import Foundation
import XcodeProj
import PathKit

enum ProjectInjector {

  enum Error: Swift.Error, CustomStringConvertible {
    case testTargetNotFound(String)
    case sourceBuildPhaseNotFound
    case alreadyInitialized

    var description: String {
      switch self {
      case .testTargetNotFound(let name):
        return "[snapview:error] Test target '\(name)' not found in project."
      case .sourceBuildPhaseNotFound:
        return "[snapview:error] No Sources build phase found in test target."
      case .alreadyInitialized:
        return "[snapview:error] snapview is already initialized. SnapViewRenderer.swift exists in test target."
      }
    }
  }

  static func inject(project: ProjectInfo) throws {
    let pbxPath = Path(project.projectPath)
    let xcodeproj = try XcodeProj(path: pbxPath)
    let pbxproj = xcodeproj.pbxproj

    // Find test target
    guard let testTarget = pbxproj.nativeTargets.first(where: { $0.name == project.testTargetName }) else {
      throw Error.testTargetNotFound(project.testTargetName)
    }

    // Check if already initialized
    let existingFiles = try testTarget.sourcesBuildPhase()?.files ?? []
    let alreadyHasRenderer = existingFiles.contains { file in
      file.file?.path?.contains("SnapViewRenderer") == true
    }
    if alreadyHasRenderer { throw Error.alreadyInitialized }

    // Find the test target's source directory
    let testDir = "\(project.sourceRoot)/\(project.testTargetName)"
    let fm = FileManager.default
    if !fm.fileExists(atPath: testDir) {
      try fm.createDirectory(atPath: testDir, withIntermediateDirectories: true)
    }

    // Write files to disk
    let rendererPath = "\(testDir)/SnapViewRenderer.swift"
    let registryPath = "\(testDir)/SnapViewRegistry.swift"

    try RendererTemplate.generate().write(toFile: rendererPath, atomically: true, encoding: .utf8)

    let placeholderRegistry = RegistryGenerator.generate(entries: [], imports: [], appModule: project.appName)
    try placeholderRegistry.write(toFile: registryPath, atomically: true, encoding: .utf8)

    // Add files to test target in pbxproj
    let testGroup: PBXGroup?
    if let existing = pbxproj.groups.first(where: { $0.path == project.testTargetName }) {
      testGroup = existing
    } else {
      testGroup = try pbxproj.rootGroup()?.addGroup(named: project.testTargetName).last
    }

    guard let targetGroup = testGroup else {
      throw Error.sourceBuildPhaseNotFound
    }

    let rendererRef = try targetGroup.addFile(
      at: Path(rendererPath),
      sourceRoot: Path(project.sourceRoot)
    )
    let registryRef = try targetGroup.addFile(
      at: Path(registryPath),
      sourceRoot: Path(project.sourceRoot)
    )

    let sourcePhase = try testTarget.sourcesBuildPhase() ?? testTarget.buildPhases
      .compactMap { $0 as? PBXSourcesBuildPhase }.first

    guard let phase = sourcePhase else {
      throw Error.sourceBuildPhaseNotFound
    }

    _ = try phase.add(file: rendererRef)
    _ = try phase.add(file: registryRef)

    try xcodeproj.write(path: pbxPath)
  }
}
