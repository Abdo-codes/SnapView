// Sources/snapview/Scanner/ImportScanner.swift
import Foundation

enum ImportScanner {
  static func scan(source: String) -> [String] {
    source.components(separatedBy: .newlines)
      .map { $0.trimmingCharacters(in: .whitespaces) }
      .filter { line in
        (line.hasPrefix("import ") || line.hasPrefix("@testable import "))
          && !line.hasPrefix("//")
          && !line.hasPrefix("/*")
      }
  }
}
