# Snapview Destination And Preflight Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Restore scheme-aware simulator destination selection and fail early when a project is not actually wired for snapview rendering.

**Architecture:** Move destination selection back to `xcodebuild -showdestinations` so the chosen simulator comes from the scheme’s real supported destinations instead of hard-coded names or raw `pbxproj` guesses. Add a narrow project preflight that checks whether the expected test target exists in the project before `render` or `render-all` call `xcodebuild`.

**Tech Stack:** Swift 6, Swift Testing, Xcode command-line tools.

---

### Task 1: Add failing tests for destination parsing

**Files:**
- Create: `Tests/SnapviewTests/BuildRunnerTests.swift`
- Modify: `Sources/snapview/Runner/BuildRunner.swift`

**Step 1: Write the failing test**

Add tests that prove:
- iOS destinations prefer an iPhone simulator over iPad.
- tvOS destinations resolve to an Apple TV simulator.
- empty or invalid destination output fails clearly instead of falling back to a hard-coded simulator.

**Step 2: Run test to verify it fails**

Run: `swift test --filter BuildRunnerTests`
Expected: FAIL because the destination helper does not exist or still returns hard-coded fallbacks.

**Step 3: Write minimal implementation**

Reintroduce scheme-aware `xcodebuild -showdestinations` probing and parse the output into a concrete `(platform, simulator)` result.

**Step 4: Run test to verify it passes**

Run: `swift test --filter BuildRunnerTests`
Expected: PASS

### Task 2: Add failing tests for render preflight

**Files:**
- Create: `Tests/SnapviewTests/ProjectValidatorTests.swift`
- Create: `Sources/snapview/Project/ProjectValidator.swift`
- Modify: `Sources/snapview/Commands/RenderCommand.swift`
- Modify: `Sources/snapview/Commands/RenderAllCommand.swift`

**Step 1: Write the failing test**

Add tests that prove:
- a project without the expected test target is rejected;
- a project with the expected test target passes validation.

**Step 2: Run test to verify it fails**

Run: `swift test --filter ProjectValidatorTests`
Expected: FAIL because no validator exists yet.

**Step 3: Write minimal implementation**

Implement a lightweight validator that inspects `project.pbxproj` and ensures the expected test target is present before rendering.

**Step 4: Run test to verify it passes**

Run: `swift test --filter ProjectValidatorTests`
Expected: PASS

### Task 3: Wire the runtime path and verify the package

**Files:**
- Modify: `Sources/snapview/Runner/BuildRunner.swift`
- Modify: `Sources/snapview/Commands/RenderCommand.swift`
- Modify: `Sources/snapview/Commands/RenderAllCommand.swift`

**Step 1: Run targeted tests**

Run: `swift test --filter BuildRunnerTests`
Run: `swift test --filter ProjectValidatorTests`
Expected: PASS

**Step 2: Run the full package test suite**

Run: `swift test`
Expected: PASS

**Step 3: Manual verification against Tateemi**

Run: `/Users/abdoelrhman/Developer/side/snapview/.build/debug/snapview list`
Run: `/Users/abdoelrhman/Developer/side/snapview/.build/debug/snapview render OnboardingView --scheme Tateemi --project /Users/abdoelrhman/Developer/side/Tateemi/Tateemi.xcodeproj --verbose`
Expected:
- `list` succeeds and enumerates previews.
- `render` fails fast with a clear preflight error about the missing test target instead of reaching `xcodebuild test`.
