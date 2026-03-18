import Foundation
import Testing
@testable import snapview

@Suite("HostStore")
struct HostStoreTests {

  @Test("saves and loads host state")
  func savesAndLoadsState() throws {
    let sourceRoot = temporarySourceRoot()
    defer { try? FileManager.default.removeItem(atPath: sourceRoot) }

    let state = HostedRenderState(
      scheme: "Demo",
      projectPath: "/tmp/Demo.xcodeproj",
      testTargetName: "DemoTests",
      runtimeDirectory: "\(sourceRoot)/runtime",
      logPath: "\(sourceRoot)/host.log",
      destinationSpecifier: "platform=iOS Simulator,OS=17.5,name=iPhone 15",
      xctestrunPath: "/tmp/Demo.xctestrun",
      pid: 42
    )

    try HostStore.save(state, sourceRoot: sourceRoot)
    let loaded = try HostStore.load(sourceRoot: sourceRoot)

    #expect(loaded == state)
  }

  @Test("loads active host only when the process is alive and ready")
  func loadsActiveHostWhenReady() throws {
    let sourceRoot = temporarySourceRoot()
    defer { try? FileManager.default.removeItem(atPath: sourceRoot) }

    let runtimeDirectory = "\(sourceRoot)/runtime"
    try FileManager.default.createDirectory(atPath: runtimeDirectory, withIntermediateDirectories: true)
    try Data("ready".utf8).write(to: URL(filePath: HostRuntime.readyPath(runtimeDirectory: runtimeDirectory)))

    let state = HostedRenderState(
      scheme: "Demo",
      projectPath: "/tmp/Demo.xcodeproj",
      testTargetName: "DemoTests",
      runtimeDirectory: runtimeDirectory,
      logPath: "\(sourceRoot)/host.log",
      destinationSpecifier: "platform=iOS Simulator,OS=17.5,name=iPhone 15",
      xctestrunPath: "/tmp/Demo.xctestrun",
      pid: Int(ProcessInfo.processInfo.processIdentifier)
    )

    try HostStore.save(state, sourceRoot: sourceRoot)

    let active = try HostStore.loadActive(sourceRoot: sourceRoot)
    #expect(active == state)
  }

  @Test("does not load an active host when the ready marker is missing")
  func doesNotLoadInactiveHost() throws {
    let sourceRoot = temporarySourceRoot()
    defer { try? FileManager.default.removeItem(atPath: sourceRoot) }

    let runtimeDirectory = "\(sourceRoot)/runtime"
    try FileManager.default.createDirectory(atPath: runtimeDirectory, withIntermediateDirectories: true)

    let state = HostedRenderState(
      scheme: "Demo",
      projectPath: "/tmp/Demo.xcodeproj",
      testTargetName: "DemoTests",
      runtimeDirectory: runtimeDirectory,
      logPath: "\(sourceRoot)/host.log",
      destinationSpecifier: "platform=iOS Simulator,OS=17.5,name=iPhone 15",
      xctestrunPath: "/tmp/Demo.xctestrun",
      pid: Int(ProcessInfo.processInfo.processIdentifier)
    )

    try HostStore.save(state, sourceRoot: sourceRoot)

    let active = try HostStore.loadActive(sourceRoot: sourceRoot)
    #expect(active == nil)
  }

  private func temporarySourceRoot() -> String {
    let url = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    return url.path
  }
}
