# Dogtor My Eyes — agent guide

SwiftUI iOS marketplace for browsing **in-network eye care**. Every provider is a dog. There is **no backend, no auth, and no network layer**.

## Layout

```
DogtorMyEyes/
  DogtorMyEyesApp.swift   # App entry + tab shell
  Theme.swift             # Colors, fonts, NetworkBadge, ProviderAvatar
  Models/Provider.swift   # Specialty, InsurancePlan, Provider
  Data/providers.json     # Mock fixture (12 providers)
  Data/ProviderStore.swift
  Views/                  # Browse, detail, favorites, booking
DogtorMyEyesTests/
  ProviderStoreTests.swift
scripts/
  verify_provider_logic.py  # Linux CI stand-in for filter logic
  ui-mock/                  # Static HTML mocks
```

## Build & test

Requires macOS + Xcode 16+:

```bash
xcodebuild \
  -scheme DogtorMyEyes \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  build test
```

On Linux (or without Xcode):

```bash
python3 .cursor/skills/add-provider/scripts/validate_provider.py
python3 scripts/verify_provider_logic.py
```

## Constraints

- Prefer editing `providers.json` over inventing providers in Swift.
- Keep `ProviderStore.filteredProviders` and `scripts/verify_provider_logic.py` in sync.
- Persist only via the existing `UserDefaults` keys in `ProviderStore` (`selectedInsurancePlan`, `favoriteProviderIDs`).
- Reuse `Theme`, `NetworkBadge`, and `ProviderAvatar` — do not hardcode teal/sand colors in views.
- Booking is local-only (`BookingSheet`); do not add networking or analytics SDKs.

## Nested guides

- Provider fixture rules: [DogtorMyEyes/Data/AGENTS.md](DogtorMyEyes/Data/AGENTS.md)
- PR review bar: [.cursor/BUGBOT.md](.cursor/BUGBOT.md)

## Cursor primitives

Sample agent config lives under `.cursor/`. The notes below match those files; the skill and rule files stay the source of detail.

### Rules

| File | When it is in context |
|------|------------------------|
| `.cursor/rules/swift-style.mdc` | `alwaysApply: true` |
| `.cursor/rules/swiftui-views.mdc` | `globs: DogtorMyEyes/Views/**/*.swift` |
| `.cursor/rules/insurance-network-logic.mdc` | `alwaysApply: false` and no globs. Description covers filter, plan, specialty, and fixture edits. |
| `.cursor/rules/release-notes.mdc` | Manual. The file says to invoke it with `@release-notes`. |

`release-notes` turns the last ~20 commits into 3–6 App Store "What's New" bullets, playful dogtor voice, about 400 characters, user-visible changes only.

### Hooks

Declared in `.cursor/hooks.json`. Each script reads a JSON payload on stdin and needs `jq` on `PATH`.

| Event | Script | Behavior |
|-------|--------|----------|
| `beforeShellExecution` | `.cursor/hooks/guard-shell.sh` | `failClosed: true`. Denies a command that looks like `git push` with `--force` (including `--force-with-lease`) when it also names `main` or `master`. Denies recursive `rm` (`-r` inside the flag cluster, or `--recursive`) unless the command includes `build/` or `artifacts/`. A whitespace-delimited `/`, `~`, or `..` is denied even if `build/` appears later, so absolute and home paths do not pass. Returns `ask` for `xcrun simctl erase` / `simctl erase`. Anything else prints `{"permission":"allow"}`. |
| `afterFileEdit` | `.cursor/hooks/format-swift.sh` | Formats in place with `xcrun swift-format format -i` only when `file_path` ends in `.swift` and `swift-format` is installed. Otherwise it prints `{}` and exits 0. Format errors are swallowed. |
| `stop` | `.cursor/hooks/verify-fixtures.sh` | `loop_limit: 2`. Runs only when `status` is `completed`. Collects `git diff --name-only HEAD` plus untracked files. If that set includes `DogtorMyEyes/Data/providers.json` or `DogtorMyEyes/Data/ProviderStore.swift`, it runs `python3 scripts/verify_provider_logic.py`. Failure becomes a `followup_message` (first 1200 characters of output). `loop_count` of 2 or more prints `{}` and does not nag again. |

The stop hook does not see commits already on `HEAD`. Formatting is not a CI check; Linux agents skip it because `xcrun` is absent.

### Skills

| Skill | Use |
|-------|-----|
| `add-provider` | Append one provider to `providers.json`, then run both Python checks below. |
| `simulator-screenshot` | macOS + Xcode. Builds the `DogtorMyEyes` scheme for the iPhone 17 simulator and writes `artifacts/dogtor-<timestamp>.png`. `artifacts/` is gitignored. |

The app target bundle id is `com.demo.DogtorMyEyes` (`PRODUCT_BUNDLE_IDENTIFIER` in `DogtorMyEyes.xcodeproj/project.pbxproj`). The screenshot skill tries `com.dogtormyeyes.DogtorMyEyes` first, then the bundle id from the built `Info.plist`.

### Subagents

| Agent | Role |
|-------|------|
| `.cursor/agents/accessibility-auditor.md` | Read-only. Audits `DogtorMyEyes/Views/**/*.swift` and `DogtorMyEyes/Theme.swift` for labels, Dynamic Type, and theme contrast. Does not edit. |
| `.cursor/agents/test-runner.md` | Runs `xcodebuild test` for scheme `DogtorMyEyes` on the iPhone 17 simulator when Xcode exists. After fixture or filter edits, also runs the two Python scripts. Returns a short failure digest, not the `xcodebuild` log. |

### Review

`.cursor/BUGBOT.md` tells Bugbot to flag filter or sort edits that skip `DogtorMyEyesTests/ProviderStoreTests.swift` or `scripts/verify_provider_logic.py`, new `UserDefaults` keys that are not `private static let` on `ProviderStore`, `Color(red:)` / raw hex outside `Theme.swift`, booking name/phone/slot logging, fixture rows missing `outOfPocket`, and `nextAvailable` values that are not ISO8601 UTC ending in `Z`.

### Pitfalls

- **Two checkers, two contracts.** `.cursor/skills/add-provider/scripts/validate_provider.py` checks schema for any non-empty list. `scripts/verify_provider_logic.py` asserts `len(providers) == 12` and fixed cases (`biscuit-barkley` is VSP in-network and not Davis; `rex-refract` is not VSP in-network; pediatric ids are `pip-pupil` and `daisy-dilate`; search `beagle` is only `pip-pupil`). A new provider has to update that script in the same change or the stop hook will fail the turn.
- **Dates.** `ProviderStore` decodes with `JSONDecoder.dateDecodingStrategy = .iso8601`. The schema script only accepts `YYYY-MM-DDTHH:MM:SSZ` (no fractional seconds). A value Swift accepts can still fail `validate_provider.py`.
- **Hex colors.** `Color.init?(hex:)` strips a leading `#`. `validate_provider.py` does not. Store six digits and no `#`, matching `DogtorMyEyes/Data/AGENTS.md`.
- **Ids.** The schema script rejects an empty `id`, a duplicate, or an `id` containing a space. It does not otherwise enforce kebab-case. Keep the existing slug style (`biscuit-barkley`).
