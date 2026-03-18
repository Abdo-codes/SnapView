# Snapview Persistent Host Design

## Context

The new `prepare` flow removes rebuilds from `render`, but repeated renders still take around 9-11 seconds because each invocation launches `xcodebuild test-without-building`, boots the test host, runs one XCTest, and exits.

To get materially faster iteration, we need a process that stays alive in the simulator and renders multiple requests without re-entering `xcodebuild` each time.

## Approaches Considered

### 1. Auto-start a fresh `test-without-building` process on every render

Pros:
- Small change from the current architecture.

Cons:
- Still pays XCTest startup cost every render.
- Not enough latency reduction.

### 2. Persistent XCTest host process

Pros:
- Reuses the existing generated test bundle and `@testable import` access.
- Avoids changing the app target or forcing users to split code into a framework.
- Keeps the project-injection surface relatively small.

Cons:
- Requires a new host lifecycle and file-based protocol.
- Generated renderer code becomes more complex.

### 3. Persistent app-side host embedded into the application target

Pros:
- Potentially cleaner long-term than running inside XCTest.

Cons:
- Much more invasive to user projects.
- Harder to inject safely across many app architectures.

## Decision

Implement approach 2.

## Design

### Host lifecycle

Add a new `snapview host` command family:
- `snapview host start --scheme <Scheme>`
- `snapview host stop`
- `snapview host status`

`host start` will:
- validate `prepare` metadata;
- launch `xcodebuild test-without-building -only-testing:<test_host>`;
- detach it into the background with logs redirected to `.snapview/host.log`;
- wait until the test bundle writes a ready marker.

`host stop` will:
- write a stop file the host loop watches for;
- wait briefly for graceful exit;
- fall back to killing the recorded `xcodebuild` pid if needed.

### Host protocol

Use a file-based protocol under `.snapview/host-runtime/`:
- `request.json`
- `response.json`
- `ready.json`
- `stop`

Each render request includes:
- request id
- list of view names
- scale
- width / height
- rtl
- locale

The host test loop watches for a new request id, renders matching registry entries, writes PNGs to `/tmp/snapview`, then writes `response.json`.

### Render behavior

`render` and `render-all` should:
- load prepared state;
- if a ready host is running, send a request and wait for a response;
- otherwise fall back to the current prepared `test-without-building` one-shot path.

That keeps the CLI useful even if the host is not running.

### Generated renderer

Expand `SnapViewRenderer.swift` to include:
- shared config decoding and render helpers;
- `test_render` for one-shot behavior;
- `test_host` for the long-lived request loop.

The generated file must remain safe to commit and safe to re-run through `init`.

### State management

Store host metadata in `.snapview/host.json`:
- xcodebuild pid
- scheme
- project path
- test target
- runtime directory
- log path

`host status` should report whether the pid is alive and whether the ready marker exists.

### Important implementation note

`ProjectInjector.inject` currently treats existing generated files as immutable. For host support, `init` must refresh generated renderer/template files even when the project is already initialized, otherwise older projects cannot pick up the new host test.

## Testing

Add unit tests for:
- host state persistence;
- host request/response codable models;
- host `xcodebuild` argument generation;
- renderer-template output containing both `test_render` and `test_host`.

Manual verification on Tateemi:
- `snapview init --scheme Tateemi`
- `snapview prepare --scheme Tateemi`
- `snapview host start --scheme Tateemi`
- `snapview render OnboardingView --scheme Tateemi`
- repeat the same render and compare latency
- `snapview host stop`
