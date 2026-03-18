# snapview v2 Local Studio Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Turn `snapview` into a local-first preview studio with `doctor`, `watch`, and a generated gallery surface backed by structured local state.

**Architecture:** Keep the current preview-driven render engine, prepared test artifacts, and persistent host. Add an orchestration layer around them: a health model for diagnostics, a gallery manifest and page generator, a host supervisor, and a watch coordinator that owns the local edit-to-image loop.

**Tech Stack:** Swift 6, ArgumentParser, XCTest, file-based runtime state under `.snapview/`, `xcodebuild build-for-testing`, `xcodebuild test-without-building`, generated HTML gallery output.

---

### Task 1: Add project health model and doctor runner

**Files:**
- Create: `Sources/snapview/Runner/ProjectHealth.swift`
- Create: `Sources/snapview/Runner/DoctorRunner.swift`
- Create: `Tests/SnapviewTests/DoctorRunnerTests.swift`
- Modify: `Sources/snapview/Project/ProjectValidator.swift`
- Modify: `Sources/snapview/Runner/PreparationStore.swift`
- Modify: `Sources/snapview/Runner/HostStore.swift`

**Step 1: Write the failing tests**

Add focused tests that prove:
- a missing test target plist becomes a structured `error` finding
- stale prepare metadata becomes a structured `warning` or `error`
- missing previews become a structured finding
- writable-output fallback becomes a structured warning instead of a hard failure

Use a shape like:

```swift
@Test
func doctorReportsMissingGeneratedInfoPlist() throws {
  let health = try DoctorRunner.run(
    project: .fixture(
      sourceRoot: "/tmp/App",
      projectPath: "/tmp/App/App.xcodeproj",
      testTargetName: "AppTests"
    ),
    previewEntries: [.fixture(name: "Dashboard")],
    buildSettings: .fixture(generateInfoPlist: false, infoPlistPath: nil),
    preparedState: nil,
    hostState: nil,
    outputWritable: true
  )

  #expect(health.findings.contains { $0.code == .missingTestTargetInfoPlist })
}
```

**Step 2: Run test to verify it fails**

Run:

```bash
swift test --filter DoctorRunnerTests
```

Expected:
- FAIL because `ProjectHealth`, `DoctorRunner`, and doctor-specific finding codes do not exist yet

**Step 3: Write the minimal implementation**

Create `ProjectHealth.swift` with:
- `ProjectHealth`
- `HealthFinding`
- `HealthFinding.Severity`
- `HealthFinding.Code`

Create `DoctorRunner.swift` with a focused entry point:

```swift
enum DoctorRunner {
  static func run(...) throws -> ProjectHealth
}
```

Keep it dependency-injected. Do not bind it to CLI parsing yet.

Move or add the narrow validation helpers needed for:
- preview count
- plist generation state
- prepare-state drift
- host-state drift
- output-directory writability

**Step 4: Run test to verify it passes**

Run:

```bash
swift test --filter DoctorRunnerTests
```

Expected:
- PASS

**Step 5: Commit**

```bash
git add Sources/snapview/Runner/ProjectHealth.swift Sources/snapview/Runner/DoctorRunner.swift Sources/snapview/Project/ProjectValidator.swift Sources/snapview/Runner/PreparationStore.swift Sources/snapview/Runner/HostStore.swift Tests/SnapviewTests/DoctorRunnerTests.swift
git commit -m "feat: add project health diagnostics model"
```

### Task 2: Add `snapview doctor`

**Files:**
- Create: `Sources/snapview/Commands/DoctorCommand.swift`
- Modify: `Sources/snapview/SnapviewCommand.swift`
- Modify: `Sources/snapview/Project/ProjectDetector.swift`
- Test: `Tests/SnapviewTests/DoctorRunnerTests.swift`

**Step 1: Write the failing test**

Add a focused test for doctor output formatting at the runner/formatter level rather than CLI subprocess tests:

```swift
@Test
func doctorFormatsGroupedFindings() throws {
  let text = DoctorCommandRenderer.render(
    .fixture(findings: [
      .init(severity: .error, code: .missingTestTargetInfoPlist, message: "Missing Info.plist", fix: "Set GENERATE_INFOPLIST_FILE = YES")
    ])
  )

  #expect(text.contains("[error]"))
  #expect(text.contains("GENERATE_INFOPLIST_FILE"))
}
```

If a formatter type feels unnecessary, keep it as an internal helper near `DoctorCommand`.

