import Foundation
import Testing
@testable import snapview

@Suite("PreparationStore")
struct PreparationStoreTests {

  @Test("saves and loads prepared render state")
  func savesAndLoadsPreparedState() throws {
    let tempRoot = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer { try? FileManager.default.removeItem(at: tempRoot) }

    let state = PreparedRenderState(
      scheme: "Demo",
      projectPath: "/tmp/Demo.xcodeproj",
      workspacePath: nil,
      testTargetName: "DemoTests",
      destinationSpecifier: "platform=iOS Simulator,OS=17.5,name=iPhone 15",
      derivedDataPath: tempRoot.appendingPathComponent("DerivedData").path,
      xctestrunPath: tempRoot.appendingPathComponent("DemoTests.xctestrun").path
    )

    try PreparationStore.save(state, sourceRoot: tempRoot.path)
    let loaded = try PreparationStore.load(sourceRoot: tempRoot.path)

    #expect(loaded == state)
  }

  @Test("fails when preparation metadata is missing")
  func failsWhenMetadataMissing() {
    let tempRoot = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer { try? FileManager.default.removeItem(at: tempRoot) }

    do {
      _ = try PreparationStore.load(sourceRoot: tempRoot.path)
      Issue.record("Expected missing preparation metadata failure")
    } catch let error as PreparationStore.Error {
      switch error {
      case .missingState(let path):
        #expect(path.contains(".snapview/prepare.json"))
      case .staleState(let detail):
        Issue.record("Unexpected stale preparation state: \(detail)")
      }
    } catch {
      Issue.record("Unexpected error: \(error)")
    }
  }
}
