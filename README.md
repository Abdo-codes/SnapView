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

You can either download the latest macOS release asset from GitHub Releases or build from source.

Source install:

```sh
git clone https://github.com/Abdo-codes/SnapView.git
cd SnapView
swift build -c release
install "$(swift build -c release --show-bin-path)/snapview" /usr/local/bin/snapview
```

## Quick Start

```sh
# One-time setup if the project does not already have snapview files
snapview init --scheme MyApp

# Repair or inspect the current project state
snapview doctor --scheme MyApp

# Default day-to-day workflow
snapview watch --scheme MyApp

# Print or regenerate the gallery page path
snapview gallery
```

`watch` is the default local loop. It bootstraps missing or stale prepared artifacts, keeps the persistent host aligned with the latest build, rerenders previews after Swift changes, and refreshes `.snapview/gallery.html`.

## Smoke Workflow

Use the integration smoke script to verify a real project end to end:

```sh
scripts/integration-smoke.sh \
  --scheme MyApp \
  --project /path/to/MyApp.xcodeproj
```

Use `--workspace /path/to/MyApp.xcworkspace` instead of `--project` when the app is built from a workspace. Add `--watch` when you want the script to wait for one successful preview refresh before exiting. Set `SNAPVIEW_BIN` to point the script at a specific snapview binary instead of the default `.build/debug/snapview`.

If you want the explicit primitives, they still exist:

```sh
snapview prepare --scheme MyApp
snapview host start --scheme MyApp
snapview render ContentView --scheme MyApp
snapview render-all --scheme MyApp
snapview list
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

1. **Doctor** — inspects project health and reports actionable fixes for preview coverage, test-target setup, prepared-state drift, host drift, and output fallback.
2. **Prepare** — scans project sources for `#Preview` blocks, generates the full registry, and runs `xcodebuild build-for-testing`.
3. **Host** — runs a long-lived XCTest host inside the simulator for near-instant repeated renders.
4. **Render** — prefers the running host when present, otherwise falls back to `xcodebuild test-without-building`. Config is passed via JSON files because env vars do not forward through `xcodebuild`.
5. **Gallery** — persists `.snapview/gallery.json` and `.snapview/gallery.html` so the local output has a stable surface.
6. **Watch** — polls Swift files under the app source root, debounces change bursts, re-prepares when needed, restarts stale hosts, rerenders the preview set, and refreshes the gallery.

## CLI Reference

| Command | Description |
|---|---|
| `snapview init --scheme <Scheme>` | One-time setup. Adds renderer to test target. |
| `snapview doctor --scheme <Scheme>` | Inspect project health and print suggested fixes. |
| `snapview gallery` | Print or regenerate the local gallery page path. |
| `snapview prepare --scheme <Scheme>` | Build test artifacts for fast renders. |
| `snapview host start --scheme <Scheme>` | Start the persistent renderer host. |
| `snapview host status` | Show the persistent host status. |
| `snapview host stop` | Stop the persistent host. |
| `snapview watch --scheme <Scheme>` | Run the local preview studio loop as Swift files change. |
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

snapview writes PNGs to `.snapview/` in the project root when it can. It also maintains:

- `.snapview/gallery.json` as the local manifest
- `.snapview/gallery.html` as the generated gallery page

If the destination directory is not writable, snapview falls back to the verified runtime output path and records those PNG paths in the gallery instead of failing the render. Add `.snapview/` to `.gitignore` if you don't want to track renders.

## Troubleshooting

Common recovery paths:

- `snapview list` shows fewer screens than you expected:
  snapview only renders discovered `#Preview` blocks. Add explicit previews for each screen or state you want rendered, then rerun `snapview prepare`.
- `snapview watch` is your default loop, but it exits immediately:
  run `snapview doctor --scheme <Scheme>` first. `watch` can repair stale preparation state by running its own `prepare`, but it still stops for real project errors such as missing previews or broken test-target setup.
- `build-for-testing` fails because the test target has no `Info.plist`:
  set `GENERATE_INFOPLIST_FILE = YES` on the test target, or point `INFOPLIST_FILE` at a real plist. `snapview init` configures generated test targets this way, but older hand-made test targets may need repair.
- `render` or `render-all` prints a warning about not being able to copy into `.snapview`:
  use the runtime output path printed by snapview. The render succeeded; only the final copy-back failed.
- `render-all` or `watch` still shows old previews after you changed preview files:
  rerun `snapview prepare`. `watch` restarts stale hosts automatically after a successful prepare, but an already-running manual host may still need `snapview host stop` and `snapview host start --scheme <Scheme>`.
- `watch` keeps retrying the same broken edit:
  it should not. `watch` now settles on the failed snapshot and waits for the next file change before trying again. If it still loops, restart `watch` and rerun `snapview doctor --scheme <Scheme>` to check for drift outside the watched source root.
- `render` fails after switching projects, schemes, or test targets:
  the prepared metadata is stale. Rerun `snapview prepare --scheme <Scheme>`.

More detail: [Troubleshooting Guide](docs/troubleshooting.md)

## Contributing

Contributions are welcome. Start with [CONTRIBUTING.md](CONTRIBUTING.md) for local setup, verification expectations, and PR scope.

## Security

For sensitive reports, use the private process in [SECURITY.md](SECURITY.md) instead of opening a public issue.

## License

`snapview` is released under the [MIT License](LICENSE).

## Known Limitations

- `prepare` is the slow build step; `host start` removes most of the repeated XCTest startup cost, but the first prepare is still expensive.
- snapview does not auto-instantiate arbitrary SwiftUI views. Add `#Preview` blocks for every screen or state you want rendered.
- `watch` uses a polling file snapshot loop in v2. It optimizes for determinism and testability over instant filesystem notifications.
- Custom fonts may fall back to system fonts.
- `.navigationTitle` and other navigation chrome do not render.
- `@Previewable` macros are not supported.
- `UIViewRepresentable` content renders blank.
