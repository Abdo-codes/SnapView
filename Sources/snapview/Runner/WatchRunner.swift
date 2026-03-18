import Foundation

final class WatchRunner {
  enum CycleOutcome: Equatable {
    case idle
    case rendered
  }

  private let debounceInterval: TimeInterval
  private let snapshot: () throws -> FileSnapshot
  private let sleep: (TimeInterval) throws -> Void
  private let prepare: () throws -> PreparedRenderState
  private let ensureHost: (PreparedRenderState) throws -> Void
  private let renderAll: (PreparedRenderState) throws -> Void
  private var lastCompletedSnapshot: FileSnapshot?

  init(
    debounceInterval: TimeInterval = 0.25,
    snapshot: @escaping () throws -> FileSnapshot,
    sleep: @escaping (TimeInterval) throws -> Void,
    prepare: @escaping () throws -> PreparedRenderState,
    ensureHost: @escaping (PreparedRenderState) throws -> Void,
    renderAll: @escaping (PreparedRenderState) throws -> Void
  ) {
    self.debounceInterval = debounceInterval
    self.snapshot = snapshot
    self.sleep = sleep
    self.prepare = prepare
    self.ensureHost = ensureHost
    self.renderAll = renderAll
  }

  func runSingleIteration() throws -> CycleOutcome {
    let currentSnapshot = try snapshot()
    guard currentSnapshot != lastCompletedSnapshot else {
      return .idle
    }

    let settledSnapshot = try debouncedSnapshot(startingAt: currentSnapshot)
    let prepared = try prepare()
    try ensureHost(prepared)
    try renderAll(prepared)
    lastCompletedSnapshot = settledSnapshot
    return .rendered
  }

  private func debouncedSnapshot(startingAt snapshot: FileSnapshot) throws -> FileSnapshot {
    var latestSnapshot = snapshot

    while true {
      try sleep(debounceInterval)
      let nextSnapshot = try self.snapshot()
      guard nextSnapshot != latestSnapshot else {
        return latestSnapshot
      }
      latestSnapshot = nextSnapshot
    }
  }
}
