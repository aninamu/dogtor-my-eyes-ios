---
name: add-provider
description: >-
  Adds a new dog eye-care provider to providers.json with schema validation.
  Use when the user asks to add a provider, dogtor, vet, or new specialty listing.
---

# Add a provider

## Workflow

1. Read [DogtorMyEyes/Data/AGENTS.md](../../../DogtorMyEyes/Data/AGENTS.md) and skim existing entries in `DogtorMyEyes/Data/providers.json`.
2. Choose a unique kebab-case `id` (e.g. `milo-myopia`). Confirm it is not already used.
3. Append a new object matching the fixture schema:
   - `specialty`: one of `optometry`, `ophthalmology`, `pediatric`, `contactsAndFrames`, `lasikConsult`
   - `acceptedPlans`: include `outOfPocket` plus at least one real plan
   - `nextAvailable`: 2–3 ISO8601 UTC times ending in `Z`
   - `avatarColor`: 6-digit hex without `#`
   - Playful but clinical bio; 2–4 services
4. Validate the whole fixture:

```bash
python3 .cursor/skills/add-provider/scripts/validate_provider.py
```

5. Re-check filter parity (the script asserts `len(providers) == 12` today — if you intentionally changed the count, update that assert in `scripts/verify_provider_logic.py` first):

```bash
python3 scripts/verify_provider_logic.py
```

6. Summarize the new provider (id, specialty, plans) for the user.

## Do not

- Invent specialties or plan enums not in `Provider.swift`
- Put `#` in `avatarColor`
- Skip `outOfPocket`