**Step 2: Run test to verify it fails**

Run:

```bash
swift test --filter DoctorRunnerTests
```

Expected:
- FAIL because no doctor command rendering exists yet

**Step 3: Write the minimal implementation**

Add `DoctorCommand` with:
- `--scheme`
- standard `--project`, `--workspace`, `--test-target` options
- output that prints findings grouped by severity
- success output when the project is healthy

Register it in `SnapviewCommand.swift`.

Reuse `DoctorRunner`; do not duplicate validation logic inside the command.

**Step 4: Run tests and a manual smoke check**

Run:

```bash
swift test --filter DoctorRunnerTests
swift build
.build/debug/snapview doctor --help
```

Expected:
- tests PASS
- build PASS
- help output lists the new command

**Step 5: Commit**

```bash
git add Sources/snapview/Commands/DoctorCommand.swift Sources/snapview/SnapviewCommand.swift Sources/snapview/Project/ProjectDetector.swift Tests/SnapviewTests/DoctorRunnerTests.swift
git commit -m "feat: add doctor command"
```

### Task 3: Add gallery manifest and page generator

**Files:**
- Create: `Sources/snapview/Runner/GalleryStore.swift`
- Create: `Sources/snapview/Generator/GalleryPageGenerator.swift`
- Create: `Tests/SnapviewTests/GalleryStoreTests.swift`
- Create: `Tests/SnapviewTests/GalleryPageGeneratorTests.swift`

**Step 1: Write the failing tests**

Add tests that prove:
- `GalleryStore` can save and load entries under `.snapview/gallery.json`
- entries preserve preview name, source file, PNG path, fallback/runtime flag, warnings, and timestamp
- `GalleryPageGenerator` emits self-contained HTML with embedded entry data

Use shapes like:

```swift
@Test
func galleryStoreRoundTripsManifest() throws {
  let state = GalleryState(
    projectPath: "/tmp/App/App.xcodeproj",
    scheme: "App",
    entries: [
      .init(
        previewName: "Dashboard",
        sourceFile: "Features/Dashboard/DashboardView.swift",
        imagePath: "/tmp/runtime/Dashboard.png",
        source: .runtimeFallback,
        warnings: ["copy-back failed"]
      )
    ]
  )

  try GalleryStore.save(state, sourceRoot: "/tmp/App")
  let loaded = try GalleryStore.load(sourceRoot: "/tmp/App")

  #expect(loaded.entries.count == 1)
  #expect(loaded.entries[0].source == .runtimeFallback)
}
```

**Step 2: Run test to verify it fails**

Run:

```bash
swift test --filter GalleryStoreTests
swift test --filter GalleryPageGeneratorTests
```

Expected:
- FAIL because gallery types and generator do not exist yet

**Step 3: Write the minimal implementation**

Implement:
- `GalleryState`
- `GalleryEntry`
- `GalleryImageSource`
- `GalleryStore.save/load/path`
- `GalleryPageGenerator.render(state:) -> String`

Write the HTML generator as a pure string builder with embedded JSON or embedded data arrays. Do not make the browser fetch local JSON at runtime.

**Step 4: Run tests to verify they pass**

Run:

```bash
swift test --filter GalleryStoreTests
swift test --filter GalleryPageGeneratorTests
```

Expected:
- PASS

**Step 5: Commit**

```bash
git add Sources/snapview/Runner/GalleryStore.swift Sources/snapview/Generator/GalleryPageGenerator.swift Tests/SnapviewTests/GalleryStoreTests.swift Tests/SnapviewTests/GalleryPageGeneratorTests.swift
git commit -m "feat: add gallery manifest and page generator"
```

### Task 4: Wire gallery updates into render flows and add `snapview gallery`

**Files:**
- Create: `Sources/snapview/Commands/GalleryCommand.swift`
- Modify: `Sources/snapview/Commands/RenderCommand.swift`
- Modify: `Sources/snapview/Commands/RenderAllCommand.swift`
- Modify: `Sources/snapview/Runner/RenderedOutputFinalizer.swift`
- Modify: `Sources/snapview/SnapviewCommand.swift`
- Test: `Tests/SnapviewTests/RenderedOutputFinalizerTests.swift`
- Test: `Tests/SnapviewTests/GalleryStoreTests.swift`

**Step 1: Write the failing tests**

Add tests proving:
- render finalization returns enough metadata to build gallery entries
- single render and render-all both update `gallery.json`
- `gallery.html` is regenerated after a successful render

