# snapview

A macOS CLI that renders SwiftUI `#Preview` blocks to PNG images — giving AI coding assistants visual feedback on the views they build.

## Why

When you ask an AI to build a SwiftUI view, it has no way to see what the result looks like. snapview bridges that gap: render a preview to disk, hand the PNG back to the AI, iterate visually.

## Requirements

- macOS 14+
- Xcode 15+
- A project with at least one test target
- Views must have `#Preview` blocks

## Install

```sh
git clone https://github.com/yourname/snapview
cd snapview
swift build -c release
cp .build/release/snapview /usr/local/bin/
```

## Quick Start

```sh
# One-time setup — adds the renderer to your test target
snapview init --scheme MyApp

# Render previews for a specific view
snapview render ContentView --scheme MyApp

# Output is written to .snapview/
open .snapview/ContentView.png
```

## How It Works

1. **Init** — scans source files for `#Preview` blocks using brace-balanced parsing, generates a registry mapping view names to preview bodies, and injects a renderer into your test target.
2. **Render** — runs a targeted `xcodebuild test` with `ImageRenderer` to produce PNGs. Config is passed via a JSON file (env vars do not forward through xcodebuild).

## CLI Reference

| Command | Description |
|---|---|
| `snapview init --scheme <Scheme>` | One-time setup. Adds renderer to test target. |
| `snapview render <ViewName> --scheme <Scheme>` | Render previews for a named view. |
| `snapview render-all --scheme <Scheme>` | Render every discovered `#Preview` block. |
| `snapview list` | List all discovered `#Preview` blocks. |
| `snapview clean` | Remove the `.snapview/` output directory. |

### Render Flags

| Flag | Description |
|---|---|
| `--rtl` | Render in right-to-left layout direction |
| `--locale <id>` | Set locale (e.g. `ar`, `fr-FR`) |
| `--scale <1\|2\|3>` | Screen scale factor |
| `--device <name>` | Device display name |
| `--simulator <id>` | Simulator UDID or name |

## Output

All PNGs are written to `.snapview/` in the project root. Add it to `.gitignore` if you don't want to track renders.

## Known Limitations

- First render takes ~30s (cold build); incremental renders ~10s.
- Custom fonts may fall back to system fonts.
- `.navigationTitle` and other navigation chrome do not render.
- `@Previewable` macros are not supported.
- `UIViewRepresentable` content renders blank.
