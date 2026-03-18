import Foundation
import Testing
@testable import snapview

@Suite("ProcessRunner")
struct ProcessRunnerTests {

  @Test("captures large non-verbose output without blocking")
  func capturesLargeOutputWithoutBlocking() throws {
    let result = try ProcessRunner.run(
      executableURL: URL(filePath: "/bin/sh"),
      arguments: [
        "-c",
        "yes snapview | head -n 200000; exit 7",
      ],
      verbose: false
    )

    #expect(result.terminationStatus == 7)
    #expect(result.output.contains("snapview"))
  }
}
