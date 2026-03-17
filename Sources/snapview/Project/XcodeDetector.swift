import Foundation

enum XcodeDetector {
  static func isXcodeOpen(projectPath: String) -> Bool {
    let process = Process()
    process.executableURL = URL(filePath: "/usr/bin/lsof")
    process.arguments = ["-t", projectPath]
    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = FileHandle.nullDevice
    try? process.run()
    process.waitUntilExit()
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    return !data.isEmpty
  }
}
