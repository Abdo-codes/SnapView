# snapview v2.1 Capture Design

## Summary

`snapview` v2 made the local preview workflow solid: `doctor`, `watch`, the persistent host, and the generated gallery now work as a coherent local product. The biggest remaining product gap is coverage. `snapview` still depends on SwiftUI `#Preview` blocks, so it cannot help when a preview crashes or when a screen has no preview at all.

This design adds a second, explicit capture path for those cases. The capture path is manifest-driven, simulator-backed, and deterministic. It does not try to auto-discover navigation or guess app state.

## Goals

- Capture screens that have no usable `#Preview`.
- Provide a fallback path for screens whose preview render fails.
- Keep the product local-first and deterministic.
- Reuse the existing gallery so preview renders and captured screens appear in one surface.
- Validate capture configuration up front through `snapview doctor`.

## Non-Goals

- Do not auto-discover app navigation.
- Do not add a UI tap-script DSL in the first version.
- Do not make `watch` run simulator capture by default.
- Do not add crop heuristics or element-level screenshots in the first version.
- Do not replace preview rendering as the primary fast path.

## Product Direction

The capture system should be explicit and app-authored:

```text
snapview capture Settings --scheme MyApp
snapview capture-all --scheme MyApp
```

The source of truth for non-preview screens is a committed manifest in the target app:

```text
snapview.capture.json
```

That manifest defines named screens and the deterministic strategies `snapview` is allowed to use to reach them.

## Workflow Design

### Capture Manifest

Add a committed manifest at the project root:

```json
{
  "appId": "com.example.myapp",
  "screens": [
    {
      "name": "Settings",
      "strategies": [
        { "type": "preview", "previewName": "Settings" },
        { "type": "deeplink", "url": "myapp://settings" }
      ]
    },
    {
      "name": "Paywall",
      "strategies": [
        { "type": "launch", "arguments": ["--ui-test-screen", "paywall"] }
      ]
    }
  ]
}
```

Rules:

- `name` is the stable screen name shown in CLI output and the gallery.
- `strategies` are ordered. `snapview` tries them in order and stops on the first success.
- A `preview` strategy reuses existing preview-backed rendering when a project wants one manifest entry to describe both the fast path and the fallback path.
- A `deeplink` strategy opens a URL in the simulator.
- A `launch` strategy launches the app with deterministic launch arguments and optional environment.

The manifest is configuration, not generated state, so it should live beside the app project rather than inside `.snapview/`.

### `snapview capture`

`snapview capture <Screen> --scheme <Scheme>` should:

1. Load and validate `snapview.capture.json`.
2. Resolve the named screen.
3. Try each configured strategy in order.
4. Save the resulting PNG into the usual output path.
5. Record the result in the gallery manifest.

This command should not depend on preview scanning unless the selected strategy is `preview`.

### `snapview capture-all`

`snapview capture-all --scheme <Scheme>` should:

1. Load and validate the manifest.
2. Execute every configured screen entry.
3. Merge capture results into the same gallery used by preview rendering.

The goal is one gallery containing both preview renders and captured screens, not two separate output systems.

### Preview Failure Fallback

Preview rendering stays the primary path:

- `render` and `render-all` remain preview-first.
- If a preview render succeeds, no capture path is used.
- If a preview render fails and the manifest contains a same-name screen entry, `snapview` can fall back to capture later.

That fallback should be implemented only after the explicit capture flow is stable. Phase 1 needs to keep failure modes clean and debuggable.

### `snapview doctor`

`doctor` should validate capture configuration before runtime:

- manifest file exists or does not exist cleanly
- JSON structure is valid
- screen names are unique
- strategies are structurally valid
- `deeplink` entries have non-empty URLs
- `launch` entries have valid arguments payloads
- `preview` strategy names point to a known preview when preview scanning is available

The output should explain capture-specific issues as actionable findings, not runtime surprises.

## Architecture

