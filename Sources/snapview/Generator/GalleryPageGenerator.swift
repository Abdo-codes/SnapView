import Foundation

enum GalleryPageGenerator {
  static func render(state: GalleryState) throws -> String {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let jsonData = try encoder.encode(state)
    let json = String(decoding: jsonData, as: UTF8.self)
      .replacingOccurrences(of: "\\/", with: "/")
      .replacingOccurrences(of: "</script>", with: "<\\/script>")

    return """
    <!doctype html>
    <html lang="en">
    <head>
      <meta charset="utf-8">
      <meta name="viewport" content="width=device-width, initial-scale=1">
      <title>snapview gallery</title>
      <style>
        :root {
          color-scheme: light;
          font-family: -apple-system, BlinkMacSystemFont, sans-serif;
        }
        body {
          margin: 0;
          background: #f3f4f6;
          color: #111827;
        }
        header {
          padding: 24px;
          background: white;
          border-bottom: 1px solid #e5e7eb;
          position: sticky;
          top: 0;
        }
        main {
          display: grid;
          gap: 16px;
          grid-template-columns: repeat(auto-fit, minmax(320px, 1fr));
          padding: 24px;
        }
        .card {
          background: white;
          border: 1px solid #e5e7eb;
          border-radius: 16px;
          overflow: hidden;
          box-shadow: 0 10px 30px rgba(17, 24, 39, 0.06);
        }
        .meta {
          padding: 16px;
          display: flex;
          flex-direction: column;
          gap: 8px;
        }
        .meta h2 {
          margin: 0;
          font-size: 18px;
        }
        .meta p {
          margin: 0;
          font-size: 13px;
          color: #4b5563;
          word-break: break-word;
        }
        .badge {
          display: inline-flex;
          align-self: flex-start;
          font-size: 12px;
          line-height: 1;
          padding: 6px 10px;
          border-radius: 999px;
          background: #e5e7eb;
        }
        img {
          width: 100%;
          display: block;
          background: #e5e7eb;
        }
        ul {
          margin: 0;
          padding-left: 20px;
          color: #b45309;
        }
      </style>
    </head>
    <body>
      <header>
        <strong>snapview gallery</strong><br>
        <span>\(state.scheme) · \(state.entries.count) previews</span>
      </header>
      <main id="gallery"></main>
      <script>
        const galleryState = \(json);
        const gallery = document.getElementById("gallery");

        for (const entry of galleryState.entries) {
          const warnings = entry.warnings.length
            ? `<ul>${entry.warnings.map((warning) => `<li>${warning}</li>`).join("")}</ul>`
            : "";

          gallery.insertAdjacentHTML(
            "beforeend",
            `
              <section class="card">
                <img src="${entry.imagePath}" alt="${entry.previewName}">
                <div class="meta">
                  <span class="badge">${entry.source}</span>
                  <h2>${entry.previewName}</h2>
                  <p>${entry.sourceFile}</p>
                  <p>${entry.imagePath}</p>
                  ${warnings}
                </div>
              </section>
            `
          );
        }
      </script>
    </body>
    </html>
    """
  }
}
