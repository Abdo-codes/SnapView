# snapview v2 Local Studio Design

## Summary

`snapview` v1 proves the renderer architecture is viable: preview-driven discovery, prepared test artifacts, a persistent XCTest host, and gallery-style output all work against real projects. The main gaps are no longer the core render path. They are setup friction, stale-state confusion, and the lack of a single local workflow that feels like a product instead of a toolbox.

This design takes `snapview` to a local-first v2. The goal is not CI orchestration or arbitrary view instantiation. The goal is to make `snapview` feel like a local preview studio for developers and agents.

## Goals

- Make setup and repair obvious with a first-class diagnostics command.
- Collapse the local edit-to-image loop into one primary command.
- Replace hand-built gallery pages with a stable generated gallery surface.
- Keep the current preview-driven, host-based render engine.
- Preserve explicit primitives (`init`, `prepare`, `render`, `render-all`, `host`) for scripts and debugging.

## Non-Goals

- Do not add CI-first workflows in this version.
- Do not auto-instantiate arbitrary SwiftUI views without `#Preview`.
- Do not replace XCTest hosting with a custom runtime.
- Do not add simulator-capture fallback yet. That can be a later v2.1 feature.

## Product Direction

The core product idea is:

```text
snapview watch --scheme MyApp
```

For healthy projects, that should be the main entry point. Everything else supports that loop.

The user experience should become:

1. Run `snapview doctor --scheme MyApp` when onboarding or when something breaks.
2. Run `snapview watch --scheme MyApp` while editing previews and views.
3. View a stable generated gallery instead of manually opening PNGs.

The existing commands remain, but they stop being the primary mental model for normal use.

## Workflow Design

### `snapview doctor`

`doctor` is the repair entry point. It should perform structured checks and emit actionable findings, not raw command failures.

Checks should include:

- project detection succeeded
- expected test target exists
- test target has either `GENERATE_INFOPLIST_FILE = YES` or a valid `INFOPLIST_FILE`
- previews are discoverable
- destination resolution works
- prepared metadata exists and matches the current project/scheme/test target
- host metadata exists and matches prepared state
- output directory is writable, or fallback runtime output will be required

Each finding should have:

- severity: `ok`, `warning`, or `error`
- machine-readable code
- human-readable explanation
- suggested fix

### `snapview watch`

`watch` becomes the local studio loop. It should:

- detect source changes under the project root
- debounce bursts of edits
- rerun `prepare` when Swift source changes affect the app/test bundle
- restart the persistent host after successful preparation
- rerender the preview set and refresh the gallery manifest
- optionally open the gallery the first time renders succeed

The first implementation should optimize for determinism over sophistication:

- watch all `.swift` files under the source root with a file-snapshot polling loop
- after a successful `prepare`, rerender the full preview set

That is intentionally simpler than dependency-aware incremental rendering. The persistent host already makes `render-all` fast enough for medium local projects, and the file-snapshot approach is easier to test than FSEvents-heavy code.

### `snapview gallery`

`gallery` becomes the stable visual surface. It should:

- generate `.snapview/gallery.html`
- be backed by `.snapview/gallery.json`
- optionally open the gallery in the default browser

The browser-facing HTML should be generic. The manifest is the source of truth. The generated page can embed the manifest at generation time to avoid `file://` fetch restrictions.

## Architecture

The v2 architecture keeps the current renderer stack and adds orchestration around it.

### Existing Core To Keep

- `PreviewScanner`
- `PreviewMatcher`
- `BuildRunner`
- `PreparationStore`
- `HostRunner`
- `HostRuntime`
- `RenderedOutputFinalizer`

These are now stable enough to treat as infrastructure.

### New Components

#### `ProjectHealth`

A structured model for project readiness and drift. This should live near the project-validation layer and describe everything `doctor` needs to report.

Suggested fields:

- detected project/workspace path
- detected source root
- expected scheme and test target
- preview count
- destination status
- test target plist status
- prepared state status
- host state status
- output directory writability
- findings array

#### `DoctorRunner`

A read-mostly coordinator that composes:

- project detection
- project validation
- destination lookup
- preview discovery
- prepared-state validation
- host-state validation
- output-path checks

It returns `ProjectHealth`, which both the CLI and future machine-readable modes can consume.

