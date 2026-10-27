# Dogtor My Eyes

SwiftUI iOS marketplace for browsing **in-network eye care** — every provider is a dog.

## Features

- Browse ~12 dog eye-care providers with specialty filters
- Coverage picker: insurance plans (VSP, EyeMed, Davis Vision, Spectera) or self-pay, which is modeled separately and never shown as "in-network"
- In-network filter, search, and sort by distance or rating
- Provider detail with bio, services, accepted plans, and upcoming openings shown in the clinic's time zone
- Openings are generated relative to today from `slotTemplates`, and past times are never shown or bookable
- Appointments tab: requests are saved on-device, grouped into Upcoming (soonest first) and Past
- Favorites, coverage, and appointment requests persisted with `UserDefaults` (declared in `PrivacyInfo.xcprivacy`)

## Requirements

- Xcode 16+ (tested against Xcode 27.x tooling)
- iOS 18.0+ simulator or device

## Open & run

Requires macOS with Xcode 16+.

```bash
open DogtorMyEyes.xcodeproj
```

Or from the command line:

```bash
xcodebuild \
  -scheme DogtorMyEyes \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  build test
```

On Linux (no Xcode), sanity-check the fixture shape with:

```bash
python3 scripts/verify_provider_logic.py
```

CI (`.github/workflows/ios-ci.yml`) runs that script and `xcodebuild test` on a macOS runner for every pull request.

## Feature flags

`FeatureFlags` resolves each `FeatureFlag` from, in order: the launch arguments `--enable-<flag>` / `--disable-<flag>`, then the
UserDefaults key `FeatureFlag.<flag>` (also settable as a launch argument, `-FeatureFlag.<flag> YES`), then the flag's default.
`phase1Finder` defaults to on in Debug builds and off in Release.

## Conversational finder (Phase 1, `phase1Finder`)

A search bar pinned to the top of Browse accepts requests like "my pup's eye is cloudy, I have VSP, near Brooklyn, Saturday".
The query becomes the app's structured filters (specialty, plan, in-network only, area or distance, urgency), shown as
editable chips, and the normal provider cards are ranked with a deterministic "why this match" line.

- Parsers only produce filter values. Providers, coverage, and openings always come from `providers.json`.
- `FinderQueryParser` is the seam: `RuleBasedQueryParser` (deterministic keywords, multilingual, typo-tolerant) is always
  available; `FoundationModelsQueryParser` uses Apple's on-device model on iOS 26+ when Apple Intelligence is ready.
  `ResilientFinderParser` times out slow model calls, falls back to the rules on any error, discards values outside the
  catalog, and always takes triage from the rules. A server-backed parser can conform to the same protocol later.
- The finder bar is the only search field while the flag is on. If nothing is understood, it falls back to keyword
  search over provider names and breeds.
- Inferred or typo-corrected chips (and a plan taken from settings) get a dashed "guessed" outline, and one clarify
  question asks about the most important uncertain chip. Urgent requests are never questioned.
- With no matches, the empty state names the chip that's limiting results and offers a one-tap way to loosen it.
- VoiceOver announces the match count when results change, plus a note when keyword fallback turns on.
- Symptoms show a persistent "Not a diagnosis" note; red-flag wording shows urgent-care guidance first.
- Nothing is booked automatically: the user still picks a slot and taps Confirm.
- Query text never leaves the device. There are no network calls or API keys.
- `--disable-finderOnDeviceModel` forces the rules parser; `--disable-phase1Finder` hides the finder.

Evals: `DogtorMyEyesTests/Fixtures/finder_eval.json` holds the prompts and expected filters; `FinderEvalTests` runs the rules
parser against every case.

## UI automation

Stable accessibility identifiers live in `DogtorMyEyes/Support/AccessibilityID.swift` (for example `browse.planPicker`,
`browse.inNetworkToggle`, `booking.confirm`). Treat them as API for QA scripts.

## Project layout

```
DogtorMyEyes/
  DogtorMyEyesApp.swift
  Theme.swift
  Palette.swift            # platform-independent colors (contrast-tested)
  PrivacyInfo.xcprivacy
  Models/Provider.swift
  Data/providers.json      # fictional demo data with relative slotTemplates
  Data/ProviderCatalog.swift
  Data/ProviderStore.swift
  Data/AppointmentStore.swift
  Data/SlotSchedule.swift
  Finder/                  # finder filters, parsers, ranking, view model
  Support/                 # feature flags, logging, connectivity, accessibility IDs
  Views/...
DogtorMyEyesTests/
```

Mock data lives in `DogtorMyEyes/Data/providers.json`. There is no auth and no network layer.
