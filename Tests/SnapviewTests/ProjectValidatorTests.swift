import Foundation
import Testing
@testable import snapview

@Suite("ProjectValidator")
struct ProjectValidatorTests {

  @Test("rejects projects that do not include the expected test target")
  func rejectsMissingTestTarget() throws {
    let tempRoot = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let projectDir = tempRoot.appendingPathComponent("Demo.xcodeproj", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: tempRoot) }

    try FileManager.default.createDirectory(at: projectDir, withIntermediateDirectories: true)
    try samplePBXProj(appName: "Demo", includeTestTarget: false)
      .write(to: projectDir.appendingPathComponent("project.pbxproj"), atomically: true, encoding: .utf8)

    let project = ProjectInfo(
      projectPath: projectDir.path,
      workspacePath: nil,
      appName: "Demo",
      moduleName: "Demo",
      testTargetName: "DemoTests",
      sourceRoot: tempRoot.path
    )

    do {
      try ProjectValidator.validateRenderPrerequisites(project: project, scheme: "Demo")
      Issue.record("Expected missing test target failure")
    } catch let error as ProjectValidator.Error {
      switch error {
      case .missingTestTarget(let targetName, let scheme):
        #expect(targetName == "DemoTests")
        #expect(scheme == "Demo")
      case .projectFileUnreadable(let path):
        Issue.record("Unexpected unreadable project file: \(path)")
      @unknown default:
        Issue.record("Unexpected validator error: \(error)")
      }
    } catch {
      Issue.record("Unexpected error: \(error)")
    }
  }

  @Test("accepts projects that include the expected test target")
  func acceptsExistingTestTarget() throws {
    let tempRoot = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let projectDir = tempRoot.appendingPathComponent("Demo.xcodeproj", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: tempRoot) }

    try FileManager.default.createDirectory(at: projectDir, withIntermediateDirectories: true)
    try samplePBXProj(appName: "Demo", includeTestTarget: true)
      .write(to: projectDir.appendingPathComponent("project.pbxproj"), atomically: true, encoding: .utf8)

    let project = ProjectInfo(
      projectPath: projectDir.path,
      workspacePath: nil,
      appName: "Demo",
      moduleName: "Demo",
      testTargetName: "DemoTests",
      sourceRoot: tempRoot.path
    )

    try ProjectValidator.validateRenderPrerequisites(project: project, scheme: "Demo")
  }

  private func samplePBXProj(appName: String, includeTestTarget: Bool) -> String {
    let testTargetBlock = includeTestTarget ? """
            BBB /* \(appName)Tests */ = {
                isa = PBXNativeTarget;
                name = \(appName)Tests;
                productType = "com.apple.product-type.bundle.unit-test";
            };
    """ : ""

    return """
    /* Begin PBXNativeTarget section */
            AAA /* \(appName) */ = {
                isa = PBXNativeTarget;
                name = \(appName);
                productType = "com.apple.product-type.application";
            };
    \(testTargetBlock)
    /* End PBXNativeTarget section */
    """
  }
}
