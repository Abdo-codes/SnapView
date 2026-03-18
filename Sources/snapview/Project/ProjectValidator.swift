import Foundation
import PathKit
import XcodeProj

enum ProjectValidator {

  struct TestTargetBuildSettings: Equatable {
    let generateInfoPlist: Bool
    let infoPlistPath: String?
  }

  enum Error: Swift.Error, CustomStringConvertible {
    case projectFileUnreadable(String)
    case missingTestTarget(String, String)

    var description: String {
      switch self {
      case .projectFileUnreadable(let path):
        return "[snapview:error] Could not read project file at \(path)."
      case .missingTestTarget(let targetName, let scheme):
        return "[snapview:error] Test target '\(targetName)' is not part of this project. Run: snapview init --scheme \(scheme)"
      }
    }
  }

  static func validateRenderPrerequisites(project: ProjectInfo, scheme: String) throws {
    let pbxprojPath = "\(project.projectPath)/project.pbxproj"
    guard let content = try? String(contentsOfFile: pbxprojPath, encoding: .utf8) else {
      throw Error.projectFileUnreadable(pbxprojPath)
    }
    guard hasNativeTarget(named: project.testTargetName, in: content) else {
      throw Error.missingTestTarget(project.testTargetName, scheme)
    }
  }

  static func hasNativeTarget(named targetName: String, in pbxprojContent: String) -> Bool {
    guard
      let start = pbxprojContent.range(of: "/* Begin PBXNativeTarget section */"),
      let end = pbxprojContent.range(of: "/* End PBXNativeTarget section */")
    else {
      return false
    }

    let section = pbxprojContent[start.upperBound..<end.lowerBound]
    return section.contains("/* \(targetName) */ = {")
      || section.contains("name = \(targetName);")
  }

  static func testTargetBuildSettings(project: ProjectInfo) throws -> TestTargetBuildSettings {
    let projectPath = project.projectPath

    do {
      let xcodeproj = try XcodeProj(path: Path(projectPath))
      guard let target = xcodeproj.pbxproj.nativeTargets.first(where: { $0.name == project.testTargetName }) else {
        throw Error.missingTestTarget(project.testTargetName, project.appName)
      }

      let configurations = target.buildConfigurationList?.buildConfigurations ?? []
      let generateInfoPlist = configurations.contains {
        buildSettingString($0.buildSettings["GENERATE_INFOPLIST_FILE"]) == "YES"
      }
      let infoPlistPath = configurations.compactMap {
        buildSettingString($0.buildSettings["INFOPLIST_FILE"])
      }.first(where: { !$0.isEmpty })

      return TestTargetBuildSettings(
        generateInfoPlist: generateInfoPlist,
        infoPlistPath: infoPlistPath
      )
    } catch let error as Error {
      throw error
    } catch {
      throw Error.projectFileUnreadable(projectPath)
    }
  }

  static func infoPlistFinding(
    buildSettings: TestTargetBuildSettings,
    testTargetName: String
  ) -> HealthFinding? {
    guard !hasGeneratedOrExplicitInfoPlist(buildSettings) else {
      return nil
    }

    return HealthFinding(
      severity: .error,
      code: .missingTestTargetInfoPlist,
      message: "Test target '\(testTargetName)' has no generated or explicit Info.plist.",
      fix: "Set GENERATE_INFOPLIST_FILE = YES or provide INFOPLIST_FILE for \(testTargetName)."
    )
  }

  static func hasGeneratedOrExplicitInfoPlist(_ buildSettings: TestTargetBuildSettings) -> Bool {
    buildSettings.generateInfoPlist || buildSettings.infoPlistPath != nil
  }

  private static func buildSettingString(_ value: Any?) -> String? {
    if let string = value as? String {
      return string
    }

    if let bool = value as? Bool {
      return bool ? "YES" : "NO"
    }

    return nil
  }
}
