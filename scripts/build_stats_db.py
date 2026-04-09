#!/usr/bin/env python3
"""Builds StatDraft bundled player database from nflverse parquet data."""

from __future__ import annotations

import json
from pathlib import Path

import pandas as pd


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
    source = Path("data/player_stats.parquet")
    if not source.exists():
        raise FileNotFoundError(
            "Missing data/player_stats.parquet. Download it first:\n"
            "curl -L "
            "\"https://github.com/nflverse/nflverse-data/releases/download/player_stats/player_stats.parquet\" "
            "-o data/player_stats.parquet"
        )

    years = sorted({year for year, _ in PROMPT_BUCKETS})
    weekly_cols = [
        "season",
        "week",
        "season_type",
        "player_id",
        "player_name",
        "player_display_name",
        "position",
        "passing_yards",
        "passing_tds",
        "interceptions",
        "rushing_yards",
        "rushing_tds",
        "receptions",
        "receiving_yards",
        "receiving_tds",
    ]
    weekly = pd.read_parquet(source, columns=weekly_cols)
    weekly = weekly[weekly["season"].isin(years)]
    weekly = weekly[weekly["season_type"] == "REG"]
    weekly = weekly[weekly["position"].isin(["QB", "RB", "WR", "TE"])].copy()
    weekly["player_name"] = weekly["player_display_name"].fillna(weekly["player_name"])
    weekly["player_name"] = weekly["player_name"].fillna("").astype(str).str.strip()
    weekly = weekly[weekly["player_name"] != ""]

    numeric = [
        "passing_yards",
        "passing_tds",
        "interceptions",
        "rushing_yards",
        "rushing_tds",
        "receptions",
        "receiving_yards",
        "receiving_tds",
    ]
    for c in numeric:
        weekly[c] = pd.to_numeric(weekly[c], errors="coerce").fillna(0)

    grouped = (
        weekly.groupby(["player_id", "player_name", "season", "position"], as_index=False)
        .agg(
            games=("week", "nunique"),
            passing_yards=("passing_yards", "sum"),
            passing_tds=("passing_tds", "sum"),
            interceptions=("interceptions", "sum"),
            rushing_yards=("rushing_yards", "sum"),
            rushing_tds=("rushing_tds", "sum"),
            receptions=("receptions", "sum"),
            receiving_yards=("receiving_yards", "sum"),
            receiving_tds=("receiving_tds", "sum"),
        )
        .sort_values(["season", "position", "player_name"])
    )
    playable = grouped.copy()

    seasons_by_player: dict[str, dict[str, dict[str, int | str]]] = {}
    names_by_player: dict[str, str] = {}
    positions_by_player: dict[str, set[str]] = {}

    for row in playable.itertuples(index=False):
        player_id = str(row.player_id).strip()
        if not player_id:
            continue
        name = str(row.player_name).strip()
        season_key = str(int(row.season))
        position = str(row.position).strip()
        line = {
            "position": position,
            "games": int(round(row.games)),
            "passingYards": int(round(row.passing_yards)),
            "passingTD": int(round(row.passing_tds)),
            "interceptions": int(round(row.interceptions)),
            "rushingYards": int(round(row.rushing_yards)),
            "rushingTD": int(round(row.rushing_tds)),
            "receptions": int(round(row.receptions)),
            "receivingYards": int(round(row.receiving_yards)),
            "receivingTD": int(round(row.receiving_tds)),
        }
        names_by_player[player_id] = name
        seasons_by_player.setdefault(player_id, {})[season_key] = line
        positions_by_player.setdefault(player_id, set()).add(position)

    players_payload = []
    for player_id, seasons in sorted(seasons_by_player.items(), key=lambda kv: names_by_player[kv[0]].lower()):
        name = names_by_player[player_id]
        aliases = build_aliases(name)
        players_payload.append(
            {
                "id": sanitize_id(player_id, name),
                "displayName": name,
                "aliases": aliases,
                "seasons": seasons,
            }
        )

    payload = {"players": players_payload}
    out = Path("StatDraft/Resources/demo_stats.json")
    out.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")

    coverage = compute_coverage(players_payload)
    print(f"Built players: {len(players_payload)}")
    for year, pos in PROMPT_BUCKETS:
        key = f"{year}_{pos}"
        print(f"{year} {pos}: {coverage.get(key, 0)}")


def build_aliases(name: str) -> list[str]:
    parts = [p for p in name.replace(".", "").split(" ") if p]
    aliases: list[str] = []
    if len(parts) >= 2:
        first, last = parts[0], parts[-1]
        aliases.extend([last, f"{first} {last}", f"{first[0]} {last}"])
    aliases.append(name)
    # Preserve order + uniqueness
    seen = set()
    out = []
    for alias in aliases:
        alias = alias.strip()
        if alias and alias.lower() not in seen:
            seen.add(alias.lower())
            out.append(alias)
    return out


def sanitize_id(player_id: str, fallback_name: str) -> str:
    value = player_id.strip().lower().replace("-", "_")
    if value:
        return value
    return fallback_name.strip().lower().replace(" ", "_")


def compute_coverage(players_payload: list[dict]) -> dict[str, int]:
    coverage: dict[str, int] = {}
    for year, pos in PROMPT_BUCKETS:
        c = 0
        for player in players_payload:
            line = player["seasons"].get(str(year))
            if line and line["position"] == pos:
                c += 1
        coverage[f"{year}_{pos}"] = c
    return coverage


if __name__ == "__main__":
    main()
