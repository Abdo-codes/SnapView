# Snapview Persistent Host Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add a persistent simulator-side renderer host so repeated `snapview render` calls avoid launching a fresh XCTest process each time.

**Architecture:** Reuse the prepared XCTest bundle, add a long-lived `test_host` loop to the generated renderer, and manage it with new `snapview host` commands. `render` should prefer the running host and fall back to the existing one-shot prepared path when no host is active.

**Tech Stack:** Swift 6, ArgumentParser, Foundation, Swift Testing, Xcode command-line tools, XCTest.

---

### Task 1: Add failing tests for host state and command argument generation

**Files:**
- Create: `Tests/SnapviewTests/HostStoreTests.swift`
- Create: `Tests/SnapviewTests/HostRunnerTests.swift`
- Modify: `Sources/snapview/Runner/BuildRunner.swift`

**Step 1: Write the failing test**

Add tests that prove:
- host metadata can be saved and loaded;
- host start arguments call `test-without-building` with `test_host`;
- host stop/status helpers can reason about saved state.

**Step 2: Run test to verify it fails**

Run: `swift test --filter HostStoreTests`
Run: `swift test --filter HostRunnerTests`
Expected: FAIL because the host state and host argument helpers do not exist.

**Step 3: Write minimal implementation**

Add host metadata models and argument builders.

**Step 4: Run test to verify it passes**

Run: `swift test --filter HostStoreTests`
Run: `swift test --filter HostRunnerTests`
Expected: PASS

### Task 2: Extend the generated renderer with host mode

**Files:**
- Modify: `Sources/snapview/Generator/RendererTemplate.swift`
- Modify: `Tests/SnapviewTests/RendererTemplateTests.swift`

**Step 1: Write the failing test**

Add assertions that the generated template now contains `test_host`, ready/response markers, and shared render helpers.

**Step 2: Run test to verify it fails**

Run: `swift test --filter RendererTemplate`
Expected: FAIL because the template only supports `test_render`.

**Step 3: Write minimal implementation**

Refactor the generated template so one-shot and host rendering share the same render function, with `test_host` polling for requests.

**Step 4: Run test to verify it passes**

Run: `swift test --filter RendererTemplate`
Expected: PASS

### Task 3: Add `snapview host` commands and refresh generated files on init

**Files:**
- Create: `Sources/snapview/Commands/HostCommand.swift`
- Create: `Sources/snapview/Runner/HostStore.swift`
- Modify: `Sources/snapview/SnapviewCommand.swift`
- Modify: `Sources/snapview/Project/ProjectInjector.swift`
- Modify: `Sources/snapview/Commands/InitCommand.swift`

**Step 1: Write the failing test**

Add a focused test for init/update behavior or host-state persistence if needed.

**Step 2: Run test to verify it fails**

Run: `swift test --filter Host`
Expected: FAIL because the command/store/update path does not exist yet.

**Step 3: Write minimal implementation**

Implement:
- `host start`
- `host stop`
- `host status`
- generated file refresh during `init`

**Step 4: Run test to verify it passes**

Run: `swift test`
Expected: PASS

### Task 4: Route render through the host when available

**Files:**
- Modify: `Sources/snapview/Commands/RenderCommand.swift`
- Modify: `Sources/snapview/Commands/RenderAllCommand.swift`
- Modify: `Sources/snapview/Runner/PNGExtractor.swift`
- Modify: `README.md`

**Step 1: Write the failing test**

Add tests for host request/response models or helper logic that chooses host vs fallback.

**Step 2: Run test to verify it fails**

Run: `swift test --filter Host`
Expected: FAIL because render does not use host runtime state yet.

**Step 3: Write minimal implementation**

Implement host-backed render:
- write request
- wait for response
- extract PNGs
- fall back to one-shot prepared render if host is unavailable

Update README for `host start/stop/status`.

**Step 4: Run test to verify it passes**

Run: `swift test`
Expected: PASS

### Task 5: Verify with Tateemi

**Files:**
- Verify only: `/Users/abdoelrhman/Developer/side/Tateemi/Tateemi.xcodeproj`

**Step 1: Refresh generated files**

Run: `/Users/abdoelrhman/Developer/side/snapview/.build/debug/snapview init --scheme Tateemi --project /Users/abdoelrhman/Developer/side/Tateemi/Tateemi.xcodeproj`
Expected: PASS and refresh generated renderer code.

**Step 2: Prepare artifacts**

Run: `/Users/abdoelrhman/Developer/side/snapview/.build/debug/snapview prepare --scheme Tateemi --project /Users/abdoelrhman/Developer/side/Tateemi/Tateemi.xcodeproj`
Expected: PASS

**Step 3: Start host**

Run: `/Users/abdoelrhman/Developer/side/snapview/.build/debug/snapview host start --scheme Tateemi --project /Users/abdoelrhman/Developer/side/Tateemi/Tateemi.xcodeproj`
Expected: PASS and report ready host state.

**Step 4: Render twice**

Run the same `render` command twice.
Expected: both succeed, second render is materially faster than the current 9s one-shot path.

**Step 5: Stop host**

Run: `/Users/abdoelrhman/Developer/side/snapview/.build/debug/snapview host stop`
Expected: PASS and no orphaned host process remains.
