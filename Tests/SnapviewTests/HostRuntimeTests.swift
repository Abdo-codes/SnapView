import Foundation
import Testing
@testable import snapview

@Suite("HostRuntime")
struct HostRuntimeTests {

  @Test("writes requests and waits for the matching response")
  func writesRequestsAndWaitsForResponse() throws {
    let runtimeDirectory = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer { try? FileManager.default.removeItem(at: runtimeDirectory) }

    try HostRuntime.prepare(runtimeDirectory: runtimeDirectory.path)

    let request = HostRenderRequest(
      requestID: "req-1",
      viewNames: ["OnboardingView"],
      scale: 2,
      width: 393,
      height: 852,
      rtl: false,
      locale: "en_US"
    )
    try HostRuntime.writeRequest(request, runtimeDirectory: runtimeDirectory.path)

    let writtenData = try Data(contentsOf: URL(filePath: HostRuntime.requestPath(runtimeDirectory: runtimeDirectory.path)))
    let writtenRequest = try JSONDecoder().decode(HostRenderRequest.self, from: writtenData)
    #expect(writtenRequest == request)

    let response = HostRenderResponse(
      requestID: request.requestID,
      renderedViewNames: request.viewNames,
      errorMessage: nil
    )
    let responseData = try JSONEncoder().encode(response)
    try responseData.write(to: URL(filePath: HostRuntime.responsePath(runtimeDirectory: runtimeDirectory.path)))

    let loaded = try HostRuntime.waitForResponse(
      requestID: request.requestID,
      runtimeDirectory: runtimeDirectory.path,
      timeout: 0.2
    )
    #expect(loaded == response)
  }
}
