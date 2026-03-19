import ArgumentParser
import Foundation

struct HostCommand: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "host",
    abstract: "Manage the persistent renderer host.",
    subcommands: [
      HostStartCommand.self,
      HostStopCommand.self,
      HostStatusCommand.self,
    ]
  )
}

struct HostStartCommand: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "start",
    abstract: "Start a persistent renderer host backed by prepared test artifacts."
  )

  @Option(name: .long, help: "Xcode scheme to build.")
  var scheme: String

  @Option(name: .long) var project: String?
  @Option(name: .long) var workspace: String?
  @Option(name: .long) var testTarget: String?

  func run() throws {
    let projectInfo = try ProjectDetector.detect(
      projectPath: project, workspacePath: workspace, testTarget: testTarget
    )
    try ProjectValidator.validateRenderPrerequisites(project: projectInfo, scheme: scheme)
    let prepared = try PreparationStore.load(sourceRoot: projectInfo.sourceRoot)
    try PreparationStore.validate(prepared, project: projectInfo, scheme: scheme)

    let rendererPath = "\(projectInfo.sourceRoot)/\(projectInfo.testTargetName)/SnapViewRenderer.swift"
    guard FileManager.default.fileExists(atPath: rendererPath) else {
      throw CleanExit.message("[snapview:error] Not initialized. Run: snapview init --scheme \(scheme)")
    }

    let result = try HostSupervisor.ensureRunning(
      prepared: prepared,
      sourceRoot: projectInfo.sourceRoot,
      existingHost: try HostStore.loadIfPresent(sourceRoot: projectInfo.sourceRoot)
    )

    switch result.decision {
    case .reuse:
      print("Persistent host is already running (pid \(result.state.pid)).")
    case .start:
      print("Persistent host is ready.")
    case .restart:
      print("Persistent host was restarted.")
    }
    print("PID: \(result.state.pid)")
    print("Log: \(result.state.logPath)")
  }
}

struct HostStopCommand: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "stop",
    abstract: "Stop the persistent renderer host."
  )

  @Option(name: .long) var project: String?
  @Option(name: .long) var workspace: String?
  @Option(name: .long) var testTarget: String?

  func run() throws {
    let projectInfo = try ProjectDetector.detect(
      projectPath: project, workspacePath: workspace, testTarget: testTarget
    )

    guard let state = try HostStore.loadIfPresent(sourceRoot: projectInfo.sourceRoot) else {
      print("Persistent host is not running.")
      return
    }

    try HostRunner.stop(state, timeout: 2)
    try HostStore.remove(sourceRoot: projectInfo.sourceRoot)
    print("Persistent host stopped.")
  }
}

struct HostStatusCommand: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "status",
    abstract: "Show the persistent renderer host status."
  )

  @Option(name: .long) var project: String?
  @Option(name: .long) var workspace: String?
  @Option(name: .long) var testTarget: String?

  func run() throws {
    let projectInfo = try ProjectDetector.detect(
      projectPath: project, workspacePath: workspace, testTarget: testTarget
    )

    guard let state = try HostStore.loadIfPresent(sourceRoot: projectInfo.sourceRoot) else {
      print("Persistent host is not running.")
      return
    }

    if HostStore.isActive(state) {
      print("Persistent host is running.")
      print("PID: \(state.pid)")
      print("Log: \(state.logPath)")
    } else {
      print("Persistent host is not running.")
      print("Last known PID: \(state.pid)")
      print("Log: \(state.logPath)")
    }
  }
}
