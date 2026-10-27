#!/usr/bin/env python3
"""Mirror ProviderStore filter/in-network logic against providers.json (Linux CI stand-in)."""

from __future__ import annotations

import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / "DogtorMyEyes" / "Data" / "providers.json"

SPECIALTY_DISPLAY = {
    "optometry": "Optometry",
    "ophthalmology": "Ophthalmology",
    "pediatric": "Pediatric",
    "contactsAndFrames": "Contacts & Frames",
    "lasikConsult": "LASIK Consult",
}


def is_in_network(provider: dict, plan: str) -> bool:
    return plan in provider["acceptedPlans"]


def accepts(provider: dict, coverage: str) -> bool:
    if coverage == "selfPay":
        return provider.get("acceptsSelfPay", True)
    return is_in_network(provider, coverage)


def filtered(
    providers: list[dict],
    *,
    plan: str,
    in_network_only: bool = True,
    specialty: str | None = None,
    search: str = "",
    sort: str = "distance",
) -> list[dict]:
    result = list(providers)
    if plan == "selfPay" or in_network_only:
        result = [p for p in result if accepts(p, plan)]
    if specialty:
        result = [p for p in result if p["specialty"] == specialty]
    query = search.strip().lower()
    if query:
        result = [
            p
            for p in result
            if query in p["name"].lower()
            or query in p["breed"].lower()
            or query in SPECIALTY_DISPLAY[p["specialty"]].lower()
        ]
    if sort == "distance":
        result.sort(key=lambda p: p["distanceMiles"])
    elif sort == "rating":
        result.sort(key=lambda p: (-p["rating"], -p["reviewCount"]))
    return result


def main() -> int:
    providers = json.loads(DATA.read_text())
    assert len(providers) == 12
    assert all("outOfPocket" not in p["acceptedPlans"] for p in providers), "self-pay is not an insurance plan"
    assert all("nextAvailable" not in p for p in providers), "openings must be relative slotTemplates"
    for p in providers:
        for t in p["slotTemplates"]:
            assert t["dayOffset"] >= 0 and 0 <= t["hour"] < 24 and 0 <= t["minute"] < 60, p["id"]

    biscuit = next(p for p in providers if p["id"] == "biscuit-barkley")
    assert is_in_network(biscuit, "vsp")
    assert not is_in_network(biscuit, "davis")
    assert not is_in_network(biscuit, "selfPay")
    assert accepts(biscuit, "selfPay")

    vsp = filtered(providers, plan="vsp", in_network_only=True)
    assert all(is_in_network(p, "vsp") for p in vsp)
    assert "biscuit-barkley" in {p["id"] for p in vsp}
    assert "rex-refract" not in {p["id"] for p in vsp}  # davis only

    pediatric = filtered(providers, plan="vsp", in_network_only=False, specialty="pediatric")
    assert {p["id"] for p in pediatric} == {"pip-pupil", "daisy-dilate"}

    beagles = filtered(providers, plan="vsp", in_network_only=False, search="beagle")
    assert {p["id"] for p in beagles} == {"pip-pupil"}

    by_distance = filtered(providers, plan="selfPay", in_network_only=True, sort="distance")
    distances = [p["distanceMiles"] for p in by_distance]
    assert distances == sorted(distances)

    by_rating = filtered(providers, plan="selfPay", in_network_only=True, sort="rating")
    ratings = [(p["rating"], p["reviewCount"]) for p in by_rating]
    assert ratings == sorted(ratings, key=lambda t: (-t[0], -t[1]))

    print(f"OK — {len(providers)} providers, filter/in-network logic verified")
    print(f"VSP in-network count: {len(vsp)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
