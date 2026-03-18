# snapview v2.1 Capture Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add manifest-driven simulator capture for non-preview screens and future preview-failure fallback, while keeping preview rendering as the primary fast path.

**Architecture:** Introduce a committed `snapview.capture.json` manifest, a capture runner that executes ordered strategies, and simulator boundaries for deep link, launch, and screenshot capture. Phase 1 adds explicit `capture` and `capture-all` plus doctor validation and gallery integration. Phase 2 adds preview-failure fallback that reuses the same manifest and capture runner.

**Tech Stack:** Swift 6, ArgumentParser, XCTest, `xcrun simctl`, existing `.snapview` gallery state, file-based output finalization, injected shell boundaries for testability.

---

## Phase 1: Capture Foundation

### Task 1: Add capture manifest models and parsing

**Files:**
- Create: `Sources/snapview/Capture/CaptureManifest.swift`
- Create: `Tests/SnapviewTests/CaptureManifestTests.swift`

**Step 1: Write the failing tests**

Add tests that prove:
- valid JSON decodes into named screens with ordered strategies
- duplicate screen names are rejected
- malformed `deeplink` and `launch` strategy payloads are rejected

Use shapes like:

```swift
@Test
func decodesManifestWithPreviewAndDeeplinkStrategies() throws {
  let manifest = try CaptureManifest.parse(
    Data("""
    {
      "appId": "com.example.app",
      "screens": [
        {
          "name": "Settings",
          "strategies": [
            { "type": "preview", "previewName": "Settings" },
            { "type": "deeplink", "url": "myapp://settings" }
          ]
        }
      ]
    }
    """.utf8)
  )

  #expect(manifest.screens.count == 1)
  #expect(manifest.screens[0].name == "Settings")
}
```

**Step 2: Run test to verify it fails**

Run:

```bash
swift test --filter CaptureManifestTests
```

Expected:
- FAIL because `CaptureManifest` and capture strategy types do not exist yet

**Step 3: Write the minimal implementation**

Implement:
- `CaptureManifest`
- `CaptureScreen`
- `CaptureStrategy`
- parse/load helpers
- validation that returns typed manifest errors

Keep JSON parsing and validation together for now. Do not wire it into commands yet.

**Step 4: Run test to verify it passes**

Run:

```bash
swift test --filter CaptureManifestTests
```

Expected:
- PASS

**Step 5: Commit**

```bash
git add Sources/snapview/Capture/CaptureManifest.swift Tests/SnapviewTests/CaptureManifestTests.swift
git commit -m "feat: add capture manifest parsing"
```

### Task 2: Add simulator control and screenshot boundaries

**Files:**
- Create: `Sources/snapview/Capture/SimulatorController.swift`
- Create: `Sources/snapview/Capture/SimulatorScreenshotter.swift`
- Create: `Tests/SnapviewTests/SimulatorControllerTests.swift`
- Create: `Tests/SnapviewTests/SimulatorScreenshotterTests.swift`

**Step 1: Write the failing tests**

Add tests that prove:
- deep link strategy shells out through the injected simulator client
- launch strategy shells out with app id, launch arguments, and optional environment
- screenshot capture writes to a stable target path and surfaces errors with context

Use shapes like:

```swift
@Test
func launchBuildsExpectedSimctlArguments() throws {
  let recorder = SimctlRecorder()
  let controller = SimulatorController(run: recorder.run)

  try controller.launch(
    appId: "com.example.app",
    device: "booted",
    arguments: ["--ui-test-screen", "paywall"],
    environment: ["SNAPVIEW_CAPTURE": "1"]
  )

  #expect(recorder.commands.last == [
    "simctl", "launch", "booted", "com.example.app", "--ui-test-screen", "paywall"
  ])
}
```

**Step 2: Run test to verify it fails**

Run:

```bash
swift test --filter 'SimulatorControllerTests|SimulatorScreenshotterTests'
```

Expected:
- FAIL because the simulator abstractions do not exist yet

**Step 3: Write the minimal implementation**

Implement thin boundaries only:
- `SimulatorController`
- `SimulatorScreenshotter`

Inject command execution instead of binding tests to real `simctl`.

**Step 4: Run test to verify it passes**

Run:

```bash
swift test --filter 'SimulatorControllerTests|SimulatorScreenshotterTests'
```

Expected:
- PASS

**Step 5: Commit**

```bash
git add Sources/snapview/Capture/SimulatorController.swift Sources/snapview/Capture/SimulatorScreenshotter.swift Tests/SnapviewTests/SimulatorControllerTests.swift Tests/SnapviewTests/SimulatorScreenshotterTests.swift
git commit -m "feat: add simulator capture boundaries"
```

### Task 3: Add capture runner and gallery integration

**Files:**
- Create: `Sources/snapview/Capture/CaptureRunner.swift`
- Modify: `Sources/snapview/Runner/GalleryStore.swift`
- Create: `Tests/SnapviewTests/CaptureRunnerTests.swift`
- Modify: `Tests/SnapviewTests/GalleryStoreTests.swift`

**Step 1: Write the failing tests**