#### `HostSupervisor`

A thin lifecycle wrapper around host start/stop/status rules. This avoids duplicating host restart logic between explicit host commands and `watch`.

Responsibilities:

- compare prepared state to current host state
- determine whether restart is required
- stop stale host
- start a fresh host after successful `prepare`

#### `GalleryStore`

A manifest layer saved under `.snapview/gallery.json`.

Suggested entry fields:

- preview name
- file path where the preview was declared
- resolved PNG path
- whether the output came from project `.snapview` or runtime fallback
- last rendered timestamp
- render status
- warnings

Top-level metadata should include:

- project path
- scheme
- test target
- render root
- render duration
- preview count
- last updated timestamp

#### `GalleryPageGenerator`

A generator that emits a stable self-contained HTML page from `GalleryStore`. This replaces the current ad hoc hand-built gallery pages used during verification.

#### `WatchRunner`

A long-lived coordinator that:

- snapshots file mtimes under the source root
- computes changed paths
- debounces change bursts
- triggers `prepare`
- asks `HostSupervisor` for a restart when needed
- runs `render-all`
- updates `GalleryStore`

## State Model

Keep:

- `.snapview/prepare.json`
- `.snapview/host.json`

Add:

- `.snapview/gallery.json`
- `.snapview/gallery.html`
- optional `.snapview/doctor.json` if persisted diagnostics become useful later

`gallery.json` becomes the canonical local-view state. HTML is generated from it, not the other way around.

## Command Surface

### New commands

- `snapview doctor --scheme <Scheme>`
- `snapview watch --scheme <Scheme>`
- `snapview gallery`

### Existing commands that should change behavior

- `prepare`
  should remain the explicit build step, but be reused by `watch`.
- `render` and `render-all`
  should update `gallery.json` and `gallery.html` after successful output finalization.
- `host start/stop/status`
  should internally reuse `HostSupervisor` rules.

## Testing Strategy

This version should be built with the same discipline as v1:

- write failing tests first
- verify the red state
- implement minimally
- verify focused tests, then full `swift test`

New test areas:

- `DoctorRunnerTests`
- `ProjectHealthTests`
- `HostSupervisorTests`
- `GalleryStoreTests`
- `GalleryPageGeneratorTests`
- `WatchRunnerTests`

`WatchRunner` should be designed for testability by injecting:

- file snapshot provider
- clock/sleep
- prepare function
- host supervisor
- render function
- gallery writer

The first watch implementation should avoid directly binding business logic to `DispatchSource` or raw filesystem APIs. Keep those at the boundary.

## Rollout Plan

### Phase 1: Repairability

- add `doctor`
- add structured health checks
- add gallery manifest + generated gallery page
- update render commands to refresh gallery state

Outcome:
- users can diagnose and recover from broken project setups without manual spelunking

### Phase 2: Local Studio Loop

- add `watch`
- auto-run `prepare`
- auto-restart host when preparation changes
- auto-run `render-all`
- auto-refresh gallery

Outcome:
- one-command local edit-to-image loop

### Phase 3: Polish

- add cleaner status summaries
- add machine-readable output modes
- reduce unnecessary host restarts
- optionally auto-open gallery on first successful render

Outcome:
- a stable local-first product surface

## Inspiration and Prior Art

This direction is informed by:

- `steipete/Poltergeist` for project-aware background workflow orchestration
- `steipete/Peekaboo` for structured local-tool ergonomics and durable session UX
- `EmergeTools/SnapshotPreviews` as the closest open-source analogue for preview discovery, gallery generation, and XCTest-based render workflows

The key conclusion from that survey is that v2 should invest in orchestration and usability, not another major renderer rewrite.

## Open Questions

- Should `gallery` open by default, or only with `--open`?
- Should `doctor` support a machine-readable `--json` mode in the first iteration, or come in phase 3?
- Should `watch` always rerender the full set, or support an opt-in changed-only mode later?

## Recommendation

Ship v2 as a local-first studio:

- `doctor` to repair setups
- `watch` to own the local loop
- `gallery.json` + generated `gallery.html` to stabilize the visual surface

Do not broaden scope into simulator fallback capture or arbitrary view rendering until this workflow is solid.
