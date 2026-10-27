# Provider fixture data

Applies when editing files in this directory (`providers.json`, `ProviderStore.swift`).

## `providers.json` schema

Each provider object must include:

| Field | Rules |
|-------|--------|
| `id` | Unique kebab-case slug (e.g. `biscuit-barkley`) |
| `specialty` | One of: `optometry`, `ophthalmology`, `pediatric`, `contactsAndFrames`, `lasikConsult` |
| `acceptedPlans` | Subset of `vsp`, `eyeMed`, `davis`, `spectera`, `outOfPocket` |
| `nextAvailable` | ISO8601 UTC timestamps ending in `Z` (e.g. `2026-10-27T14:00:00Z`) |
| `avatarColor` | 6-digit hex **without** `#` (e.g. `C4A35A`) |
| `rating` | Double 0–5 |
| `distanceMiles` | Non-negative double |

## Invariants

- Every provider **must** include `outOfPocket` in `acceptedPlans`. Out-of-pocket is always treated as in-network in app logic.
- Keep ~12 providers unless the user explicitly asks for more or fewer.
- After editing this file, run: `python3 scripts/verify_provider_logic.py`

## Decoder

`ProviderStore` loads with `JSONDecoder.dateDecodingStrategy = .iso8601`. Non-ISO8601 dates will fail the decode and empty the catalog.
