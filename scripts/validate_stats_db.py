#!/usr/bin/env python3
"""Validate StatDraft bundled stats DB and report prompt coverage."""

from __future__ import annotations

import json
from pathlib import Path

PROMPT_BUCKETS = [
    (2007, "QB"),
    (2011, "QB"),
    (2006, "RB"),
    (2012, "RB"),
    (2014, "WR"),
    (2018, "WR"),
    (2013, "TE"),
    (2009, "QB"),
    (2015, "RB"),
    (2010, "WR"),
    (2016, "TE"),
    (2008, "QB"),
    (2017, "RB"),
    (2019, "WR"),
    (2005, "QB"),
    (2020, "RB"),
]


def main() -> None:
    path = Path("StatDraft/Resources/demo_stats.json")
    payload = json.loads(path.read_text(encoding="utf-8"))
    players = payload["players"]

    ids = [p["id"] for p in players]
    assert len(ids) == len(set(ids)), "Duplicate player IDs found"

    int_keys = [
        "games",
        "passingYards",
        "passingTD",
        "interceptions",
        "rushingYards",
        "rushingTD",
        "receptions",
        "receivingYards",
        "receivingTD",
    ]
    valid_positions = {"QB", "RB", "WR", "TE"}
    for player in players:
        assert isinstance(player["displayName"], str) and player["displayName"].strip()
        assert isinstance(player["aliases"], list) and player["aliases"]
        assert isinstance(player["seasons"], dict) and player["seasons"]
        for season, line in player["seasons"].items():
            int(season)
            assert line["position"] in valid_positions
            for key in int_keys:
                assert isinstance(line[key], int), f"Bad {key} for {player['id']} {season}"

    print(f"Players: {len(players)}")
    min_coverage = 10_000
    for season, position in PROMPT_BUCKETS:
        count = 0
        for player in players:
            line = player["seasons"].get(str(season))
            if line and line["position"] == position:
                count += 1
        min_coverage = min(min_coverage, count)
        print(f"{season} {position}: {count}")
    print(f"Minimum coverage: {min_coverage}")


if __name__ == "__main__":
    main()
