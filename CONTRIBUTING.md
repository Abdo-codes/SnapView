# Contributing

Thanks for contributing to `snapview`.

## Before You Start

- Open an issue for bugs, UX gaps, or proposed features before doing large changes.
- Keep pull requests focused. Small, isolated changes are easier to review and ship.
- Match the existing product direction: preview-driven rendering, explicit diagnostics, and deterministic behavior over cleverness.

## Local Development

Requirements:

- macOS 14+
- Xcode 15+
- Swift 6 toolchain

Common setup:

```sh
swift build
swift test
```

For the script-based integration smoke path:

```sh
scripts/integration-smoke.sh \
  --scheme MyApp \
  --project /path/to/MyApp.xcodeproj
```

## Pull Requests

Before opening a PR:

- run `swift test`
- run `swift build`
- update docs if behavior or CLI usage changed
- include the exact verification commands you ran

If your change affects rendering, preparation, or watch behavior, include a concrete reproduction project or smoke command when possible.

## Scope

Good contributions:

- render, host, watch, gallery, and doctor correctness fixes
- diagnostics and error reporting improvements
- deterministic tests and integration coverage
- documentation that reflects actual product behavior

Changes that usually need discussion first:

- broad CLI redesigns
- new installation/distribution channels
- support for non-macOS platforms
- changes that weaken deterministic behavior in favor of hidden heuristics

## Code Style

- Keep changes pragmatic and small.
- Prefer explicit behavior over magic.
- Add tests for behavior changes.
- Avoid bundling unrelated cleanup with functional work.
