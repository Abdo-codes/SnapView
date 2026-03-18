import Foundation
import Testing
@testable import snapview

@Suite("BuildRunner")
struct BuildRunnerTests {

  @Test("build failures prefer actionable xcodebuild error lines")
  func buildFailureDescriptionUsesActionableErrorLine() {
    let output = """
    Command line invocation:
        /Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild test-without-building ...

    Build settings from command line:
        CODE_SIGNING_ALLOWED = NO

    2026-03-18 23:56:55.033 xcodebuild[64724:21046819] [MT] IDERunDestination: Supported platforms for the buildables in the current scheme is empty.
    /tmp/App/NotificationClient.swift:11: error: -[DemoTests.SnapViewRenderer test_render] : failed - Unimplemented: 'NotificationClient.cancelAll'
    ** TEST EXECUTE FAILED **
    """

    let description = BuildRunner.Error.buildFailed(65, output).description

    #expect(description.contains("NotificationClient.cancelAll"))
    #expect(!description.contains("Command line invocation"))
  }

  @Test("prefers an iPhone simulator for iOS schemes")
  func prefersIPhoneSimulator() throws {
    let output = """
    Available destinations for the "Demo" scheme:
      { platform:iOS Simulator, id:AAAA, OS:18.2, name:iPad Pro (13-inch) (M4) }
      { platform:iOS Simulator, id:BBBB, OS:18.2, name:iPhone 16 }
    """

    let destination = try BuildRunner.resolveDestination(
      fromShowDestinations: output,
      requestedSimulator: nil
    )

    #expect(destination.platform == "iOS")
    #expect(destination.simulator == "iPhone 16")
    #expect(destination.osVersion == "18.2")
  }

  @Test("uses scheme-specific platform when caller provides a simulator name")
  func usesDetectedPlatformWithRequestedSimulator() throws {
    let output = """
    Available destinations for the "TVApp" scheme:
      { platform:tvOS Simulator, id:CCCC, OS:18.2, name:Apple TV 4K (3rd generation) }
    """

    let destination = try BuildRunner.resolveDestination(
      fromShowDestinations: output,
      requestedSimulator: "Living Room TV"
    )

    #expect(destination.platform == "tvOS")
    #expect(destination.simulator == "Living Room TV")
    #expect(destination.osVersion == nil)
  }

  @Test("preserves OS version from showdestinations output")
  func preservesOSVersion() throws {
    let output = """
    Available destinations for the "Tateemi" scheme:
      { platform:iOS Simulator, arch:arm64, id:AAAA, OS:17.5, name:iPhone 15 }
      { platform:iOS Simulator, arch:arm64, id:BBBB, OS:26.2, name:iPhone 17 }
    """

    let destination = try BuildRunner.resolveDestination(
      fromShowDestinations: output,
      requestedSimulator: "iPhone 15"
    )

    #expect(destination.platform == "iOS")
    #expect(destination.simulator == "iPhone 15")
    #expect(destination.osVersion == "17.5")
    #expect(destination.destinationSpecifier == "platform=iOS Simulator,OS=17.5,name=iPhone 15")
  }

  @Test("fails clearly when no simulator destinations exist")
  func failsWhenNoSimulatorDestinationsExist() {
    let output = """
    Available destinations for the "Broken" scheme:
      { platform:macOS, arch:arm64, variant:Designed for [iPad,iPhone], id:macos, name:My Mac }
    """

    do {
      _ = try BuildRunner.resolveDestination(
        fromShowDestinations: output,
        requestedSimulator: nil
      )
      Issue.record("Expected missing-destination failure")
    } catch let error as BuildRunner.Error {
      switch error {
      case .noSimulatorDestination(let scheme):
        #expect(scheme == "selected scheme")
      default:
        Issue.record("Unexpected BuildRunner error: \(error)")
      }
    } catch {
      Issue.record("Unexpected error: \(error)")
    }
  }
}
