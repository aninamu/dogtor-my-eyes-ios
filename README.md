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
  Support/                 # feature flags, logging, accessibility IDs
  Views/...
DogtorMyEyesTests/
```

Mock data lives in `DogtorMyEyes/Data/providers.json`. There is no auth and no network layer.
