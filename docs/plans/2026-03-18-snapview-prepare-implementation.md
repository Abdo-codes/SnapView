# Snapview Prepare Fast Path Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add a cached `prepare` flow so `render` uses `xcodebuild test-without-building` instead of rebuilding the app on every invocation.

**Architecture:** Introduce a `prepare` command that generates the full registry, builds test artifacts once with `build-for-testing`, and saves metadata under `.snapview/`. Then change `render` and `render-all` to load that metadata and run `test-without-building` against the cached `.xctestrun`.

**Tech Stack:** Swift 6, ArgumentParser, Foundation, Swift Testing, Xcode command-line tools.

---

### Task 1: Add failing tests for prepared state and build/test argument generation

**Files:**
- Create: `Tests/SnapviewTests/PreparationStoreTests.swift`
- Create: `Tests/SnapviewTests/BuildRunnerPreparationTests.swift`
- Modify: `Sources/snapview/Runner/BuildRunner.swift`

**Step 1: Write the failing test**

Add tests that prove:
- prepared metadata can be saved and loaded;
- `build-for-testing` arguments include `-derivedDataPath`;
- `test-without-building` arguments include `-xctestrun` and the cached destination.

**Step 2: Run test to verify it fails**

Run: `swift test --filter PreparationStoreTests`
Run: `swift test --filter BuildRunnerPreparationTests`
Expected: FAIL because the preparation store and argument helpers do not exist yet.

**Step 3: Write minimal implementation**

Add a small metadata model/store and extract pure build-argument helpers from `BuildRunner`.

**Step 4: Run test to verify it passes**

Run: `swift test --filter PreparationStoreTests`
Run: `swift test --filter BuildRunnerPreparationTests`
Expected: PASS

### Task 2: Add the `prepare` command

**Files:**
- Create: `Sources/snapview/Commands/PrepareCommand.swift`
- Create: `Sources/snapview/Runner/PreparationStore.swift`
- Modify: `Sources/snapview/SnapviewCommand.swift`
- Modify: `Sources/snapview/Runner/BuildRunner.swift`
- Modify: `Sources/snapview/Commands/InitCommand.swift`

**Step 1: Write the failing test**

Add a focused command-adjacent test around the preparation store or helper that proves prepare artifacts are written to `.snapview`.

**Step 2: Run test to verify it fails**

Run: `swift test --filter Prepare`
Expected: FAIL because the command/store helper does not exist.

**Step 3: Write minimal implementation**

Implement `prepare` so it:
- validates init/prerequisites;
- scans all previews;
- writes the full registry;
- runs `build-for-testing`;
- discovers the `.xctestrun`;
- saves metadata.

**Step 4: Run test to verify it passes**

Run: `swift test --filter Prepare`
Expected: PASS

### Task 3: Switch render commands to the prepared fast path

**Files:**
- Modify: `Sources/snapview/Commands/RenderCommand.swift`
- Modify: `Sources/snapview/Commands/RenderAllCommand.swift`
- Modify: `Sources/snapview/Runner/BuildRunner.swift`
- Modify: `README.md`

**Step 1: Write the failing test**

Add tests that prove render uses cached `.xctestrun` metadata instead of requiring registry regeneration/build arguments.

**Step 2: Run test to verify it fails**

Run: `swift test --filter BuildRunnerPreparationTests`
Expected: FAIL because `test-without-building` invocation logic does not exist yet.

**Step 3: Write minimal implementation**

Change `render` and `render-all` to:
- load the preparation metadata;
- write only runtime config;
- run `test-without-building`.

Update README quick-start and CLI reference for `prepare`.

**Step 4: Run test to verify it passes**

Run: `swift test`
Expected: PASS

### Task 4: Verify with Tateemi

**Files:**
- Verify only: `/Users/abdoelrhman/Developer/side/Tateemi/Tateemi.xcodeproj`

**Step 1: Prepare the project**

Run: `/Users/abdoelrhman/Developer/side/snapview/.build/debug/snapview prepare --scheme Tateemi --project /Users/abdoelrhman/Developer/side/Tateemi/Tateemi.xcodeproj`
Expected: PASS and emit cached preparation metadata.

**Step 2: Render using the fast path**

Run: `/Users/abdoelrhman/Developer/side/snapview/.build/debug/snapview render OnboardingView --scheme Tateemi --project /Users/abdoelrhman/Developer/side/Tateemi/Tateemi.xcodeproj`
Expected: PASS and write `.snapview/OnboardingView.png` without rebuilding the whole app.

**Step 3: Verify repeat render latency**

Run the same render command again.
Expected: materially faster second run and still produces the PNG.
