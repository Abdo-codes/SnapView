import Foundation
import Testing
@testable import snapview

@Suite("BuildRunnerPreparation")
struct BuildRunnerPreparationTests {

  private let project = ProjectInfo(
    projectPath: "/tmp/Demo.xcodeproj",
    workspacePath: nil,
    appName: "Demo",
    moduleName: "Demo",
    testTargetName: "DemoTests",
    sourceRoot: "/tmp/Demo"
  )

  @Test("build-for-testing arguments include derived data and destination")
  func buildForTestingArguments() {
    let destination = BuildRunner.Destination(
      platform: "iOS",
      simulator: "iPhone 15",
      osVersion: "17.5"
    )

    let args = BuildRunner.buildForTestingArguments(
      scheme: "Demo",
      project: project,
      destination: destination,
      derivedDataPath: "/tmp/Demo/.snapview/DerivedData"
    )

    #expect(args.contains("build-for-testing"))
    #expect(args.contains("-derivedDataPath"))
    #expect(args.contains("/tmp/Demo/.snapview/DerivedData"))
    #expect(args.contains(destination.destinationSpecifier))
  }

  @Test("test-without-building arguments include xctestrun and only-testing")
  func testWithoutBuildingArguments() {
    let prepared = PreparedRenderState(
      scheme: "Demo",
      projectPath: "/tmp/Demo.xcodeproj",
      workspacePath: nil,
      testTargetName: "DemoTests",
      destinationSpecifier: "platform=iOS Simulator,OS=17.5,name=iPhone 15",
      derivedDataPath: "/tmp/Demo/.snapview/DerivedData",
      xctestrunPath: "/tmp/Demo/.snapview/DerivedData/Build/Products/Demo_iphonesimulator17.5-arm64.xctestrun",
      preparedAt: Date(timeIntervalSince1970: 1_000)
    )

    let args = BuildRunner.testWithoutBuildingArguments(
      xctestrunPath: prepared.xctestrunPath,
      destinationSpecifier: prepared.destinationSpecifier,
      onlyTesting: "DemoTests/SnapViewRenderer/test_render"
    )

    #expect(args.contains("test-without-building"))
    #expect(args.contains("-xctestrun"))
    #expect(args.contains(prepared.xctestrunPath))
    #expect(args.contains("-destination"))
    #expect(args.contains(prepared.destinationSpecifier))
    #expect(args.contains("-only-testing:DemoTests/SnapViewRenderer/test_render"))
  }

  @Test("finds xctestrun under derived data products")
  func findsXCTestRunFile() throws {
    let tempRoot = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let products = tempRoot.appendingPathComponent("Build/Products", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: tempRoot) }

    try FileManager.default.createDirectory(at: products, withIntermediateDirectories: true)
    let xctestrun = products.appendingPathComponent("Demo_iphonesimulator17.5-arm64.xctestrun")
    try Data().write(to: xctestrun)

    let found = try BuildRunner.findXCTestRun(inDerivedDataPath: tempRoot.path)
    #expect(found == xctestrun.path)
  }
}
