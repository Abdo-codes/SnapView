import Foundation
import Testing
@testable import snapview

@Suite("SimulatorController")
struct SimulatorControllerTests {

  @Test("open URL shells out through simctl")
  func openURLShellsOutThroughSimctl() throws {
    let recorder = SimctlRecorder()
    let controller = SimulatorController(run: recorder.run)

    try controller.openURL("myapp://settings", device: "booted")

    #expect(recorder.invocations == [
      .init(arguments: ["simctl", "openurl", "booted", "myapp://settings"], environment: [:])
    ])
  }

  @Test("launch builds expected simctl arguments")
  func launchBuildsExpectedSimctlArguments() throws {
    let recorder = SimctlRecorder()
    let controller = SimulatorController(run: recorder.run)

    try controller.launch(
      appId: "com.example.app",
      device: "booted",
      arguments: ["--ui-test-screen", "paywall"],
      environment: ["SNAPVIEW_CAPTURE": "1", "LANG": "en_US"]
    )

    #expect(recorder.invocations == [
      .init(
        arguments: [
          "simctl", "launch",
          "--env", "LANG=en_US",
          "--env", "SNAPVIEW_CAPTURE=1",
          "booted", "com.example.app",
          "--ui-test-screen", "paywall",
        ],
        environment: [:]
      )
    ])
  }
}

private final class SimctlRecorder {
  struct Invocation: Equatable {
    let arguments: [String]
    let environment: [String: String]
  }

  private(set) var invocations: [Invocation] = []

  func run(arguments: [String], environment: [String: String]) throws {
    invocations.append(.init(arguments: arguments, environment: environment))
  }
}