### Keep the Existing Preview Stack

Do not disturb the current preview engine:

- `PreviewScanner`
- `PreviewMatcher`
- `BuildRunner`
- `PreparationStore`
- `HostRunner`
- `HostRuntime`
- `RenderedOutputFinalizer`
- `GalleryStore`

These remain the fast path for preview-backed rendering.

### New Components

#### `CaptureManifest`

A parser and validator for `snapview.capture.json`.

Suggested model:

- `CaptureManifest`
- `CaptureScreen`
- `CaptureStrategy`
- `CaptureStrategy.preview`
- `CaptureStrategy.deeplink`
- `CaptureStrategy.launch`

Responsibilities:

- load JSON
- validate structural rules
- expose lookup by screen name

#### `CaptureRunner`

A coordinator that executes one named capture entry.

Responsibilities:

- resolve the requested screen
- try strategies in order
- report success/failure and warnings
- produce a gallery-compatible output record

#### `SimulatorController`

A small wrapper around `xcrun simctl`.

Responsibilities:

- resolve or boot the requested simulator
- terminate the app when a clean launch is required
- launch the app with arguments and environment
- open deep links

This should stay as a thin boundary around shelling out. Business logic should live above it.

#### `SimulatorScreenshotter`

A boundary for simulator screenshots.

Responsibilities:

- capture a PNG after the app settles
- store it in a stable temporary location before output finalization

The initial version should capture the whole device screen. That is less precise than preview PNGs, but it is the simplest robust starting point.

#### `CaptureStore`

This does not need a separate manifest file. Instead, it should adapt capture results into the existing `GalleryStore` shape.

Recommended gallery additions:

- `renderKind: preview | capture`
- `captureStrategy: preview | deeplink | launch | none`
- warnings array

That keeps one gallery surface while preserving provenance.

## Rendering Behavior

### Phase 1

- `capture` and `capture-all` are explicit commands.
- `watch` stays preview-only.
- `render` and `render-all` do not yet auto-fallback to capture.
- gallery entries can come from either preview rendering or explicit capture.

### Phase 2

- `render` and `render-all` may fall back to capture when a preview fails and a same-name manifest entry exists.
- the gallery must clearly mark those outputs as capture fallbacks instead of successful preview renders.

## Error Handling

Key failure cases:

- manifest missing
- malformed manifest JSON
- unknown screen name
- invalid strategy payload
- simulator unavailable
- app bundle identifier missing
- deep link open failed
- app launch failed
- screenshot capture failed

Each should become a typed error or structured finding. Avoid raw `simctl` stderr leaking straight to the user unless it is wrapped with context.

## Testing Strategy

Follow the same discipline used in v2:

- write failing tests first
- verify the red state
- implement minimally
- verify focused suites, then full `swift test`

New test areas:

- `CaptureManifestTests`
- `CaptureRunnerTests`
- `SimulatorControllerTests`
- `SimulatorScreenshotterTests`
- `DoctorRunnerTests` for manifest validation findings
- `GalleryStoreTests` for capture entry metadata

Design for dependency injection:

- `simctl` execution
- app launch/open URL calls
- screenshot capture
- sleep/wait behavior
- output finalization

## Rollout

### Phase 1: Capture Foundation

- add `snapview.capture.json`
- add manifest parsing and validation
- add `snapview capture`
- add `snapview capture-all`
- add simulator control and screenshot capture
- merge capture entries into the gallery
- extend `doctor` to validate the manifest

### Phase 2: Preview Failure Fallback

- detect preview render failures in `render` and `render-all`
- look for same-name manifest entries
- run capture as a fallback when available
- record preview failure as a warning in the gallery entry

## Recommendation

Start with Phase 1 only. The explicit capture flow is valuable on its own, and it keeps the first version easier to debug. Once explicit capture is stable, Phase 2 can reuse the same manifest and simulator plumbing as a fallback path for preview-backed crashers.
