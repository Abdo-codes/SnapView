import Foundation
import Testing
@testable import snapview

@Suite("GalleryCommand")
struct GalleryCommandTests {

  @Test("formats regenerated gallery output")
  func formatsRegeneratedGalleryOutput() {
    let text = GalleryCommandRenderer.render(
      pagePath: "/tmp/App/.snapview/gallery.html",
      regenerated: true
    )

    #expect(text.contains("Gallery regenerated from .snapview/gallery.json."))
    #expect(text.contains("Gallery: /tmp/App/.snapview/gallery.html"))
  }
}
