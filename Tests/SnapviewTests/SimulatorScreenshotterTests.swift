import Foundation
import Testing
@testable import snapview

@Suite("SimulatorScreenshotter")
struct SimulatorScreenshotterTests {

  @Test("capture uses a stable target path")
  func captureUsesStableTargetPath() throws {
    let recorder = SimctlRecorder()
    let screenshotter = SimulatorScreenshotter(run: recorder.run)
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let outputPath = try screenshotter.capture(
      device: "booted",
      screenName: "Settings Screen",
      directory: directory.path
    )

    #expect(outputPath == "\(directory.path)/Settings-Screen.png")
    #expect(recorder.invocations == [
      .init(
        arguments: ["simctl", "io", "booted", "screenshot", "\(directory.path)/Settings-Screen.png"],
        environment: [:]
      )
    ])
  }

  @Test("capture surfaces simctl failures with context")
  func captureSurfacesSimctlFailuresWithContext() throws {
    let screenshotter = SimulatorScreenshotter { _, _ in
      throw SimctlFailure("simctl screenshot failed")
    }
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    #expect(throws: SimulatorScreenshotter.Error.captureFailed(screenName: "Settings Screen", detail: "simctl screenshot failed")) {
      _ = try screenshotter.capture(
        device: "booted",
        screenName: "Settings Screen",
        directory: directory.path
      )
    }
  }
}

private struct SimctlFailure: Swift.Error, CustomStringConvertible {
  let description: String

  init(_ description: String) {
    self.description = description
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
