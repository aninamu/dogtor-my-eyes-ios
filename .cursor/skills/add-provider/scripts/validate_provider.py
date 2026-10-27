#!/usr/bin/env python3
"""Validate DogtorMyEyes/Data/providers.json against the fixture schema."""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[4]
DATA = ROOT / "DogtorMyEyes" / "Data" / "providers.json"

SPECIALTIES = {
    "optometry",
    "ophthalmology",
    "pediatric",
    "contactsAndFrames",
    "lasikConsult",
}
PLANS = {"vsp", "eyeMed", "davis", "spectera", "outOfPocket"}
HEX = re.compile(r"^[0-9A-Fa-f]{6}$")
ISO_Z = re.compile(r"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$")
REQUIRED = {
    "id",
    "name",
    "breed",
    "specialty",
    "acceptedPlans",
    "rating",
    "reviewCount",
    "distanceMiles",
    "bio",
    "services",
    "nextAvailable",
    "avatarColor",
}


def fail(message: str) -> None:
    print(f"FAIL: {message}", file=sys.stderr)
    raise SystemExit(1)


def main() -> int:
    if not DATA.is_file():
        fail(f"missing {DATA}")

    try:
        providers = json.loads(DATA.read_text())
    except json.JSONDecodeError as exc:
        fail(f"invalid JSON: {exc}")

    if not isinstance(providers, list) or not providers:
        fail("providers.json must be a non-empty array")

    ids: set[str] = set()
    for i, provider in enumerate(providers):
        prefix = f"[{i}]"
        if not isinstance(provider, dict):
            fail(f"{prefix} not an object")

        missing = REQUIRED - provider.keys()
        if missing:
            fail(f"{prefix} missing fields: {sorted(missing)}")

        pid = provider["id"]
        if not isinstance(pid, str) or not pid or " " in pid:
            fail(f"{prefix} id must be a non-empty kebab-case string")
        if pid in ids:
            fail(f"{prefix} duplicate id: {pid}")
        ids.add(pid)

        if provider["specialty"] not in SPECIALTIES:
            fail(f"{prefix} unknown specialty: {provider['specialty']}")

        plans = provider["acceptedPlans"]
        if not isinstance(plans, list) or not plans:
            fail(f"{prefix} acceptedPlans must be a non-empty list")
        for plan in plans:
            if plan not in PLANS:
                fail(f"{prefix} unknown plan: {plan}")
        if "outOfPocket" not in plans:
            fail(f"{prefix} acceptedPlans must include outOfPocket")

        if not HEX.match(str(provider["avatarColor"])):
            fail(f"{prefix} avatarColor must be 6-digit hex without #")

        slots = provider["nextAvailable"]
        if not isinstance(slots, list) or not slots:
            fail(f"{prefix} nextAvailable must be a non-empty list")
        for slot in slots:
            if not isinstance(slot, str) or not ISO_Z.match(slot):
                fail(f"{prefix} nextAvailable entry must be ISO8601 with Z: {slot!r}")

        if not isinstance(provider["services"], list) or not provider["services"]:
            fail(f"{prefix} services must be a non-empty list")

        rating = provider["rating"]
        if not isinstance(rating, (int, float)) or not 0 <= float(rating) <= 5:
            fail(f"{prefix} rating must be 0–5")

        if float(provider["distanceMiles"]) < 0:
            fail(f"{prefix} distanceMiles must be >= 0")

    print(f"OK: {len(providers)} providers validated ({DATA})")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
