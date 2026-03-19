import Foundation

struct FileSnapshot: Equatable {
  let files: [String: Date]
}

struct FileSnapshotWatcher {
  let rootPath: String

  func snapshot() throws -> FileSnapshot {
    let fm = FileManager.default
    guard let enumerator = fm.enumerator(atPath: rootPath) else {
      return FileSnapshot(files: [:])
    }

    var files: [String: Date] = [:]
    while let path = enumerator.nextObject() as? String {
      guard path.hasSuffix(".swift") else {
        continue
      }

      let fullPath = "\(rootPath)/\(path)"
      let attributes = try fm.attributesOfItem(atPath: fullPath)
      let modifiedAt = attributes[.modificationDate] as? Date ?? .distantPast
      files[path] = modifiedAt
    }

    return FileSnapshot(files: files)
  }
}
