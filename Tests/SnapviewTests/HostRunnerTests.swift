import Foundation
import Testing
@testable import snapview

@Suite("HostRunner")
struct HostRunnerTests {

  @Test("start arguments use the persistent host test")
  func startArgumentsUseHostTest() {
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

    let args = HostRunner.startArguments(prepared: prepared)

    #expect(args.contains("test-without-building"))
    #expect(args.contains("-xctestrun"))
    #expect(args.contains(prepared.xctestrunPath))
    #expect(args.contains("-destination"))
    #expect(args.contains(prepared.destinationSpecifier))
    #expect(args.contains("-only-testing:DemoTests/SnapViewRenderer/test_host"))
  }
}