Add tests that prove:
- `CaptureRunner` tries strategies in order and stops at the first success
- a successful capture result becomes a gallery entry
- gallery entries preserve `renderKind` and `captureStrategy`

Use shapes like:

```swift
@Test
func captureRunnerFallsThroughToDeeplinkAfterPreviewFailure() throws {
  let runner = CaptureRunner(
    renderPreview: { _ in throw CaptureRunner.Error.previewFailed("boom") },
    openURL: { _ in },
    launchApp: { _, _, _ in },
    takeScreenshot: { "/tmp/Settings.png" },
    finalizeOutput: { path in path }
  )

  let result = try runner.capture(
    screen: .fixture(
      name: "Settings",
      strategies: [
        .preview(previewName: "Settings"),
        .deeplink(url: "myapp://settings")
      ]
    )
  )

  #expect(result.captureStrategy == .deeplink)
}
```

**Step 2: Run test to verify it fails**

Run:

```bash
swift test --filter 'CaptureRunnerTests|GalleryStoreTests'
```

Expected:
- FAIL because capture execution and gallery metadata do not exist yet

**Step 3: Write the minimal implementation**

Implement:
- `CaptureRunner`
- typed capture result model
- gallery metadata additions for capture provenance

Keep `CaptureRunner` injected. Do not wire CLI yet.

**Step 4: Run test to verify it passes**

Run:

```bash
swift test --filter 'CaptureRunnerTests|GalleryStoreTests'
```

Expected:
- PASS

**Step 5: Commit**

```bash
git add Sources/snapview/Capture/CaptureRunner.swift Sources/snapview/Runner/GalleryStore.swift Tests/SnapviewTests/CaptureRunnerTests.swift Tests/SnapviewTests/GalleryStoreTests.swift
git commit -m "feat: add capture runner and gallery metadata"
```

### Task 4: Add `snapview capture` and `snapview capture-all`

**Files:**
- Create: `Sources/snapview/Commands/CaptureCommand.swift`
- Create: `Sources/snapview/Commands/CaptureAllCommand.swift`
- Modify: `Sources/snapview/SnapviewCommand.swift`
- Create: `Tests/SnapviewTests/CaptureCommandTests.swift`

**Step 1: Write the failing tests**

Add tests that prove:
- command help and registration exist
- `capture` resolves a named manifest screen
- `capture-all` executes every screen and updates the gallery

Use formatter/helper-level tests where possible instead of subprocess-heavy tests.

**Step 2: Run test to verify it fails**

Run:

```bash
swift test --filter CaptureCommandTests
```

Expected:
- FAIL because no capture commands are registered

**Step 3: Write the minimal implementation**

Add:
- `snapview capture <Screen> --scheme <Scheme>`
- `snapview capture-all --scheme <Scheme>`

Reuse:
- project detection
- simulator selection flags
- gallery persistence
- output finalization

Keep CLI surface parallel to existing render commands. Do not add preview-failure fallback yet.

**Step 4: Run tests and smoke checks**

Run:

```bash
swift test --filter CaptureCommandTests
swift build
.build/debug/snapview capture --help
.build/debug/snapview capture-all --help
```

Expected:
- PASS

**Step 5: Commit**

```bash
git add Sources/snapview/Commands/CaptureCommand.swift Sources/snapview/Commands/CaptureAllCommand.swift Sources/snapview/SnapviewCommand.swift Tests/SnapviewTests/CaptureCommandTests.swift
git commit -m "feat: add explicit capture commands"
```

### Task 5: Extend doctor to validate the capture manifest

**Files:**
- Modify: `Sources/snapview/Runner/DoctorRunner.swift`
- Modify: `Sources/snapview/Commands/DoctorCommand.swift`
- Modify: `Tests/SnapviewTests/DoctorRunnerTests.swift`

**Step 1: Write the failing tests**

Add tests that prove:
- malformed manifest becomes a structured doctor error
- duplicate screen names become structured findings
- invalid preview references inside manifest become doctor warnings or errors

**Step 2: Run test to verify it fails**

Run:

```bash
swift test --filter DoctorRunnerTests
```

Expected:
- FAIL because doctor does not know about capture manifest validation yet

**Step 3: Write the minimal implementation**

Extend `DoctorRunner` to:
- load the capture manifest if present
- validate it
- surface capture findings in the existing grouped output

Do not persist separate doctor JSON yet.

**Step 4: Run test to verify it passes**

Run:

```bash
swift test --filter DoctorRunnerTests
```

Expected:
- PASS

**Step 5: Commit**

```bash
git add Sources/snapview/Runner/DoctorRunner.swift Sources/snapview/Commands/DoctorCommand.swift Tests/SnapviewTests/DoctorRunnerTests.swift
git commit -m "feat: validate capture manifests in doctor"
```

### Task 6: Document the explicit capture workflow

**Files:**
- Modify: `README.md`
- Modify: `docs/troubleshooting.md`
- Modify: `docs/plans/2026-03-18-snapview-v2-1-capture-design.md`

**Step 1: Write the failing test**

Add one focused command-output or formatter test if the CLI text needs new capture-specific wording. Prefer not to add doc-only tests.

