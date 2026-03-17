// Sources/snapview/Generator/RendererTemplate.swift
import Foundation

enum RendererTemplate {

  static func generate() -> String {
    """
    // SnapViewRenderer.swift — added by snapview init. Safe to commit.
    import XCTest
    import SwiftUI
    import UIKit

    @MainActor
    final class SnapViewRenderer: XCTestCase {

      private let outputDir = "/tmp/snapview"

      override func setUp() async throws {
        try FileManager.default.createDirectory(
          atPath: outputDir,
          withIntermediateDirectories: true
        )
      }

      func test_render() throws {
        // Read config from file (env vars don't forward through xcodebuild)
        let configPath = "\\(outputDir)/config.json"
        let config: [String: String]
        if let data = FileManager.default.contents(atPath: configPath),
           let decoded = try? JSONSerialization.jsonObject(with: data) as? [String: String] {
          config = decoded
        } else {
          config = [:]
        }

        let requestedViews = config["SNAPVIEW_VIEWS"]?
          .split(separator: ",")
          .map(String.init) ?? []

        let scale = Double(config["SNAPVIEW_SCALE"] ?? "2.0") ?? 2.0
        let width = Double(config["SNAPVIEW_WIDTH"] ?? "393") ?? 393
        let height = Double(config["SNAPVIEW_HEIGHT"] ?? "852") ?? 852
        let isRTL = config["SNAPVIEW_RTL"] == "1"
        let locale = config["SNAPVIEW_LOCALE"] ?? "en_US"

        let entries = requestedViews.isEmpty
          ? SnapViewRegistry.all
          : SnapViewRegistry.all.filter { requestedViews.contains($0.name) }

        guard !entries.isEmpty else {
          XCTFail("No matching entries found in SnapViewRegistry")
          return
        }

        for entry in entries {
          let hosted = entry.body()
            .frame(width: width, height: height)
            .environment(\\.layoutDirection, isRTL ? .rightToLeft : .leftToRight)
            .environment(\\.locale, Locale(identifier: locale))

          let renderer = ImageRenderer(content: AnyView(hosted))
          renderer.scale = scale

          guard let cgImage = renderer.cgImage else {
            XCTFail("ImageRenderer returned nil for \\(entry.name)")
            continue
          }
          let image = UIImage(cgImage: cgImage)
          guard let data = image.pngData() else {
            XCTFail("PNG encoding failed for \\(entry.name)")
            continue
          }
          let url = URL(filePath: "\\(outputDir)/\\(entry.name).png")
          try data.write(to: url)
        }
      }
    }
    """
  }
}
