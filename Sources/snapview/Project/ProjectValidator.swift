import Foundation

enum ProjectValidator {

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
}
