import Foundation

enum HostSupervisor {
  enum RestartDecision: Equatable {
    case start
    case reuse
    case restart
  }

  struct EnsureResult: Equatable {
    let decision: RestartDecision
    let state: HostedRenderState
  }

  static func restartDecision(
    prepared: PreparedRenderState,
    host: HostedRenderState?,
    isHostActive: Bool
  ) -> RestartDecision {
    guard let host else {
      return .start
    }

    let expectedRuntimeDirectory = HostRuntime.hostRuntimeDirectory(for: prepared)
    guard
      host.scheme == prepared.scheme,
      host.projectPath == prepared.projectPath,
      host.testTargetName == prepared.testTargetName,
      host.runtimeDirectory == expectedRuntimeDirectory,
      host.destinationSpecifier == prepared.destinationSpecifier,
      host.xctestrunPath == prepared.xctestrunPath,
      isHostActive
    else {
      return .restart
    }

    return .reuse
  }

  static func ensureRunning(
    prepared: PreparedRenderState,
    sourceRoot: String,
    existingHost: HostedRenderState?,
    isHostActive: (HostedRenderState) -> Bool = HostStore.isActive,
    stopHost: (HostedRenderState, TimeInterval) throws -> Void = HostRunner.stop,
    removeStoredHost: (String) throws -> Void = HostStore.remove,
    prepareRuntime: (String) throws -> Void = HostRuntime.prepare,
    startHost: (PreparedRenderState, String, String) throws -> Int = HostRunner.start,
    saveHost: (HostedRenderState, String) throws -> Void = HostStore.save,
    waitUntilReady: (HostedRenderState, TimeInterval) throws -> Void = HostRunner.waitUntilReady,
    logPathForSourceRoot: (String) -> String = defaultLogPath
  ) throws -> EnsureResult {
    let decision = restartDecision(
      prepared: prepared,
      host: existingHost,
      isHostActive: existingHost.map(isHostActive) ?? false
    )

    if case .reuse = decision, let existingHost {
      return EnsureResult(decision: .reuse, state: existingHost)
    }

    if let existingHost {
      try? stopHost(existingHost, 1)
      try? removeStoredHost(sourceRoot)
    }

    let runtimeDirectory = HostRuntime.hostRuntimeDirectory(for: prepared)
    let logPath = logPathForSourceRoot(sourceRoot)
    try prepareRuntime(runtimeDirectory)

    let pid = try startHost(prepared, runtimeDirectory, logPath)
    let state = HostedRenderState(
      scheme: prepared.scheme,
      projectPath: prepared.projectPath,
      testTargetName: prepared.testTargetName,
      runtimeDirectory: runtimeDirectory,
      logPath: logPath,
      destinationSpecifier: prepared.destinationSpecifier,
      xctestrunPath: prepared.xctestrunPath,
      pid: pid
    )
    try saveHost(state, sourceRoot)

    do {
      try waitUntilReady(state, 15)
    } catch {
      try? stopHost(state, 1)
      try? removeStoredHost(sourceRoot)
      throw error
    }

    return EnsureResult(decision: decision, state: state)
  }

  private static func defaultLogPath(sourceRoot: String) -> String {
    "\(sourceRoot)/.snapview/host.log"
  }
}
