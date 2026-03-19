# snapview Integration Smoke Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add a generic smoke script that verifies the real `snapview` local-studio workflow against any target project or workspace.

**Architecture:** Implement a small shell harness in `scripts/integration-smoke.sh` that runs the public CLI in sequence, validates artifacts, and optionally verifies one bounded `watch` startup. Test the harness with a fake `snapview` binary so behavior is deterministic and does not require a real Xcode project during automated tests.

**Tech Stack:** POSIX shell, Swift Testing, temporary filesystem fixtures, existing `ProcessRunner` patterns, README documentation.

---

### Task 1: Add shell-script test coverage for usage and default flow

**Files:**
- Create: `Tests/SnapviewTests/IntegrationSmokeScriptTests.swift`
- Create: `Tests/Fixtures/integration-smoke/fake-snapview.sh`
- Create: `scripts/integration-smoke.sh`

**Step 1: Write the failing tests**

Add focused tests that spawn the shell script through `/bin/sh` and use a fake `snapview` binary via `SNAPVIEW_BIN`.

Cover at least:

- missing required arguments fails with usage text
- default flow runs `doctor`, `prepare`, `render-all`, then `gallery`
- default flow fails if `gallery.html` does not exist
- default flow fails if no PNG exists

Use shapes like:

```swift
@Test("default smoke flow runs doctor prepare render-all and gallery")
func smokeScriptRunsDefaultFlow() throws {
  let fixture = try SmokeFixture.make()
  let result = try ProcessRunner.run(
    executableURL: URL(filePath: "/bin/sh"),
    arguments: [
      fixture.scriptPath,
      "--scheme", "Demo",
      "--project", fixture.projectPath,
    ],
    environment: fixture.environment,
    verbose: false
  )

  #expect(result.terminationStatus == 0)
  #expect(result.output.contains("==> doctor"))
  #expect(result.output.contains("==> prepare"))
  #expect(result.output.contains("==> render-all"))
  #expect(result.output.contains("==> gallery"))
}
```

The fake binary should:

- append each invocation to a log file
- create a fake gallery file when asked to run `gallery`
- create a fake PNG when asked to run `render-all`

**Step 2: Run tests to verify they fail**

Run:

```bash
swift test --filter IntegrationSmokeScriptTests
```

Expected:
- FAIL because the script and fake binary do not exist yet

**Step 3: Write the minimal implementation**

Create:

- `scripts/integration-smoke.sh` with:
  - strict mode (`set -eu`)
  - argument parsing for `--scheme`, `--project`, `--workspace`, `--test-target`, `--watch`, `--keep-host`
  - binary resolution from `SNAPVIEW_BIN` or `.build/debug/snapview`
  - default command sequence for `doctor`, `prepare`, `render-all`, `gallery`
  - artifact checks for `gallery.html` and at least one PNG
- `Tests/Fixtures/integration-smoke/fake-snapview.sh` with simple subcommand behavior driven by env vars

Keep the first version narrow. Do not implement `--watch` yet in this task.

**Step 4: Run tests to verify they pass**

Run:

```bash
swift test --filter IntegrationSmokeScriptTests
```

Expected:
- PASS for usage and default-flow tests

**Step 5: Commit**

```bash
git add scripts/integration-smoke.sh Tests/SnapviewTests/IntegrationSmokeScriptTests.swift Tests/Fixtures/integration-smoke/fake-snapview.sh
git commit -m "feat: add integration smoke harness"
```

### Task 2: Add optional watch verification and host cleanup behavior

**Files:**
- Modify: `scripts/integration-smoke.sh`
- Modify: `Tests/SnapviewTests/IntegrationSmokeScriptTests.swift`
- Modify: `Tests/Fixtures/integration-smoke/fake-snapview.sh`

**Step 1: Write the failing tests**

Add tests that prove:

- `--watch` starts the watch step and exits after the first successful refresh marker
- the script stops a host by default after a successful run
- `--keep-host` skips host shutdown

Use the fake binary to simulate:

