import Foundation

struct CaptureResult: Equatable {
  let screenName: String
  let imagePath: String
  let captureStrategy: GalleryCaptureStrategy
  let warnings: [String]

  func galleryEntry(
    sourceFile: String,
    source: GalleryImageSource,
    updatedAt: Date
  ) -> GalleryEntry {
    GalleryEntry(
      previewName: screenName,
      sourceFile: sourceFile,
      imagePath: imagePath,
      source: source,
      renderKind: .capture,
      captureStrategy: captureStrategy,
      warnings: warnings,
      updatedAt: updatedAt
    )
  }
}

struct CaptureRunner {
  typealias RenderPreview = (_ previewName: String) throws -> String
  typealias OpenURL = (_ url: String) throws -> Void
  typealias LaunchApp = (
    _ arguments: [String],
    _ environment: [String: String],
    _ screenName: String
  ) throws -> Void
  typealias TakeScreenshot = () throws -> String
  typealias FinalizeOutput = (_ path: String) throws -> String

  let renderPreview: RenderPreview
  let openURL: OpenURL
  let launchApp: LaunchApp
  let takeScreenshot: TakeScreenshot
  let finalizeOutput: FinalizeOutput

  func capture(screen: CaptureScreen) throws -> CaptureResult {
    guard !screen.strategies.isEmpty else {
      throw Error.noStrategies(screen.name)
    }

    var failures: [String] = []

    for strategy in screen.strategies {
      do {
        switch strategy {
        case .preview(let previewName):
          let imagePath = try finalizeOutput(try renderPreview(previewName))
          return CaptureResult(
            screenName: screen.name,
            imagePath: imagePath,
            captureStrategy: .preview,
            warnings: []
          )

        case .deeplink(let url):
          try openURL(url)
          let imagePath = try finalizeOutput(try takeScreenshot())
          return CaptureResult(
            screenName: screen.name,
            imagePath: imagePath,
            captureStrategy: .deeplink,
            warnings: []
          )

        case .launch(let arguments, let environment):
          try launchApp(arguments, environment, screen.name)
          let imagePath = try finalizeOutput(try takeScreenshot())
          return CaptureResult(
            screenName: screen.name,
            imagePath: imagePath,
            captureStrategy: .launch,
            warnings: []
          )
        }
      } catch {
        failures.append(describe(error, for: strategy))
      }
    }

    throw Error.allStrategiesFailed(screen: screen.name, failures: failures)
  }

  enum Error: Swift.Error, Equatable, CustomStringConvertible {
    case noStrategies(String)
    case previewFailed(String)
    case deeplinkFailed(String)
    case launchFailed(String)
    case allStrategiesFailed(screen: String, failures: [String])

    var description: String {
      switch self {
      case .noStrategies(let screen):
        return "No capture strategies were configured for '\(screen)'."
      case .previewFailed(let detail):
        return "Preview capture failed: \(detail)"
      case .deeplinkFailed(let detail):
        return "Deeplink capture failed: \(detail)"
      case .launchFailed(let detail):
        return "Launch capture failed: \(detail)"
      case .allStrategiesFailed(let screen, let failures):
        return "All capture strategies failed for '\(screen)': \(failures.joined(separator: "; "))"
      }
    }
  }

  private func describe(_ error: Swift.Error, for strategy: CaptureStrategy) -> String {
    if let error = error as? Error {
      return error.description
    }

    switch strategy {
    case .preview:
      return Error.previewFailed(String(describing: error)).description
    case .deeplink:
      return Error.deeplinkFailed(String(describing: error)).description
    case .launch:
      return Error.launchFailed(String(describing: error)).description
    }
  }
}
