import ArgumentParser
import Foundation

struct GlobalOptions: ParsableArguments {
  @Flag(name: .long, help: "Emit machine-readable JSON instead of human-readable text.")
  var json = false
}

struct JSONEnvelope<T: Encodable>: Encodable {
  let command: String
  let success: Bool
  let data: T?
  let error: String?
}

enum JSONOutput {
  private static func encoder() -> JSONEncoder {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    encoder.dateEncodingStrategy = .iso8601
    return encoder
  }

  static func success<T: Encodable>(command: String, data: T) -> String {
    let envelope = JSONEnvelope(command: command, success: true, data: data, error: nil as String?)
    guard let json = try? encoder().encode(envelope),
          let str = String(data: json, encoding: .utf8)
    else { return "{}" }
    return str
  }

  static func failure(command: String, error: String) -> String {
    let envelope = JSONEnvelope<EmptyData>(command: command, success: false, data: nil, error: error)
    guard let json = try? encoder().encode(envelope),
          let str = String(data: json, encoding: .utf8)
    else { return "{}" }
    return str
  }
}

private struct EmptyData: Encodable {}
