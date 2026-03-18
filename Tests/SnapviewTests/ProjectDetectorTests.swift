import Foundation
import Testing
@testable import snapview

@Suite("ProjectDetector")
struct ProjectDetectorTests {

  @Test("uses the explicit project parent as source root")
  func usesProjectParentAsSourceRoot() throws {
    let root = try makeFixtureRoot()
    defer { try? FileManager.default.removeItem(at: root) }

    let project = root.appendingPathComponent("Demo.xcodeproj", isDirectory: true)
    try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)
    try fixturePBXProj().write(
      to: project.appendingPathComponent("project.pbxproj"),
      atomically: true,
      encoding: .utf8
    )

    let info = try ProjectDetector.detect(
      projectPath: project.path,
      workspacePath: nil,
      testTarget: "DemoTests"
    )

    #expect(info.sourceRoot == root.path)
    #expect(info.projectPath == project.path)
  }

  @Test("uses the explicit workspace parent as source root")
  func usesWorkspaceParentAsSourceRoot() throws {
    let root = try makeFixtureRoot()
    defer { try? FileManager.default.removeItem(at: root) }

    let workspace = root.appendingPathComponent("Demo.xcworkspace", isDirectory: true)
    let project = root.appendingPathComponent("Demo.xcodeproj", isDirectory: true)
    try FileManager.default.createDirectory(at: workspace, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)
    try fixturePBXProj().write(
      to: project.appendingPathComponent("project.pbxproj"),
      atomically: true,
      encoding: .utf8
    )

    let info = try ProjectDetector.detect(
      projectPath: project.path,
      workspacePath: workspace.path,
      testTarget: "DemoTests"
    )

    #expect(info.sourceRoot == root.path)
    #expect(info.workspacePath == workspace.path)
  }

  private func makeFixtureRoot() throws -> URL {
    let root = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    return root
  }

  private func fixturePBXProj() -> String {
    """
    // !$*UTF8*$!
    {
      objects = {
        DEMO = {
          buildSettings = {
            PRODUCT_NAME = Demo;
          };
        };
      };
    }
    """
  }
}
