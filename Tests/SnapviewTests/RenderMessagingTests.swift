import Testing
@testable import snapview

@Suite("RenderMessaging")
struct RenderMessagingTests {

  @Test("preview not found message explains preview-backed rendering")
  func previewNotFoundMessage() {
    let message = RenderMessaging.previewNotFound(viewName: "DashboardView")
    #expect(message.contains("DashboardView"))
    #expect(message.contains("only renders #Preview-backed views"))
    #expect(message.contains("snapview list"))
  }

  @Test("no previews message explains how to add coverage")
  func noPreviewsMessage() {
    let message = RenderMessaging.noPreviewsFound()
    #expect(message.contains("No #Preview blocks found"))
    #expect(message.contains("render-all only renders discovered previews"))
    #expect(message.contains("Add #Preview blocks"))
  }
}
