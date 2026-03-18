# snapview

A macOS CLI that renders SwiftUI `#Preview` blocks to PNG images — giving AI coding assistants visual feedback on the views they build.

snapview is intentionally preview-driven. It renders discovered `#Preview` entries, not arbitrary `View` types with guessed state.

## Why

When you ask an AI to build a SwiftUI view, it has no way to see what the result looks like. snapview bridges that gap: render a preview to disk, hand the PNG back to the AI, iterate visually.

## Requirements

- macOS 14+
- Xcode 15+
- A project with at least one test target
- The test target must either generate its own `Info.plist` (`GENERATE_INFOPLIST_FILE = YES`) or point to a valid `INFOPLIST_FILE`
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

# One-time or after preview/source changes — builds fast render artifacts
snapview prepare --scheme MyApp

# See exactly what snapview can render
snapview list

# Optional — keep a renderer host alive for faster repeated renders
snapview host start --scheme MyApp

# Render previews for a specific view without rebuilding
snapview render ContentView --scheme MyApp

# Output is written to .snapview/
open .snapview/ContentView.png
```

If you just ran `snapview prepare`, restart the host so it picks up the refreshed registry and test bundle:

```sh
snapview host stop
snapview host start --scheme MyApp
```

## What snapview Renders

- `snapview render <ViewName>` matches discovered preview entries by backing view name, preview body, or explicit preview name.
- `snapview render-all` renders every discovered `#Preview` entry in the project.
- `snapview list` shows the exact preview coverage snapview can render.
- If a screen has no `#Preview`, snapview will not render it. Add a `#Preview` block for every screen or state you want in the output set.

Example:

```swift
#Preview("Dashboard") {
  DashboardView(store: .preview)
}

#Preview("Dashboard - Empty State") {
  DashboardView(store: .previewEmpty)
}
```

The example above produces two renderable outputs. If `SettingsView` has no preview, it will not appear in `snapview list` or `snapview render-all`.

## How It Works

1. **Init** — injects the renderer into your test target.
2. **Prepare** — scans project sources for `#Preview` blocks, generates the full registry, and runs `xcodebuild build-for-testing`.
3. **List** — shows the discovered preview set so you can confirm coverage before rendering.
4. **Host** — optionally starts a long-lived XCTest host inside the simulator.
5. **Render** — prefers the running host when present, otherwise falls back to `xcodebuild test-without-building`. Config is passed via JSON files because env vars do not forward through `xcodebuild`.

## CLI Reference

| Command | Description |
|---|---|
| `snapview init --scheme <Scheme>` | One-time setup. Adds renderer to test target. |
| `snapview prepare --scheme <Scheme>` | Build test artifacts for fast renders. |
| `snapview host start --scheme <Scheme>` | Start the persistent renderer host. |
| `snapview host status` | Show the persistent host status. |
| `snapview host stop` | Stop the persistent host. |
| `snapview render <ViewName> --scheme <Scheme>` | Render `#Preview` entries that match a named view or preview name. |
| `snapview render-all --scheme <Scheme>` | Render every discovered `#Preview` block. |
| `snapview list` | List all discovered `#Preview` blocks that snapview can render. |
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

snapview writes PNGs to `.snapview/` in the project root when it can. If the destination directory is not writable, it falls back to the verified runtime output path and prints that path in the command result. Add `.snapview/` to `.gitignore` if you don't want to track renders.

## Troubleshooting

Common recovery paths:

- `snapview list` shows fewer screens than you expected:
  snapview only renders discovered `#Preview` blocks. Add explicit previews for each screen or state you want rendered, then rerun `snapview prepare`.
- `build-for-testing` fails because the test target has no `Info.plist`:
  set `GENERATE_INFOPLIST_FILE = YES` on the test target, or point `INFOPLIST_FILE` at a real plist. `snapview init` configures generated test targets this way, but older hand-made test targets may need repair.
- `render` or `render-all` prints a warning about not being able to copy into `.snapview`:
  use the runtime output path printed by snapview. The render succeeded; only the final copy-back failed.
- `render-all` still shows old previews after you changed preview files:
  rerun `snapview prepare`, then restart the persistent host with `snapview host stop` and `snapview host start --scheme <Scheme>`.
- `render` fails after switching projects, schemes, or test targets:
  the prepared metadata is stale. Rerun `snapview prepare --scheme <Scheme>`.

More detail: [Troubleshooting Guide](/Users/abdoelrhman/Developer/side/snapview/docs/troubleshooting.md)

## Known Limitations

- `prepare` is the slow build step; `host start` removes most of the repeated XCTest startup cost, but the first prepare is still expensive.
- snapview does not auto-instantiate arbitrary SwiftUI views. Add `#Preview` blocks for every screen or state you want rendered.
- Custom fonts may fall back to system fonts.
- `.navigationTitle` and other navigation chrome do not render.
- `@Previewable` macros are not supported.
- `UIViewRepresentable` content renders blank.
