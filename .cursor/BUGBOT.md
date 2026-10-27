# Bugbot review guide — Dogtor My Eyes

SwiftUI demo marketplace for in-network dog eye-care providers. No backend, no auth, no real PHI. Tune PR reviews for **real regressions**, not style nits.

## Always flag

- **Filter logic without tests** — changes to `Provider.isInNetwork` or `ProviderStore.filteredProviders` without a matching case in `DogtorMyEyesTests/ProviderStoreTests.swift`.
- **Python/Swift drift** — Swift filter/sort changes without updating `scripts/verify_provider_logic.py` (or the reverse).
- **Loose UserDefaults keys** — new `UserDefaults` string keys that are not declared as `private static let` constants on `ProviderStore`.
- **Hardcoded colors** — `Color(red:...)` / raw hex styling outside `Theme.swift`.
- **Booking PII in logs** — `print` / logging that could emit patient name, phone, or slot times from `BookingSheet`.
- **Missing out-of-pocket** — `providers.json` entries whose `acceptedPlans` omit `outOfPocket`.
- **Non-ISO dates** — `nextAvailable` values that are not ISO8601 UTC with a trailing `Z`.

## Do not flag

- Playful dog-themed copy, breed jokes, or punny provider names.
- Absence of a real backend, auth, analytics, or push notifications.
- Local-only favorites / plan persistence via `UserDefaults`.
- Static HTML under `scripts/ui-mock/`.
- Cursor config under `.cursor/` unless it clearly breaks the app build.

## Test expectations

| Area changed | Expect |
|--------------|--------|
| `ProviderStore` / `Provider.isInNetwork` | XCTest coverage + `verify_provider_logic.py` still green |
| `providers.json` | Schema still valid; count assert updated if intentional |
| `Theme.swift` / Views | No new hardcoded brand colors; icon-only controls labeled |

## Example findings

> **Filter without tests:** `filteredProviders` gained a new specialty branch but `ProviderStoreTests` was not updated.

> **Missing outOfPocket:** provider `rex-refract` drops cash-pay users from every in-network browse.

> **Color drift:** `BrowseView` uses `Color(red: 0.18, ...)` instead of `Theme.teal`.
