import Foundation
import Testing
@testable import snapview

@Suite("IntegrationSmokeScript")
struct IntegrationSmokeScriptTests {

  @Test("rejects missing required arguments with usage text")
  func rejectsMissingRequiredArguments() throws {
    let fixture = try SmokeFixture.make()
    let result = try fixture.run(arguments: ["--scheme", "Demo"])

    #expect(result.terminationStatus != 0)
    #expect(result.output.contains("Usage:"))
    #expect(result.output.contains("--project"))
    #expect(result.output.contains("--workspace"))
  }

  @Test("runs the default flow and writes gallery artifacts")
  func runsDefaultFlowAndWritesGalleryArtifacts() throws {
    let fixture = try SmokeFixture.make()
    let result = try fixture.run(
      arguments: [
        "--scheme", "Demo",
        "--project", fixture.projectPath,
      ]
    )

    #expect(result.terminationStatus == 0)
    #expect(result.output.contains("==> doctor"))
    #expect(result.output.contains("==> prepare"))
    #expect(result.output.contains("==> render-all"))
    #expect(result.output.contains("==> gallery"))
    #expect(FileManager.default.fileExists(atPath: fixture.galleryPath))
    #expect(FileManager.default.fileExists(atPath: fixture.pngPath))

    let invocations = try fixture.loggedInvocations()
    #expect(invocations == fixture.expectedInvocations())
  }

  @Test("accepts watch and keep-host flags without enabling watch behavior")
  func acceptsWatchAndKeepHostFlags() throws {
    let fixture = try SmokeFixture.make()
    let result = try fixture.run(
      arguments: [
        "--scheme", "Demo",
        "--project", fixture.projectPath,
        "--watch",
        "--keep-host",
      ]
    )

    #expect(result.terminationStatus == 0)
    #expect(result.output.contains("==> doctor"))
    #expect(result.output.contains("==> gallery"))
    let invocations = try fixture.loggedInvocations()
    #expect(invocations == fixture.expectedInvocations())
  }

  @Test("fails if gallery.html is missing")
  func failsIfGalleryIsMissing() throws {
    let fixture = try SmokeFixture.make(createGallery: false)
    let result = try fixture.run(
      arguments: [
        "--scheme", "Demo",
        "--project", fixture.projectPath,
      ]
    )

    #expect(result.terminationStatus != 0)
    #expect(result.output.contains("gallery.html"))
  }

  @Test("fails if no PNG exists")
  func failsIfNoPNGExists() throws {
    let fixture = try SmokeFixture.make(createPNG: false)
    let result = try fixture.run(
      arguments: [
        "--scheme", "Demo",
        "--project", fixture.projectPath,
      ]
    )

    #expect(result.terminationStatus != 0)
    #expect(result.output.contains(".png"))
  }
}

private struct SmokeFixture {
  let rootURL: URL
  let projectPath: String
  let scriptPath: String
  let fakeSnapviewPath: String
  let commandLogPath: String
  let galleryPath: String
  let pngPath: String
  let createGallery: Bool
  let createPNG: Bool

  static func make(
    createGallery: Bool = true,
    createPNG: Bool = true
  ) throws -> SmokeFixture {
    let fm = FileManager.default
    let rootURL = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    let projectURL = rootURL.appendingPathComponent("Demo App.xcodeproj", isDirectory: true)
    let snapviewDirectory = rootURL.appendingPathComponent(".snapview", isDirectory: true)
    try fm.createDirectory(at: projectURL, withIntermediateDirectories: true)
    try fm.createDirectory(at: snapviewDirectory, withIntermediateDirectories: true)

    let repoRoot = URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .deletingLastPathComponent()

    let scriptPath = repoRoot.appendingPathComponent("scripts/integration-smoke.sh").path
    let fakeSnapviewPath = repoRoot
      .appendingPathComponent("Tests/Fixtures/integration-smoke/fake-snapview.sh").path
    let commandLogPath = rootURL.appendingPathComponent("commands.log").path
    let galleryPath = snapviewDirectory.appendingPathComponent("gallery.html").path
    let pngPath = snapviewDirectory.appendingPathComponent("Smoke.png").path

    let fixture = SmokeFixture(
      rootURL: rootURL,
      projectPath: projectURL.path,
      scriptPath: scriptPath,
      fakeSnapviewPath: fakeSnapviewPath,
      commandLogPath: commandLogPath,
      galleryPath: galleryPath,
      pngPath: pngPath,
      createGallery: createGallery,
      createPNG: createPNG
    )
    return fixture
  }

  func run(arguments: [String]) throws -> ProcessRunner.Result {
    var environment = ProcessInfo.processInfo.environment
    environment["SNAPVIEW_BIN"] = fakeSnapviewPath
    environment["SMOKE_PROJECT_ROOT"] = rootURL.path
    environment["SMOKE_COMMAND_LOG"] = commandLogPath
    environment["SMOKE_EXPECT_INPUT_FLAG"] = "--project"
    environment["SMOKE_EXPECT_INPUT_PATH"] = projectPath
    environment["SMOKE_EXPECT_SCHEME"] = "Demo"
    environment["SMOKE_CREATE_GALLERY"] = createGallery ? "1" : "0"
    environment["SMOKE_CREATE_PNG"] = createPNG ? "1" : "0"

    let result = try ProcessRunner.run(
      executableURL: URL(filePath: "/bin/sh"),
      arguments: [scriptPath] + arguments,
      environment: environment,
      verbose: false
    )
    return result
  }

  func loggedInvocations() throws -> [[String]] {
    let data = try Data(contentsOf: URL(fileURLWithPath: commandLogPath))
    return Self.parseInvocations(from: data)
  }

  func expectedInvocations() -> [[String]] {
    [
      ["doctor", "--project", projectPath, "--scheme", "Demo"],
      ["prepare", "--project", projectPath, "--scheme", "Demo"],
      ["render-all", "--project", projectPath, "--scheme", "Demo"],
      ["gallery", "--project", projectPath],
    ]
  }

  private static func parseInvocations(from data: Data) -> [[String]] {
    var invocations: [[String]] = []
    var currentInvocation: [String] = []
    var tokenBytes: [UInt8] = []
    var consecutiveZeroBytes = 0

    func appendCurrentToken() {
      guard !tokenBytes.isEmpty else { return }
      currentInvocation.append(String(decoding: tokenBytes, as: UTF8.self))
      tokenBytes.removeAll(keepingCapacity: true)
    }

    func finishInvocation() {
      guard !currentInvocation.isEmpty else { return }
      invocations.append(currentInvocation)
      currentInvocation = []
    }

    for byte in data {
      if byte == 0 {
        appendCurrentToken()
        consecutiveZeroBytes += 1
        if consecutiveZeroBytes == 2 {
          finishInvocation()
          consecutiveZeroBytes = 0
        }
      } else {
        if consecutiveZeroBytes > 0 {
          consecutiveZeroBytes = 0
        }
        tokenBytes.append(byte)
      }
    }

    return invocations
  }
}