Minimal assertion shape:

```swift
@Test
func renderAllWritesGalleryManifestForRuntimeFallbackOutput() throws {
  // arrange fake rendered outputs
  // call the helper that persists gallery state
  // assert gallery.json contains the runtime fallback path
}
```

**Step 2: Run tests to verify they fail**

Run:

```bash
swift test --filter RenderedOutputFinalizerTests
swift test --filter GalleryStoreTests
```

Expected:
- FAIL because render flows do not emit gallery state yet

**Step 3: Write the minimal implementation**

Refactor `RenderedOutputFinalizer` to return structured output:

```swift
struct FinalizedRenderOutput {
  let outputDirectory: String
  let imagePaths: [String]
  let usedRuntimeFallback: Bool
  let warnings: [String]
}
```

Then:
- update `render` and `render-all` to persist `GalleryState`
- generate `.snapview/gallery.html` from `GalleryPageGenerator`
- add `GalleryCommand` that opens or prints the generated page path

Keep the command small. Reuse store/generator helpers.

**Step 4: Run tests and manual verification**

Run:

```bash
swift test --filter RenderedOutputFinalizerTests
swift test --filter GalleryStoreTests
swift build
```

Expected:
- PASS

**Step 5: Commit**

```bash
git add Sources/snapview/Commands/GalleryCommand.swift Sources/snapview/Commands/RenderCommand.swift Sources/snapview/Commands/RenderAllCommand.swift Sources/snapview/Runner/RenderedOutputFinalizer.swift Sources/snapview/SnapviewCommand.swift Tests/SnapviewTests/RenderedOutputFinalizerTests.swift Tests/SnapviewTests/GalleryStoreTests.swift
git commit -m "feat: persist gallery state from render commands"
```

### Task 5: Add host supervision

**Files:**
- Create: `Sources/snapview/Runner/HostSupervisor.swift`
- Create: `Tests/SnapviewTests/HostSupervisorTests.swift`
- Modify: `Sources/snapview/Commands/HostCommand.swift`
- Modify: `Sources/snapview/Runner/HostRunner.swift`

**Step 1: Write the failing tests**

Add tests that prove:
- stale host metadata triggers a restart requirement
- matching prepared and host state does not restart unnecessarily
- stop/start orchestration is shared by explicit host commands and watch logic

Example:

```swift
@Test
func hostSupervisorRequestsRestartWhenPreparedStateChanges() throws {
  let decision = HostSupervisor.restartDecision(
    prepared: .fixture(scheme: "App", xctestrunPath: "/tmp/new.xctestrun"),
    host: .fixture(runtimeDirectory: "/tmp/old", pid: 123)
  )

  #expect(decision == .restart)
}
```

**Step 2: Run test to verify it fails**

Run:

```bash
swift test --filter HostSupervisorTests
```

Expected:
- FAIL because `HostSupervisor` does not exist yet

**Step 3: Write the minimal implementation**

Implement:
- restart decision logic
- shared start/restart helpers
- command-side reuse in `HostCommand`

Keep the actual process launching in `HostRunner`; `HostSupervisor` should orchestrate, not own `Process`.

**Step 4: Run tests**

Run:

```bash
swift test --filter HostSupervisorTests
swift test --filter HostRunnerTests
```

Expected:
- PASS

**Step 5: Commit**

```bash
git add Sources/snapview/Runner/HostSupervisor.swift Sources/snapview/Commands/HostCommand.swift Sources/snapview/Runner/HostRunner.swift Tests/SnapviewTests/HostSupervisorTests.swift
git commit -m "refactor: add host supervision layer"
```

### Task 6: Add watch runner and `snapview watch`

**Files:**
- Create: `Sources/snapview/Runner/FileSnapshotWatcher.swift`
- Create: `Sources/snapview/Runner/WatchRunner.swift`
- Create: `Sources/snapview/Commands/WatchCommand.swift`
- Create: `Tests/SnapviewTests/WatchRunnerTests.swift`
- Modify: `Sources/snapview/SnapviewCommand.swift`
- Modify: `Sources/snapview/Commands/PrepareCommand.swift`

**Step 1: Write the failing tests**

Add watch tests that prove:
- a change burst is debounced into one refresh cycle
- a successful cycle runs `prepare`, then host supervision, then `render-all`, then gallery write
- no-op cycles do not rerender

Use injected closures or protocols for side effects:

