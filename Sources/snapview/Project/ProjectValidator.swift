import Foundation
import PathKit
import XcodeProj

enum ProjectValidator {

  struct TestTargetBuildSettings: Equatable {
    struct Configuration: Equatable {
      let name: String
      let generateInfoPlist: Bool?
      let infoPlistPath: String?
    }

    let configurations: [Configuration]

    init(configurations: [Configuration]) {
      self.configurations = configurations
    }

    init(generateInfoPlist: Bool, infoPlistPath: String?) {
      self.configurations = [
        Configuration(
          name: "Default",
          generateInfoPlist: generateInfoPlist,
          infoPlistPath: infoPlistPath
        )
      ]
    }
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

  static func testTargetBuildSettings(
    project: ProjectInfo,
    scheme: String? = nil
  ) throws -> TestTargetBuildSettings {
    let projectPath = project.projectPath

    do {
      let xcodeproj = try XcodeProj(path: Path(projectPath))
      guard let target = xcodeproj.pbxproj.nativeTargets.first(where: { $0.name == project.testTargetName }) else {
        throw Error.missingTestTarget(project.testTargetName, scheme ?? project.appName)
      }

      let configurations = (target.buildConfigurationList?.buildConfigurations ?? []).map { config in
        TestTargetBuildSettings.Configuration(
          name: config.name,
          generateInfoPlist: buildSettingBool(config.buildSettings["GENERATE_INFOPLIST_FILE"]),
          infoPlistPath: buildSettingString(config.buildSettings["INFOPLIST_FILE"])
        )
      }

      return TestTargetBuildSettings(
        configurations: configurations
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
    let invalidConfigurations = buildSettings.configurations.filter { configuration in
      if hasGeneratedOrExplicitInfoPlist(configuration) {
        return false
      }
      return configuration.generateInfoPlist == false
    }

    guard !invalidConfigurations.isEmpty else {
      return nil
    }

    let names = invalidConfigurations.map(\.name).joined(separator: ", ")

    return HealthFinding(
      severity: .error,
      code: .missingTestTargetInfoPlist,
      message: "Test target '\(testTargetName)' has no generated or explicit Info.plist in: \(names).",
      fix: "Set GENERATE_INFOPLIST_FILE = YES or provide INFOPLIST_FILE for \(testTargetName)."
    )
  }

  static func hasGeneratedOrExplicitInfoPlist(_ buildSettings: TestTargetBuildSettings) -> Bool {
    buildSettings.configurations.allSatisfy(hasGeneratedOrExplicitInfoPlist)
  }

  static func hasGeneratedOrExplicitInfoPlist(
    _ configuration: TestTargetBuildSettings.Configuration
  ) -> Bool {
    configuration.generateInfoPlist == true
      || (configuration.infoPlistPath?.isEmpty == false)
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

  private static func buildSettingBool(_ value: Any?) -> Bool? {
    if let bool = value as? Bool {
      return bool
    }

    if let string = buildSettingString(value)?.uppercased() {
      switch string {
      case "YES":
        return true
      case "NO":
        return false
      default:
        return nil
      }
    }

    return nil
  }
}
