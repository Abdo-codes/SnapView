import Foundation

struct ProjectInfo {
  let projectPath: String
  let workspacePath: String?
  let appName: String          // Target/project name (e.g., "Tateemi")
  let moduleName: String       // Swift module name (e.g., "تطعيمي")
  let testTargetName: String
  let sourceRoot: String
}

enum ProjectDetector {

  enum Error: Swift.Error, CustomStringConvertible {
    case noProjectFound
    case multipleProjectsFound([String])

    var description: String {
      switch self {
      case .noProjectFound:
        return "[snapview:error] No .xcodeproj found in current directory. Use --project."
      case .multipleProjectsFound(let paths):
        return "[snapview:error] Multiple .xcodeproj files found: \(paths.joined(separator: ", ")). Use --project to specify."
      }
    }
  }

  static func detect(
    projectPath: String? = nil,
    workspacePath: String? = nil,
    testTarget: String? = nil
  ) throws -> ProjectInfo {
    let fm = FileManager.default
    let cwd = fm.currentDirectoryPath

    let resolvedProject: String
    if let projectPath {
      resolvedProject = projectPath
    } else {
      let contents = try fm.contentsOfDirectory(atPath: cwd)
      let xcodeprojs = contents.filter { $0.hasSuffix(".xcodeproj") }
      guard !xcodeprojs.isEmpty else { throw Error.noProjectFound }
      guard xcodeprojs.count == 1 else { throw Error.multipleProjectsFound(xcodeprojs) }
      resolvedProject = "\(cwd)/\(xcodeprojs[0])"
    }

    let resolvedWorkspace: String?
    if let workspacePath {
      resolvedWorkspace = workspacePath
    } else {
      let contents = try fm.contentsOfDirectory(atPath: cwd)
      resolvedWorkspace = contents
        .first { $0.hasSuffix(".xcworkspace") }
        .map { "\(cwd)/\($0)" }
    }

    let appName = URL(filePath: resolvedProject)
      .deletingPathExtension()
      .lastPathComponent

    // Query the actual Swift module name from xcodebuild
    let moduleName = detectModuleName(
      scheme: appName,
      projectPath: resolvedProject,
      workspacePath: resolvedWorkspace
    )

    return ProjectInfo(
      projectPath: resolvedProject,
      workspacePath: resolvedWorkspace,
      appName: appName,
      moduleName: moduleName,
      testTargetName: testTarget ?? "\(appName)Tests",
      sourceRoot: cwd
    )
  }

  private static func detectModuleName(
    scheme: String,
    projectPath: String,
    workspacePath: String?
  ) -> String {
    // Read PRODUCT_NAME directly from pbxproj — fast, no xcodebuild needed
    let pbxprojPath = "\(projectPath)/project.pbxproj"
    guard let content = try? String(contentsOfFile: pbxprojPath, encoding: .utf8) else {
      return scheme
    }

    // Look for PRODUCT_MODULE_NAME first (explicit override)
    for line in content.components(separatedBy: .newlines) {
      let trimmed = line.trimmingCharacters(in: .whitespaces)
      if trimmed.hasPrefix("PRODUCT_MODULE_NAME = ") {
        let value = trimmed.dropFirst("PRODUCT_MODULE_NAME = ".count)
          .trimmingCharacters(in: CharacterSet(charactersIn: "\";"))
        if !value.isEmpty && !value.contains("$") { return value }
      }
    }

    // Fall back to PRODUCT_NAME from the app target's config
    // Find the first PRODUCT_NAME that isn't $(TARGET_NAME)
    for line in content.components(separatedBy: .newlines) {
      let trimmed = line.trimmingCharacters(in: .whitespaces)
      if trimmed.hasPrefix("PRODUCT_NAME = ") {
        let value = trimmed.dropFirst("PRODUCT_NAME = ".count)
          .trimmingCharacters(in: CharacterSet(charactersIn: "\";"))
        if !value.isEmpty && !value.contains("$") {
          return value
        }
      }
    }

    return scheme
  }
}