```swift
@Test
func watchRunnerDebouncesAndRunsSingleRefreshCycle() async throws {
  let recorder = WatchRecorder()
  let runner = WatchRunner(
    snapshotter: { ... },
    sleeper: { _ in },
    prepare: { recorder.events.append("prepare") },
    ensureHost: { recorder.events.append("host") },
    renderAll: { recorder.events.append("render") }
  )

  try await runner.runSingleIteration()

  #expect(recorder.events == ["prepare", "host", "render"])
}
```

**Step 2: Run test to verify it fails**

Run:

```bash
swift test --filter WatchRunnerTests
```

Expected:
- FAIL because watch types do not exist yet

**Step 3: Write the minimal implementation**

Implement:
- `FileSnapshotWatcher` using file-path + mtime snapshots
- `WatchRunner` with injected side effects
- `WatchCommand` that:
  - resolves the project
  - runs `doctor`-style readiness checks
  - runs `prepare`
  - ensures a fresh host
  - runs `render-all`
  - enters the loop

For v2, rerender the full preview set after each successful prepare. Do not add changed-only rendering yet.

**Step 4: Run tests and smoke check**

Run:

```bash
swift test --filter WatchRunnerTests
swift build
.build/debug/snapview watch --help
```

Expected:
- PASS

**Step 5: Commit**

```bash
git add Sources/snapview/Runner/FileSnapshotWatcher.swift Sources/snapview/Runner/WatchRunner.swift Sources/snapview/Commands/WatchCommand.swift Sources/snapview/SnapviewCommand.swift Sources/snapview/Commands/PrepareCommand.swift Tests/SnapviewTests/WatchRunnerTests.swift
git commit -m "feat: add local watch workflow"
```

### Task 7: Polish command output and documentation

**Files:**
- Modify: `README.md`
- Modify: `docs/troubleshooting.md`
- Modify: `docs/plans/2026-03-18-snapview-v2-local-studio-design.md`
- Modify: `Sources/snapview/Commands/DoctorCommand.swift`
- Modify: `Sources/snapview/Commands/GalleryCommand.swift`
- Modify: `Sources/snapview/Commands/WatchCommand.swift`

**Step 1: Write the failing test**

Add one focused assertion in existing command-message tests or a new `WatchCommand`/`DoctorCommand` formatter test:

```swift
@Test
func doctorOutputIncludesSuggestedFixes() {
  let text = ...
  #expect(text.contains("Suggested fix"))
}
```

**Step 2: Run test to verify it fails**

Run:

```bash
swift test --filter DoctorRunnerTests
```

Expected:
- FAIL if the final polish wording is not implemented yet

**Step 3: Write the minimal implementation**

Update:
- README quick start to recommend `doctor`, `watch`, and `gallery`
- troubleshooting to cover `watch` and gallery manifest behavior
- command help text to reflect the local-studio workflow

**Step 4: Run full verification**

Run:

```bash
swift test
swift build
```

Expected:
- all tests PASS
- build PASS

Then run one manual integration pass against a real project:

```bash
.build/debug/snapview doctor --scheme Dawasah --project /Users/abdoelrhman/Developer/side/Dawasah/Dawasah.xcodeproj
.build/debug/snapview prepare --scheme Dawasah --project /Users/abdoelrhman/Developer/side/Dawasah/Dawasah.xcodeproj
.build/debug/snapview host start --scheme Dawasah --project /Users/abdoelrhman/Developer/side/Dawasah/Dawasah.xcodeproj
.build/debug/snapview render-all --scheme Dawasah --project /Users/abdoelrhman/Developer/side/Dawasah/Dawasah.xcodeproj
.build/debug/snapview gallery --project /Users/abdoelrhman/Developer/side/Dawasah/Dawasah.xcodeproj
```

Expected:
- `doctor` reports healthy or actionable findings
- render-all succeeds
- gallery path opens or prints successfully

**Step 5: Commit**

```bash
git add README.md docs/troubleshooting.md docs/plans/2026-03-18-snapview-v2-local-studio-design.md Sources/snapview/Commands/DoctorCommand.swift Sources/snapview/Commands/GalleryCommand.swift Sources/snapview/Commands/WatchCommand.swift
git commit -m "docs: document local studio workflow"
```

## Final Verification Checklist

Before calling the work complete:

1. `swift test`
2. `swift build`
3. manual `doctor` check against a real project
4. manual `watch` smoke test against a real project
5. manual gallery generation/open against a real project

Do not claim completion until all five are verified fresh.
