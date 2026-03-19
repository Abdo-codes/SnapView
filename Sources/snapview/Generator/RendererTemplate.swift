// Sources/snapview/Generator/RendererTemplate.swift
import Foundation

enum RendererTemplate {

  static func generate() -> String {
    """
    // SnapViewRenderer.swift — added by snapview init. Safe to commit.
    import XCTest
    import SwiftUI
    import UIKit

    private struct HostRenderRequest: Codable {
      let requestID: String
      let viewNames: [String]
      let scale: Double
      let width: Double
      let height: Double
      let rtl: Bool
      let locale: String
    }

    private struct HostRenderResponse: Codable {
      let requestID: String
      let renderedViewNames: [String]
      let errorMessage: String?
    }

    @MainActor
    final class SnapViewRenderer: XCTestCase {

      private let runtimeDir = ProcessInfo.processInfo.environment["SNAPVIEW_RUNTIME_DIR"] ?? "/tmp/snapview"
      private lazy var outputDir = "\\(runtimeDir)/output"
      private lazy var configPath = "\\(runtimeDir)/config.json"
      private lazy var requestPath = "\\(runtimeDir)/request.json"
      private lazy var responsePath = "\\(runtimeDir)/response.json"
      private lazy var readyPath = "\\(runtimeDir)/ready.json"
      private lazy var stopPath = "\\(runtimeDir)/stop"

      override func setUp() async throws {
        try ensureDirectory(runtimeDir)
        try ensureDirectory(outputDir)
      }

      func test_render() throws {
        do {
          _ = try render(request: requestFromConfig())
        } catch {
          XCTFail(error.localizedDescription)
        }
      }

      func test_host() throws {
        try clearRuntimeFiles()
        try Data("{\\"status\\":\\"ready\\"}".utf8).write(to: URL(filePath: readyPath), options: .atomic)

        defer {
          try? clearRuntimeFiles()
        }

        var lastRequestID: String?
        while !FileManager.default.fileExists(atPath: stopPath) {
          if let request = try loadRequest(), request.requestID != lastRequestID {
            lastRequestID = request.requestID
            do {
              let rendered = try render(request: request)
              try writeResponse(.init(
                requestID: request.requestID,
                renderedViewNames: rendered,
                errorMessage: nil
              ))
            } catch {
              try writeResponse(.init(
                requestID: request.requestID,
                renderedViewNames: [],
                errorMessage: error.localizedDescription
              ))
            }
            try? FileManager.default.removeItem(atPath: requestPath)
          }
          RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }
      }

      private func render(request: HostRenderRequest) throws -> [String] {
        try clearOutputDirectory()

        let entries = request.viewNames.isEmpty
          ? SnapViewRegistry.all
          : SnapViewRegistry.all.filter { request.viewNames.contains($0.name) }

        guard !entries.isEmpty else {
          throw NSError(
            domain: "SnapViewRenderer",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "No matching entries found in SnapViewRegistry"]
          )
        }

        var renderedViewNames: [String] = []
        for entry in entries {
          let hosted = entry.body()
            .frame(width: request.width, height: request.height)
            .environment(\\.layoutDirection, request.rtl ? .rightToLeft : .leftToRight)
            .environment(\\.locale, Locale(identifier: request.locale))

          let image = try snapshotImage(for: AnyView(hosted), request: request)
          guard let data = image.pngData() else {
            throw NSError(
              domain: "SnapViewRenderer",
              code: 3,
              userInfo: [NSLocalizedDescriptionKey: "PNG encoding failed for \\(entry.name)"]
            )
          }

          let url = URL(filePath: "\\(outputDir)/\\(entry.name).png")
          try data.write(to: url, options: .atomic)
          renderedViewNames.append(entry.name)
        }

        return renderedViewNames
      }

      private func snapshotImage(
        for view: AnyView,
        request: HostRenderRequest
      ) throws -> UIImage {
        let size = CGSize(width: request.width, height: request.height)
        let scene = try activeWindowScene()
        let controller = UIHostingController(rootView: view)
        controller.view.backgroundColor = .clear

        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(origin: .zero, size: size)
        window.bounds = CGRect(origin: .zero, size: size)
        window.rootViewController = controller
        window.backgroundColor = .clear
        window.isOpaque = false
        window.alpha = 0.01
        window.semanticContentAttribute = request.rtl ? .forceRightToLeft : .forceLeftToRight

        controller.view.frame = window.bounds
        controller.view.bounds = window.bounds
        controller.view.semanticContentAttribute = window.semanticContentAttribute
        controller.view.backgroundColor = .clear

        window.isHidden = false

        defer {
          window.isHidden = true
          window.rootViewController = nil
        }

        controller.view.setNeedsLayout()
        controller.view.layoutIfNeeded()
        window.setNeedsLayout()
        window.layoutIfNeeded()
        RunLoop.current.run(until: Date().addingTimeInterval(0.1))

        let format = UIGraphicsImageRendererFormat.preferred()
        format.scale = request.scale
        format.opaque = false

        return UIGraphicsImageRenderer(size: size, format: format).image { context in
          if !controller.view.drawHierarchy(in: controller.view.bounds, afterScreenUpdates: true) {
            controller.view.layer.render(in: context.cgContext)
          }
        }
      }

      private func activeWindowScene() throws -> UIWindowScene {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        if let scene = scenes.first(where: {
          $0.activationState == .foregroundActive || $0.activationState == .foregroundInactive
        }) {
          return scene
        }
        if let scene = scenes.first {
          return scene
        }

        throw NSError(
          domain: "SnapViewRenderer",
          code: 2,
          userInfo: [NSLocalizedDescriptionKey: "No UIWindowScene available for rendering"]
        )
      }

      private func requestFromConfig() -> HostRenderRequest {
        let config = loadConfig()
        return HostRenderRequest(
          requestID: UUID().uuidString,
          viewNames: config["SNAPVIEW_VIEWS"]?
            .split(separator: ",")
            .map(String.init) ?? [],
          scale: Double(config["SNAPVIEW_SCALE"] ?? "2.0") ?? 2.0,
          width: Double(config["SNAPVIEW_WIDTH"] ?? "393") ?? 393,
          height: Double(config["SNAPVIEW_HEIGHT"] ?? "852") ?? 852,
          rtl: config["SNAPVIEW_RTL"] == "1",
          locale: config["SNAPVIEW_LOCALE"] ?? "en_US"
        )
      }

      private func loadConfig() -> [String: String] {
        guard let data = FileManager.default.contents(atPath: configPath),
          let decoded = try? JSONSerialization.jsonObject(with: data) as? [String: String]
        else {
          return [:]
        }
        return decoded
      }

      private func loadRequest() throws -> HostRenderRequest? {
        guard FileManager.default.fileExists(atPath: requestPath) else {
          return nil
        }
        let data = try Data(contentsOf: URL(filePath: requestPath))
        return try JSONDecoder().decode(HostRenderRequest.self, from: data)
      }

      private func writeResponse(_ response: HostRenderResponse) throws {
        let data = try JSONEncoder().encode(response)
        try data.write(to: URL(filePath: responsePath), options: .atomic)
      }

      private func clearOutputDirectory() throws {
        if FileManager.default.fileExists(atPath: outputDir) {
          try FileManager.default.removeItem(atPath: outputDir)
        }
        try ensureDirectory(outputDir)
      }

      private func clearRuntimeFiles() throws {
        for path in [requestPath, responsePath, readyPath, stopPath] {
          try? FileManager.default.removeItem(atPath: path)
        }
      }

      private func ensureDirectory(_ path: String) throws {
        try FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true)
      }
    }
    """
  }
}
