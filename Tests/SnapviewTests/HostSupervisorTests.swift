import Foundation
import Testing
@testable import snapview

@Suite("HostSupervisor")
struct HostSupervisorTests {

  @Test("stale prepared host runtime requires restart")
  func stalePreparedHostRuntimeRequiresRestart() {
    let prepared = preparedState()
    let staleHost = hostState(runtimeDirectory: "/tmp/old-runtime", pid: 101)

    let decision = HostSupervisor.restartDecision(
      prepared: prepared,
      host: staleHost,
      isHostActive: true
    )

    #expect(decision == .restart)
  }

  @Test("changed prepared artifacts require restart even with matching runtime directory")
  func changedPreparedArtifactsRequireRestart() {
    let prepared = preparedState(xctestrunPath: "/tmp/new.xctestrun")
    let matchingRuntime = HostRuntime.hostRuntimeDirectory(for: prepared)
    let staleHost = hostState(
      runtimeDirectory: matchingRuntime,
      xctestrunPath: "/tmp/old.xctestrun",
      pid: 151
    )

    let decision = HostSupervisor.restartDecision(
      prepared: prepared,
      host: staleHost,
      isHostActive: true
    )

    #expect(decision == .restart)
  }

  @Test("matching active host does not restart unnecessarily")
  func matchingActiveHostDoesNotRestartUnnecessarily() throws {
    let prepared = preparedState()
    let expectedRuntime = HostRuntime.hostRuntimeDirectory(for: prepared)
    let existing = hostState(runtimeDirectory: expectedRuntime, pid: 202)

    let decision = HostSupervisor.restartDecision(
      prepared: prepared,
      host: existing,
      isHostActive: true
    )

    #expect(decision == .reuse)
  }

  @Test("shared ensure-running orchestration stops and restarts stale hosts")
  func sharedEnsureRunningOrchestrationStopsAndRestartsStaleHosts() throws {
    let prepared = preparedState()
    let staleHost = hostState(runtimeDirectory: "/tmp/old-runtime", pid: 303)
    var events: [String] = []

    let result = try HostSupervisor.ensureRunning(
      prepared: prepared,
      sourceRoot: "/tmp/source-root",
      existingHost: staleHost,
      isHostActive: { _ in false },
      stopHost: { state, timeout in
        events.append("stop:\(state.pid):\(timeout)")
      },
      removeStoredHost: { sourceRoot in
        events.append("remove:\(sourceRoot)")
      },
      prepareRuntime: { runtimeDirectory in
        events.append("prepare:\(runtimeDirectory)")
      },
      startHost: { _, runtimeDirectory, logPath in
        events.append("start:\(runtimeDirectory):\(logPath)")
        return 404
      },
      saveHost: { state, sourceRoot in
        events.append("save:\(state.pid):\(sourceRoot)")
      },
      waitUntilReady: { state, timeout in
        events.append("wait:\(state.pid):\(timeout)")
      }
    )

    #expect(result.decision == .restart)
    #expect(result.state.pid == 404)
    #expect(result.state.runtimeDirectory == HostRuntime.hostRuntimeDirectory(for: prepared))
    #expect(
      events == [
        "stop:303:1.0",
        "remove:/tmp/source-root",
        "prepare:\(HostRuntime.hostRuntimeDirectory(for: prepared))",
        "start:\(HostRuntime.hostRuntimeDirectory(for: prepared)):/tmp/source-root/.snapview/host.log",
        "save:404:/tmp/source-root",
        "wait:404:15.0",
      ]
    )
  }

  private func preparedState(
    scheme: String = "Demo",
    projectPath: String = "/tmp/Demo.xcodeproj",
    testTargetName: String = "DemoTests",
    xctestrunPath: String = "/tmp/Demo.xctestrun"
  ) -> PreparedRenderState {
    PreparedRenderState(
      scheme: scheme,
      projectPath: projectPath,
      workspacePath: nil,
      testTargetName: testTargetName,
      destinationSpecifier: "platform=iOS Simulator,OS=17.5,name=iPhone 15",
      derivedDataPath: "/tmp/DerivedData",
      xctestrunPath: xctestrunPath
    )
  }

  private func hostState(
    scheme: String = "Demo",
    projectPath: String = "/tmp/Demo.xcodeproj",
    testTargetName: String = "DemoTests",
    runtimeDirectory: String,
    destinationSpecifier: String = "platform=iOS Simulator,OS=17.5,name=iPhone 15",
    xctestrunPath: String = "/tmp/Demo.xctestrun",
    pid: Int
  ) -> HostedRenderState {
    HostedRenderState(
      scheme: scheme,
      projectPath: projectPath,
      testTargetName: testTargetName,
      runtimeDirectory: runtimeDirectory,
      logPath: "/tmp/source-root/.snapview/host.log",
      destinationSpecifier: destinationSpecifier,
      xctestrunPath: xctestrunPath,
      pid: pid
    )
  }
}
