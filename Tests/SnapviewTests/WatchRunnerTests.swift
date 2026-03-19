import Foundation
import Testing
@testable import snapview

@Suite("WatchRunner")
struct WatchRunnerTests {

  @Test("successful cycle runs prepare host and render in order")
  func successfulCycleRunsRefreshPipeline() throws {
    let stable = FileSnapshot(files: ["DashboardView.swift": Date(timeIntervalSince1970: 1_000)])
    var snapshots = [stable, stable]
    var sleeps: [TimeInterval] = []
    var events: [String] = []
    let prepared = preparedState()

    let runner = WatchRunner(
      snapshot: { snapshots.removeFirst() },
      sleep: { sleeps.append($0) },
      prepare: {
        events.append("prepare")
        return prepared
      },
      ensureHost: { state in
        events.append("host:\(state.scheme)")
      },
      renderAll: { _ in
        events.append("render")
      }
    )

    let outcome = try runner.runSingleIteration()

    #expect(outcome == .rendered)
    #expect(events == ["prepare", "host:Demo", "render"])
    #expect(sleeps == [0.25])
  }

  @Test("change burst is debounced into one refresh cycle")
  func changeBurstDebouncesToSingleRefreshCycle() throws {
    let first = FileSnapshot(files: ["DashboardView.swift": Date(timeIntervalSince1970: 1_000)])
    let second = FileSnapshot(files: ["DashboardView.swift": Date(timeIntervalSince1970: 2_000)])
    var snapshots = [first, second, second]
    var sleeps: [TimeInterval] = []
    var events: [String] = []

    let runner = WatchRunner(
      snapshot: { snapshots.removeFirst() },
      sleep: { sleeps.append($0) },
      prepare: {
        events.append("prepare")
        return preparedState()
      },
      ensureHost: { _ in
        events.append("host")
      },
      renderAll: { _ in
        events.append("render")
      }
    )

    let outcome = try runner.runSingleIteration()

    #expect(outcome == .rendered)
    #expect(events == ["prepare", "host", "render"])
    #expect(sleeps == [0.25, 0.25])
  }

  @Test("no-op cycle does not rerender")
  func noOpCycleDoesNotRerender() throws {
    let stable = FileSnapshot(files: ["DashboardView.swift": Date(timeIntervalSince1970: 1_000)])
    var snapshots = [stable, stable, stable]
    var events: [String] = []

    let runner = WatchRunner(
      snapshot: { snapshots.removeFirst() },
      sleep: { _ in },
      prepare: {
        events.append("prepare")
        return preparedState()
      },
      ensureHost: { _ in
        events.append("host")
      },
      renderAll: { _ in
        events.append("render")
      }
    )

    let firstOutcome = try runner.runSingleIteration()
    let secondOutcome = try runner.runSingleIteration()

    #expect(firstOutcome == .rendered)
    #expect(secondOutcome == .idle)
    #expect(events == ["prepare", "host", "render"])
  }

  @Test("failed cycle is not retried until the snapshot changes")
  func failedCycleWaitsForNextChange() throws {
    let stable = FileSnapshot(files: ["DashboardView.swift": Date(timeIntervalSince1970: 1_000)])
    let changed = FileSnapshot(files: ["DashboardView.swift": Date(timeIntervalSince1970: 2_000)])
    var snapshots = [stable, stable, stable, changed, changed]
    var prepareCalls = 0
    var events: [String] = []

    let runner = WatchRunner(
      snapshot: { snapshots.removeFirst() },
      sleep: { _ in },
      prepare: {
        prepareCalls += 1
        if prepareCalls == 1 {
          throw TestError.prepareFailed
        }
        events.append("prepare")
        return preparedState()
      },
      ensureHost: { _ in
        events.append("host")
      },
      renderAll: { _ in
        events.append("render")
      }
    )

    #expect(throws: TestError.prepareFailed) {
      try runner.runSingleIteration()
    }
    let secondOutcome = try runner.runSingleIteration()
    let thirdOutcome = try runner.runSingleIteration()

    #expect(secondOutcome == .idle)
    #expect(thirdOutcome == .rendered)
    #expect(prepareCalls == 2)
    #expect(events == ["prepare", "host", "render"])
  }

  private func preparedState() -> PreparedRenderState {
    PreparedRenderState(
      scheme: "Demo",
      projectPath: "/tmp/Demo.xcodeproj",
      workspacePath: nil,
      testTargetName: "DemoTests",
      destinationSpecifier: "platform=iOS Simulator,OS=17.5,name=iPhone 15",
      derivedDataPath: "/tmp/Demo/.snapview/DerivedData",
      xctestrunPath: "/tmp/Demo/.snapview/DerivedData/Build/Products/Demo_iphonesimulator17.5-arm64.xctestrun",
      preparedAt: Date(timeIntervalSince1970: 1_000)
    )
  }
}

private enum TestError: Error, Equatable {
  case prepareFailed
}
