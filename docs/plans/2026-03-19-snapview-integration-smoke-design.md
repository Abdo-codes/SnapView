# snapview Integration Smoke Design

## Summary

`snapview` now has a real local-studio workflow: `doctor`, `prepare`, `render-all`, `gallery`, and `watch`. We manually verified that workflow against a real Xcode project, but the repo does not yet have a repeatable harness for that verification. This design adds a small generic smoke script that exercises the product-facing CLI against any project and reports the first failing step clearly.

The goal is not to replace unit tests. The goal is to make the real workflow reproducible for local verification and lightweight CI use.

## Goals

- Add a generic smoke script that can target any project or workspace.
- Verify the core local-studio workflow through the public CLI.
- Keep the default smoke path fast and deterministic.
- Make `watch` verification available without forcing it on every run.
- Clean up the persistent host by default so smoke runs do not leave background state behind.

## Non-Goals

- Do not add a new Swift executable target just for smoke verification.
- Do not simulate file edits in `watch` during v1.
- Do not parse or validate gallery HTML content beyond existence checks.
- Do not add CI wiring in the first slice.
- Do not overbuild shell-unit infrastructure around every argument edge case.

## Product Shape

The new entry point should be:

```sh
scripts/integration-smoke.sh --scheme <Scheme> [--project <path> | --workspace <path>] [--test-target <name>] [--watch] [--keep-host]
```

Defaults:

- `--scheme` is required.
- Exactly one of `--project` or `--workspace` is required.
- The script uses `.build/debug/snapview` by default.
- `SNAPVIEW_BIN` may override the binary path.
- `--watch` is opt-in.
- `--keep-host` is opt-in.

## Why A Shell Script

The smoke harness should execute the exact commands users run. A shell script keeps the implementation close to the product surface:

- no extra compilation step
- easy local use during development
- easy future use from CI
- simple failure reporting around subprocess exit codes

A Swift harness would add more structure, but it would mainly reimplement orchestration that shell already handles well enough for this scope.

## Execution Flow

The script should run these steps in order:

1. Validate CLI arguments.
2. Resolve the `snapview` binary path.
3. Run `snapview doctor`.
4. Run `snapview prepare`.
5. Run `snapview render-all`.
6. Run `snapview gallery` and capture the gallery path.
7. Assert that `gallery.html` exists.
8. Assert that at least one PNG exists in the output directory.
9. If `--watch` is set:
   - start `snapview watch`
   - wait until the first successful refresh appears in output
   - stop it cleanly
10. Unless `--keep-host` is set, stop any host started during the run.

The script should stop at the first failure and exit non-zero.

## Success Criteria

Default smoke run passes only if:

- `doctor` exits successfully
- `prepare` exits successfully
- `render-all` exits successfully
- `gallery` exits successfully
- the resulting gallery path exists on disk
- at least one PNG exists in the expected output directory

`--watch` adds one more requirement:

- the initial `watch` startup completes one successful refresh before the script stops it

That is enough for v1. It proves the main workflow without turning the smoke script into a full integration framework.

## Logging And Failure Reporting

The script should emit compact step markers:

- `==> doctor`
- `==> prepare`
- `==> render-all`
- `==> gallery`
- `==> watch`
- `Smoke passed`

On failure it should print:

- the step name
- the exact command that failed
- the exit status

The command output itself should stream normally so the underlying failure remains visible.

## Cleanup Semantics

Default behavior should leave the environment clean:

- stop any host started by the smoke script
- remove any temporary watch log files the script creates

`--keep-host` exists only for debugging cases where the caller wants to inspect a running host after a successful smoke run.

## Testing Strategy

The implementation should add deterministic tests around the shell script behavior, not around real Xcode projects:

- usage validation
- command ordering with a fake `snapview` binary
- artifact assertion behavior
- optional `--watch` flow with a fake binary that emits a successful refresh marker

That test layer should use a fake `SNAPVIEW_BIN` and temporary directories so it stays fast and hermetic.

Real project verification remains a manual smoke pass after implementation.

## Files

- Create: `scripts/integration-smoke.sh`
- Create: `Tests/SnapviewTests/IntegrationSmokeScriptTests.swift`
- Create: `Tests/Fixtures/integration-smoke/fake-snapview.sh`
- Modify: `README.md`

## Open Questions Resolved

- `watch` verification is opt-in via `--watch`.
- Artifact validation is required in v1: `gallery.html` plus at least one PNG.
- The harness is generic rather than tied to Dawasah.

## Recommendation

Implement the shell script in a narrow first slice:

- deterministic default smoke path
- opt-in watch verification
- explicit cleanup
- minimal README usage docs

That gives `snapview` a repeatable product-level verification path with low maintenance cost.
