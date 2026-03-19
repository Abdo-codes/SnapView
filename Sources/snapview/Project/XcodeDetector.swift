import Foundation

enum XcodeDetector {
  static func isXcodeOpen(projectPath: String) -> Bool {
    // Use pgrep instead of lsof — lsof on a directory hangs scanning all FDs
    let process = Process()
    process.executableURL = URL(filePath: "/usr/bin/pgrep")
    process.arguments = ["-x", "Xcode"]
    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = FileHandle.nullDevice
    try? process.run()
    process.waitUntilExit()
    return process.terminationStatus == 0
  }
}
