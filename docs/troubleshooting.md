# snapview Troubleshooting

This page covers the failure modes we hit while verifying `snapview` against external app projects such as Tateemi and Dawasah.

## 1. `snapview list` only shows one screen

Cause:
- `snapview` is preview-driven. It renders discovered `#Preview` blocks, not arbitrary SwiftUI views.

How to confirm:

```sh
snapview list
```

If a screen is missing from the list, `snapview` cannot render it yet.

How to fix:
- Add a `#Preview` block for every screen or state you want rendered.
- Prefer explicit preview names for gallery output.
- If the screen needs sample state, build that state in preview fixtures instead of relying on live dependencies.

Example:

```swift
#Preview("Dashboard") {
  DashboardView(store: .preview)
}

#Preview("Dashboard - Empty State") {
  DashboardView(store: .previewEmpty)
}
```

Then rerun:

```sh
snapview prepare --scheme MyApp
```

## 2. `build-for-testing` fails because the test target has no `Info.plist`

Typical error:

```text
Cannot code sign because the target does not have an Info.plist file
```

Cause:
- The app project has a unit-test target, but that target is missing both:
  - `GENERATE_INFOPLIST_FILE = YES`
  - and a valid `INFOPLIST_FILE`

How to fix:
- In the test target build settings, set `GENERATE_INFOPLIST_FILE = YES`.
- Or set `INFOPLIST_FILE` to a real plist file.

What `snapview init` does:
- When `snapview init` creates or patches its generated test target files, it configures generated `Info.plist` support.
- Older existing test targets may still need manual repair.

Minimum expected test-target settings:

```text
BUNDLE_LOADER = $(TEST_HOST)
TEST_HOST = $(BUILT_PRODUCTS_DIR)/MyApp.app/MyApp
GENERATE_INFOPLIST_FILE = YES
```

After fixing the target, rerun:

```sh
snapview prepare --scheme MyApp
```

## 3. `render-all` succeeds, but PNGs are not copied into `.snapview`

Typical warning:

```text
Warning: couldn't copy PNGs to /path/to/project/.snapview; using runtime output instead.
```

Cause:
- `snapview` rendered successfully, but the final copy step back into the external project's `.snapview` folder failed due to permissions or sandbox constraints.

How to fix or work around:
- Use the runtime output path printed by `snapview`.
- If you want the PNGs inside the project, make sure the project directory is writable from the environment running `snapview`.

What this means:
- The render is good.
- The failure is only in the final copy-back step.

## 4. The persistent host is running, but renders still reflect old previews

Cause:
- `snapview prepare` refreshed the generated registry and test bundle, but the already-running host is still using the previous prepared artifacts.

How to fix:

```sh
snapview host stop
snapview host start --scheme MyApp
```

Recommended workflow after preview changes:

```sh
snapview prepare --scheme MyApp
snapview host stop
snapview host start --scheme MyApp
snapview render-all --scheme MyApp
```

## 5. `render` or `render-all` says preparation is stale

Cause:
- The prepared metadata no longer matches the current project, scheme, or test target.
- This usually happens after switching projects, changing the scheme, or regenerating test artifacts.

How to fix:

```sh
snapview prepare --scheme MyApp
```

If you are using the persistent host, restart it afterward.

## 6. Swift 6 preview fixture code fails because preview stores cross actor boundaries

Typical symptom:
- You create helper preview stores in a shared fixture namespace, and Swift 6 rejects a `Store(...)` call with actor-isolation or non-Sendable errors.

Cause:
- `Store` initialization is `@MainActor`.
- A shared preview helper was created in a nonisolated context.

How to fix:
- Put the preview fixture namespace or helper on the main actor.

Example:

```swift
@MainActor
enum MyPreviewData {
  static func inertStore<State, Action>(initialState: State) -> Store<State, Action> {
    Store(initialState: initialState) {
      Reduce<State, Action> { _, _ in .none }
    }
  }
}
```

This keeps preview-only store construction deterministic and Swift 6-safe.

## 7. A view crashes under plain image rendering, especially with navigation

Typical symptom:
- SwiftUI crashes while rendering previews that use `NavigationStack` or require a real UIKit hosting environment.

What `snapview` does now:
- The generated renderer snapshots through an offscreen `UIWindowScene` and `UIHostingController`, not a bare `ImageRenderer` path.

What to do if you still see a crash:
- Verify the screen renders in Xcode previews first.
- Reduce the preview to the smallest crashing case.
- Confirm the crash is in the app view code, not in test-target setup or stale host artifacts.
- Rerun `snapview prepare`, restart the host, and try again.

## Recovery Checklist

When an external app project does not render correctly:

1. Run `snapview list` and confirm the screen is actually covered by `#Preview`.
2. Ensure the test target has a generated or real `Info.plist`.
3. Run `snapview prepare --scheme <Scheme>`.
4. Restart the persistent host if it was already running.
5. Run `snapview render-all --scheme <Scheme>`.
6. If `.snapview` is not writable, use the runtime output path reported by the command.