**Step 2: Run test to verify it fails**

Run:

```bash
swift test --filter 'DoctorRunnerTests|CaptureCommandTests'
```

Expected:
- FAIL if new output wording is required

**Step 3: Write the minimal implementation**

Update docs to cover:
- `snapview.capture.json`
- `capture`
- `capture-all`
- how capture and preview entries share the gallery
- why `watch` remains preview-only in v2.1

**Step 4: Run full verification**

Run:

```bash
swift test
swift build
```

Expected:
- PASS

Then run a manual real-project smoke pass against an app that defines a capture manifest:

```bash
.build/debug/snapview doctor --scheme MyApp --project /path/to/MyApp.xcodeproj
.build/debug/snapview capture-all --scheme MyApp --project /path/to/MyApp.xcodeproj
.build/debug/snapview gallery --project /path/to/MyApp.xcodeproj
```

Expected:
- doctor validates the manifest
- capture-all produces PNGs
- gallery contains capture entries

**Step 5: Commit**

```bash
git add README.md docs/troubleshooting.md docs/plans/2026-03-18-snapview-v2-1-capture-design.md
git commit -m "docs: describe explicit capture workflow"
```

## Phase 2: Preview Failure Fallback

### Task 7: Add capture fallback to `render`

**Files:**
- Modify: `Sources/snapview/Commands/RenderCommand.swift`
- Modify: `Sources/snapview/Capture/CaptureRunner.swift`
- Modify: `Tests/SnapviewTests/RenderMessagingTests.swift`
- Create: `Tests/SnapviewTests/RenderCaptureFallbackTests.swift`

**Step 1: Write the failing test**

Add tests that prove:
- when preview rendering fails for a named screen and the manifest has a same-name entry, `render` falls back to capture
- the resulting gallery entry is marked as capture fallback, not successful preview render

**Step 2: Run test to verify it fails**

Run:

```bash
swift test --filter 'RenderCaptureFallbackTests|RenderMessagingTests'
```

Expected:
- FAIL because preview-failure fallback does not exist yet

**Step 3: Write the minimal implementation**

Update `RenderCommand` to:
- detect preview-render failure
- look up a same-name capture entry
- invoke `CaptureRunner`
- append a warning describing the preview failure

Keep success/failure messaging explicit. Avoid swallowing real errors when no fallback exists.

**Step 4: Run test to verify it passes**

Run:

```bash
swift test --filter 'RenderCaptureFallbackTests|RenderMessagingTests'
```

Expected:
- PASS

**Step 5: Commit**

```bash
git add Sources/snapview/Commands/RenderCommand.swift Sources/snapview/Capture/CaptureRunner.swift Tests/SnapviewTests/RenderMessagingTests.swift Tests/SnapviewTests/RenderCaptureFallbackTests.swift
git commit -m "feat: add render capture fallback"
```

### Task 8: Add capture fallback to `render-all`

**Files:**
- Modify: `Sources/snapview/Commands/RenderAllCommand.swift`
- Modify: `Tests/SnapviewTests/RenderCaptureFallbackTests.swift`

**Step 1: Write the failing test**

Add tests that prove:
- `render-all` continues after a preview failure when a capture fallback exists
- the final gallery preserves which entries came from preview render and which came from capture fallback

**Step 2: Run test to verify it fails**

Run:

```bash
swift test --filter RenderCaptureFallbackTests
```

Expected:
- FAIL because render-all fallback orchestration does not exist yet

**Step 3: Write the minimal implementation**

Update `RenderAllCommand.perform` to:
- attempt preview rendering entry-by-entry or in a way that preserves per-entry fallback handling
- invoke capture fallback where configured
- keep final reporting readable for mixed preview/capture runs

Do not broaden scope into watch-triggered capture.

**Step 4: Run test to verify it passes**

Run:

```bash
swift test --filter RenderCaptureFallbackTests
```

Expected:
- PASS

**Step 5: Commit**

```bash
git add Sources/snapview/Commands/RenderAllCommand.swift Tests/SnapviewTests/RenderCaptureFallbackTests.swift
git commit -m "feat: add render-all capture fallback"
```

### Task 9: Final verification and merge prep

**Files:**
- Review the full diff

**Step 1: Run full verification**

Run:

```bash
swift test
swift build
```

Expected:
- PASS

**Step 2: Run real-project verification**

Against a project with both preview entries and a `snapview.capture.json` manifest:

```bash
.build/debug/snapview doctor --scheme MyApp --project /path/to/MyApp.xcodeproj
.build/debug/snapview render-all --scheme MyApp --project /path/to/MyApp.xcodeproj
.build/debug/snapview capture-all --scheme MyApp --project /path/to/MyApp.xcodeproj
.build/debug/snapview gallery --project /path/to/MyApp.xcodeproj
```

Expected:
- explicit capture works
- preview-backed screens still render through the fast path
- configured preview failures fall back to capture when Phase 2 lands
- gallery provenance is clear

**Step 3: Request code review**

Run the repo’s review workflow before merging.

**Step 4: Commit final polish if needed**

```bash
git add <files>
git commit -m "chore: polish capture workflow"
```
