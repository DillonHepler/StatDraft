#!/usr/bin/env python3
"""Validate StatDraft bundled stats DB and report prompt coverage."""

from __future__ import annotations

import json
from pathlib import Path

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
        if player.get("birthYear") is not None:
            assert isinstance(player["birthYear"], int)
        if player.get("draftYear") is not None:
            assert isinstance(player["draftYear"], int)
        if player.get("draftRound") is not None:
            assert isinstance(player["draftRound"], int)
        if player.get("draftPick") is not None:
            assert isinstance(player["draftPick"], int)
        if player.get("superBowlWins") is not None:
            assert isinstance(player["superBowlWins"], int)
        if player.get("collegeName") is not None:
            assert isinstance(player["collegeName"], str)
        if player.get("careerTeams") is not None:
            assert isinstance(player["careerTeams"], list)
        assert isinstance(player["seasons"], dict) and player["seasons"]
        for season, line in player["seasons"].items():
            int(season)
            assert line["position"] in valid_positions
            if line.get("team") is not None:
                assert isinstance(line["team"], str)
            for key in int_keys:
                assert isinstance(line[key], int), f"Bad {key} for {player['id']} {season}"

    all_years = sorted({int(y) for player in players for y in player["seasons"].keys()})
    print(f"Players: {len(players)}")
    print(f"Season coverage: {all_years[0]}-{all_years[-1]}")


if __name__ == "__main__":
    main()
