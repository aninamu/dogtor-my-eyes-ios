# Provider fixture data

Applies when editing files in this directory (`providers.json`, `ProviderStore.swift`).

## `providers.json` schema

Each provider object must include:

| Field | Rules |
|-------|--------|
| `id` | Unique slug, no spaces (e.g. `biscuit-barkley`). The schema script does not otherwise check kebab-case. |
| `name`, `breed`, `bio` | Required. Swift decodes them as `String`. The schema script only checks that the keys exist. |
| `specialty` | One of: `optometry`, `ophthalmology`, `pediatric`, `contactsAndFrames`, `lasikConsult` |
| `acceptedPlans` | Non-empty subset of `vsp`, `eyeMed`, `davis`, `spectera`, `outOfPocket` |
| `rating` | Number 0–5 |
| `reviewCount` | Required. Swift decodes it as `Int`. Rating ties sort toward the higher count. The schema script only checks that the key exists. |
| `distanceMiles` | Non-negative number |
| `services` | Non-empty list. Swift decodes `[String]`. The schema script checks that the list is non-empty, not each element. |
| `nextAvailable` | Non-empty list of `YYYY-MM-DDTHH:MM:SSZ` (e.g. `2026-10-27T14:00:00Z`). No fractional seconds. |
| `avatarColor` | 6-digit hex **without** `#` (e.g. `C4A35A`) |

## Invariants

- Every provider **must** include `outOfPocket` in `acceptedPlans`. Out-of-pocket is always treated as in-network in app logic (`Provider.isInNetwork`).
- Keep 12 providers unless the user explicitly asks for more or fewer. `scripts/verify_provider_logic.py` asserts `len(providers) == 12` and a few fixed ids. Change those asserts in the same edit when the catalog changes.
- `ProviderStore` loads this file with `JSONDecoder.dateDecodingStrategy = .iso8601`. A decode failure sets `loadError` and leaves `providers` empty.

## Checks

Schema (any non-empty count, required keys, enums, `outOfPocket`, hex, `Z` dates):

```bash
python3 .cursor/skills/add-provider/scripts/validate_provider.py
```

Filter parity with `ProviderStore.filteredProviders` (in-network, specialty, name/breed/specialty search, distance sort, rating sort with `reviewCount` tie-break) plus the count assert:

```bash
python3 scripts/verify_provider_logic.py
```

Run both after editing `providers.json`. The agent stop hook runs only the parity script, and only when `providers.json` or `ProviderStore.swift` is still dirty versus `HEAD`. A date Swift's `.iso8601` strategy accepts (for example one with fractional seconds) can still fail the schema script.
