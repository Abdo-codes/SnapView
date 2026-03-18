import ArgumentParser
import Foundation

struct WatchCommand: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "watch",
    abstract: "Continuously prepare, host, and render previews as Swift files change."
  )

  @Option(name: .long, help: "Xcode scheme to watch.")
  var scheme: String

  @Option(name: .long) var project: String?
  @Option(name: .long) var workspace: String?
  @Option(name: .long) var testTarget: String?
  @Option(name: .long) var device: String = "iPhone15Pro"
  @Option(name: .long) var scale: Double = 2.0
  @Option(name: .long) var output: String = ".snapview"
  @Option(name: .long) var simulator: String?
  @Flag(name: .long) var rtl = false
  @Option(name: .long) var locale: String = "en_US"
  @Flag(name: .long) var verbose = false
  @Option(name: .long, help: "Seconds between filesystem polls.")
  var pollInterval: Double = 1.0
  @Option(name: .long, help: "Seconds to wait for changes to settle before refreshing.")
  var debounce: Double = 0.25

  func run() throws {
    let projectInfo = try ProjectDetector.detect(
      projectPath: project,
      workspacePath: workspace,
      testTarget: testTarget
    )
    try ProjectValidator.validateRenderPrerequisites(project: projectInfo, scheme: scheme)

    let health = try DoctorCommand.health(projectInfo: projectInfo, scheme: scheme)
    if !health.findings.isEmpty {
      print(DoctorCommandRenderer.render(health))
      if !Self.startupBlockingFindings(health).isEmpty {
        throw ExitCode.failure
      }
    }

    let watcher = FileSnapshotWatcher(rootPath: "\(projectInfo.sourceRoot)/\(projectInfo.appName)")
    let galleryPath = GalleryStore.pagePath(sourceRoot: projectInfo.sourceRoot)
    let runner = WatchRunner(
      debounceInterval: debounce,
      snapshot: { try watcher.snapshot() },
      sleep: { Thread.sleep(forTimeInterval: $0) },
      prepare: {
        print("[watch] Preparing previews...")
        return try PrepareCommand.performPreparation(
          projectInfo: projectInfo,
          scheme: scheme,
          simulator: simulator,
          verbose: verbose,
          report: { print("  \($0)") }
        )
      },
      ensureHost: { prepared in
        let result = try HostSupervisor.ensureRunning(
          prepared: prepared,
          sourceRoot: projectInfo.sourceRoot,
          existingHost: try HostStore.loadIfPresent(sourceRoot: projectInfo.sourceRoot)
        )

        switch result.decision {
        case .reuse:
          print("[watch] Reusing persistent host (pid \(result.state.pid)).")
        case .start:
          print("[watch] Persistent host ready (pid \(result.state.pid)).")
        case .restart:
          print("[watch] Persistent host restarted (pid \(result.state.pid)).")
        }
      },
      renderAll: { prepared in
        print("[watch] Rendering gallery...")
        let result = try RenderAllCommand.perform(
          request: RenderAllRequest(
            scheme: scheme,
            projectInfo: projectInfo,
            prepared: prepared,
            device: device,
            scale: scale,
            output: output,
            simulator: simulator,
            rtl: rtl,
            locale: locale,
            verbose: verbose
          ),
          report: { print("  \($0)") }
        )
        print("[watch] Updated \(result.imagePaths.count) preview(s) in \(result.elapsed)s.")
        print("[watch] Gallery: \(galleryPath)")
      }
    )

    print("Watching \(projectInfo.appName) for Swift changes. Press Ctrl-C to stop.")
    print("Gallery: \(galleryPath)")

    while true {
      do {
        _ = try runner.runSingleIteration()
      } catch {
        print("[watch:error] \(error)")
      }

      Thread.sleep(forTimeInterval: pollInterval)
    }
  }

  static func startupBlockingFindings(_ health: ProjectHealth) -> [HealthFinding] {
    health.errors.filter { $0.code != .stalePreparationState }
  }
}