- `watch` printing a line like `[watch] Updated 3 preview(s) in 1.0s.`
- `host stop` logging that cleanup happened

Example:

```swift
@Test("watch mode waits for first successful refresh and then stops host")
func smokeScriptWatchFlowStopsAfterFirstRefresh() throws {
  let fixture = try SmokeFixture.make(watchRefreshes: true)
  let result = try ProcessRunner.run(
    executableURL: URL(filePath: "/bin/sh"),
    arguments: [
      fixture.scriptPath,
      "--scheme", "Demo",
      "--project", fixture.projectPath,
      "--watch",
    ],
    environment: fixture.environment,
    verbose: false
  )

  #expect(result.terminationStatus == 0)
  #expect(result.output.contains("==> watch"))
  #expect(fixture.loggedCommands.contains("host stop"))
}
```

**Step 2: Run tests to verify they fail**

Run:

```bash
swift test --filter IntegrationSmokeScriptTests
```

Expected:
- FAIL because `--watch` behavior and cleanup semantics are not implemented yet

**Step 3: Write the minimal implementation**

Update the shell script to:

- create a temporary watch log file
- start `snapview watch ...` in the background when `--watch` is set
- wait until a success marker appears in the log
- stop the watch process cleanly
- call `snapview host stop ...` after success unless `--keep-host` is set

Keep the watch success marker simple and explicit. Match the existing output from `WatchRunner`, such as `[watch] Updated`.

**Step 4: Run tests to verify they pass**

Run:

```bash
swift test --filter IntegrationSmokeScriptTests
```

Expected:
- PASS for default and watch flow tests

**Step 5: Commit**

```bash
git add scripts/integration-smoke.sh Tests/SnapviewTests/IntegrationSmokeScriptTests.swift Tests/Fixtures/integration-smoke/fake-snapview.sh
git commit -m "feat: add watch smoke verification"
```

### Task 3: Document the smoke workflow and run a manual end-to-end verification

**Files:**
- Modify: `README.md`

**Step 1: Write the failing documentation-oriented assertion**

Add one focused test if helpful, or skip automated doc testing and rely on the manual verification below. If you add a test, keep it narrow and deterministic, for example a formatter helper if one is introduced. Do not invent a large docs test framework for v1.

**Step 2: Update the README**

Add a short section showing:

- how to run the script with `--project`
- how to run it with `--workspace`
- when to use `--watch`
- what `SNAPVIEW_BIN` does

Suggested example:

```sh
scripts/integration-smoke.sh \
  --scheme MyApp \
  --project /path/to/MyApp.xcodeproj
```

**Step 3: Run repo verification**

Run:

```bash
swift test
swift build
```

Expected:
- all tests PASS
- build PASS

**Step 4: Run a real-project smoke pass**

Run:

```bash
scripts/integration-smoke.sh \
  --scheme Dawasah \
  --project /Users/abdoelrhman/Developer/side/Dawasah/Dawasah.xcodeproj
```

Then run the watch variant:

```bash
scripts/integration-smoke.sh \
  --scheme Dawasah \
  --project /Users/abdoelrhman/Developer/side/Dawasah/Dawasah.xcodeproj \
  --watch
```

Expected:
- both commands exit successfully
- gallery exists
- PNGs exist
- the watch run completes one successful refresh and stops cleanly

**Step 5: Commit**

```bash
git add README.md scripts/integration-smoke.sh Tests/SnapviewTests/IntegrationSmokeScriptTests.swift Tests/Fixtures/integration-smoke/fake-snapview.sh
git commit -m "docs: add integration smoke workflow"
```

## Final Verification Checklist

Before calling the work complete:

1. `swift test`
2. `swift build`
3. `scripts/integration-smoke.sh --scheme Dawasah --project /Users/abdoelrhman/Developer/side/Dawasah/Dawasah.xcodeproj`
4. `scripts/integration-smoke.sh --scheme Dawasah --project /Users/abdoelrhman/Developer/side/Dawasah/Dawasah.xcodeproj --watch`

Do not claim completion until all four checks pass fresh.
