// Tests/SnapviewTests/RendererTemplateTests.swift
import Testing
@testable import snapview

@Suite("RendererTemplate")
struct RendererTemplateTests {

  @Test("generates valid XCTestCase class")
  func generatesTemplate() {
    let output = RendererTemplate.generate()
    #expect(output.contains("import XCTest"))
    #expect(output.contains("import SwiftUI"))
    #expect(output.contains("import UIKit"))
    #expect(output.contains("@MainActor"))
    #expect(output.contains("final class SnapViewRenderer: XCTestCase"))
    #expect(output.contains("config.json"))
    #expect(output.contains("test_host"))
    #expect(output.contains("request.json"))
    #expect(output.contains("response.json"))
    #expect(output.contains("ready.json"))
    #expect(output.contains("SNAPVIEW_RUNTIME_DIR"))
    #expect(output.contains("UIHostingController"))
    #expect(output.contains("UIWindowScene"))
    #expect(output.contains("UIGraphicsImageRenderer"))
    #expect(output.contains("snapshotImage"))
    #expect(!output.contains("let renderer = ImageRenderer"))
    #expect(output.contains("runtimeDir)/output"))
  }
}
