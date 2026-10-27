# Dogtor My Eyes — agent guide

SwiftUI iOS marketplace for browsing **in-network eye care**. Every provider is a dog. There is **no backend, no auth, and no network layer**.

## Layout

```
DogtorMyEyes/
  DogtorMyEyesApp.swift   # App entry + tab shell
  Theme.swift             # Colors, fonts, NetworkBadge, ProviderAvatar
  Models/Provider.swift   # Specialty, InsurancePlan, Provider
  Data/providers.json     # Mock fixture (~12 providers)
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

On Linux (or without Xcode), validate fixture + filter logic with:

```bash
python3 scripts/verify_provider_logic.py
```

## Constraints

- Prefer editing `providers.json` over inventing providers in Swift.
- Keep `ProviderStore.filteredProviders` and `scripts/verify_provider_logic.py` in sync.
- Persist only via the existing `UserDefaults` keys in `ProviderStore` (`selectedInsurancePlan`, `favoriteProviderIDs`, `requestedAppointments`).
- Reuse `Theme`, `NetworkBadge`, and `ProviderAvatar` — do not hardcode teal/sand colors in views.
- Booking is local-only (`BookingSheet`); do not add networking or analytics SDKs.

## Nested guides

- Provider fixture rules: [DogtorMyEyes/Data/AGENTS.md](DogtorMyEyes/Data/AGENTS.md)
