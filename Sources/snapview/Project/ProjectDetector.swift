import Foundation

struct ProjectInfo {
  let projectPath: String
  let workspacePath: String?
  let appName: String
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

    return ProjectInfo(
      projectPath: resolvedProject,
      workspacePath: resolvedWorkspace,
      appName: appName,
      testTargetName: testTarget ?? "\(appName)Tests",
      sourceRoot: cwd
    )
  }
}
