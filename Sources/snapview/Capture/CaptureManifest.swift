import Foundation

struct CaptureManifest: Equatable {
  let appId: String
  let screens: [CaptureScreen]

  static func parse(_ data: Data) throws -> Self {
    let rawManifest: RawCaptureManifest
    do {
      rawManifest = try JSONDecoder().decode(RawCaptureManifest.self, from: data)
    } catch {
      throw Error.invalidJSON(error.localizedDescription)
    }

    let duplicates = duplicateScreenNames(in: rawManifest.screens)
    guard duplicates.isEmpty else {
      throw Error.duplicateScreenNames(duplicates)
    }

    return CaptureManifest(
      appId: rawManifest.appId,
      screens: try rawManifest.screens.map { rawScreen in
        CaptureScreen(
          name: rawScreen.name,
          strategies: try rawScreen.strategies.map { rawStrategy in
            try strategy(from: rawStrategy, screenName: rawScreen.name)
          }
        )
      }
    )
  }

  static func load(filePath: String) throws -> Self {
    try parse(Data(contentsOf: URL(filePath: filePath)))
  }

  enum Error: Swift.Error, Equatable, CustomStringConvertible {
    case invalidJSON(String)
    case duplicateScreenNames([String])
    case invalidPreviewStrategy(screen: String)
    case invalidDeeplinkStrategy(screen: String)
    case invalidLaunchStrategy(screen: String)
    case unsupportedStrategyType(String, screen: String)

    var description: String {
      switch self {
      case .invalidJSON(let message):
        return "Invalid capture manifest JSON: \(message)"
      case .duplicateScreenNames(let names):
        return "Duplicate capture screen names: \(names.joined(separator: ", "))"
      case .invalidPreviewStrategy(let screen):
        return "Preview strategy is invalid for screen '\(screen)'."
      case .invalidDeeplinkStrategy(let screen):
        return "Deeplink strategy is invalid for screen '\(screen)'."
      case .invalidLaunchStrategy(let screen):
        return "Launch strategy is invalid for screen '\(screen)'."
      case .unsupportedStrategyType(let type, let screen):
        return "Unsupported capture strategy '\(type)' for screen '\(screen)'."
      }
    }
  }

  private static func duplicateScreenNames(in screens: [RawCaptureScreen]) -> [String] {
    let counts = screens.reduce(into: [String: Int]()) { partialResult, screen in
      partialResult[screen.name, default: 0] += 1
    }

    return counts
      .filter { $0.value > 1 }
      .map(\.key)
      .sorted()
  }

  private static func strategy(
    from rawStrategy: RawCaptureStrategy,
    screenName: String
  ) throws -> CaptureStrategy {
    switch rawStrategy.type {
    case "preview":
      guard let previewName = rawStrategy.previewName?.nonEmpty else {
        throw Error.invalidPreviewStrategy(screen: screenName)
      }
      return .preview(previewName: previewName)

    case "deeplink":
      guard let url = rawStrategy.url?.nonEmpty else {
        throw Error.invalidDeeplinkStrategy(screen: screenName)
      }
      return .deeplink(url: url)

    case "launch":
      guard let arguments = rawStrategy.arguments else {
        throw Error.invalidLaunchStrategy(screen: screenName)
      }
      return .launch(arguments: arguments, environment: rawStrategy.environment ?? [:])

    default:
      throw Error.unsupportedStrategyType(rawStrategy.type, screen: screenName)
    }
  }
}

struct CaptureScreen: Equatable {
  let name: String
  let strategies: [CaptureStrategy]
}

enum CaptureStrategy: Equatable {
  case preview(previewName: String)
  case deeplink(url: String)
  case launch(arguments: [String], environment: [String: String])
}

private struct RawCaptureManifest: Decodable {
  let appId: String
  let screens: [RawCaptureScreen]
}

private struct RawCaptureScreen: Decodable {
  let name: String
  let strategies: [RawCaptureStrategy]
}

private struct RawCaptureStrategy: Decodable {
  let type: String
  let previewName: String?
  let url: String?
  let arguments: [String]?
  let environment: [String: String]?
}

private extension String {
  var nonEmpty: String? {
    let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? nil : trimmed
  }
}
