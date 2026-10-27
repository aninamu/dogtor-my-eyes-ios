# Dogtor My Eyes

SwiftUI iOS marketplace for browsing **in-network eye care** — every provider is a dog.

## Features

- Browse ~12 dog eye-care providers with specialty filters
- Insurance plan picker (VSP, EyeMed, Davis Vision, Spectera, Out of Pocket)
- In-network filter, search, and sort by distance or rating
- Provider detail with bio, services, accepted plans, and next slots
- Local appointment request sheet (no backend)
- Favorites persisted with `UserDefaults`

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

On Linux (no Xcode), validate the fixture schema and the filter logic with:

```bash
python3 .cursor/skills/add-provider/scripts/validate_provider.py
python3 scripts/verify_provider_logic.py
```

`validate_provider.py` checks shape. `verify_provider_logic.py` mirrors `ProviderStore` filtering and asserts the catalog still has 12 providers. See [DogtorMyEyes/Data/AGENTS.md](DogtorMyEyes/Data/AGENTS.md).

## Project layout

```
DogtorMyEyes/
  DogtorMyEyesApp.swift
  Theme.swift
  Models/Provider.swift
  Data/providers.json
  Data/ProviderStore.swift
  Views/...
DogtorMyEyesTests/
  ProviderStoreTests.swift
```

Mock data lives in `DogtorMyEyes/Data/providers.json`. There is no auth and no network layer.

## Agent tooling

Cursor rules, hooks, skills, subagents, and the Bugbot guide are under `.cursor/`. What they run, and where they diverge from the Swift decoder, is in [AGENTS.md](AGENTS.md).
