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
    #expect(output.contains("ImageRenderer"))
    #expect(output.contains("renderer.cgImage"))
    #expect(output.contains("/tmp/snapview"))
  }
}
