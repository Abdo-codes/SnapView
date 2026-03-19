# Snapview Prepare Fast Path Design

## Context

`snapview render` is slow because it rewrites generated Swift and then invokes `xcodebuild test` on every render. In real apps that forces Swift package resolution, test-host startup, and compilation of the full app graph. The current architecture can work, but it cannot be instant.

## Approaches Considered

### 1. Keep `render` as-is and tune arguments

Pros:
- Smallest code change.

Cons:
- Still pays Xcode build cost on every render.
- Does not address the main latency source.

### 2. Add `prepare`, cache test artifacts, and switch `render` to `test-without-building`

Pros:
- Largest latency win for modest code change.
- Keeps the existing test-based renderer and project injection model.
- Makes the “slow step” explicit and one-time.

Cons:
- Adds one more CLI command and cached state to manage.
- Prepared artifacts can become stale after source changes.

### 3. Replace the test runner with a persistent simulator host

Pros:
- Best long-term latency potential.

Cons:
- Much larger architectural change.
- Requires a new IPC model and a bigger debugging surface.

## Decision

Implement approach 2.

Add a new `snapview prepare --scheme <Scheme>` command that:
- validates the project is initialized;
- scans all previews;
- generates a full `SnapViewRegistry.swift`;
- runs `xcodebuild build-for-testing`;
- writes cached metadata describing the prepared test bundle and destination.

Then change `snapview render` and `snapview render-all` to:
- use the cached full registry instead of rewriting generated Swift;
- write only the runtime config file;
- invoke `xcodebuild test-without-building` using the prepared test artifacts.

## Design

### Command model

- `init` remains the one-time project wiring step.
- `prepare` becomes the explicit slow step that refreshes the generated registry and builds test artifacts.
- `render` and `render-all` become fast-path commands and fail with a clear error if preparation is missing or stale.

### Cached state

Store metadata under `.snapview/prepare.json` and build artifacts under `.snapview/DerivedData/`.

Prepared metadata should include:
- scheme
- project/workspace path
- test target name
- destination specifier
- derived data path
- `.xctestrun` path

### Registry flow

Generate the full registry during `prepare`, not during `render`.

`render` still scans sources to match a user-supplied preview name, but it should not rewrite the registry. The runtime filter remains file-based via `/tmp/snapview/config.json`.

### Build flow

`prepare`:
- resolve a simulator destination using `xcodebuild -showdestinations`;
- run `xcodebuild build-for-testing -derivedDataPath ...`;
- locate the generated `.xctestrun`;
- save metadata.

`render`:
- load metadata;
- verify it matches the requested scheme/project/test target;
- run `xcodebuild test-without-building -xctestrun ... -destination ... -only-testing:...`.

### Error handling

Fast-fail on:
- missing preparation metadata;
- missing `.xctestrun`;
- mismatched scheme/project/test target.

Error messages should instruct the user to run `snapview prepare --scheme ...`.

## Testing

Add unit tests for:
- preparation metadata persistence;
- `build-for-testing` argument generation;
- `test-without-building` argument generation;
- `.xctestrun` path discovery.

Keep full-package verification via `swift test`, then manual verification against Tateemi by running:
- `snapview init --scheme Tateemi`
- `snapview prepare --scheme Tateemi`
- `snapview render OnboardingView --scheme Tateemi`
