#!/usr/bin/env python3
"""Builds StatDraft bundled player database from nflverse parquet data."""

from __future__ import annotations

import json
from pathlib import Path

import pandas as pd


MIN_SEASON = 1999
MAX_SEASON = 2025


def main() -> None:
    source = Path("data/player_stats.parquet")
    players_source = Path("data/players.parquet")
    if not source.exists():
        raise FileNotFoundError(
            "Missing data/player_stats.parquet. Download it first:\n"
            "curl -L "
            "\"https://github.com/nflverse/nflverse-data/releases/download/player_stats/player_stats.parquet\" "
            "-o data/player_stats.parquet"
        )
    if not players_source.exists():
        raise FileNotFoundError(
            "Missing data/players.parquet. Download it first:\n"
            "curl -L "
            "\"https://github.com/nflverse/nflverse-data/releases/download/players/players.parquet\" "
            "-o data/players.parquet"
        )

    weekly_cols = [
        "season",
        "week",
        "season_type",
        "player_id",
        "player_name",
        "player_display_name",
        "position",
        "recent_team",
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
    weekly = weekly[(weekly["season"] >= MIN_SEASON) & (weekly["season"] <= MAX_SEASON)]
    weekly = weekly[weekly["season_type"] == "REG"]
    weekly = weekly[weekly["position"].isin(["QB", "RB", "WR", "TE"])].copy()
    weekly["player_name"] = weekly["player_display_name"].fillna(weekly["player_name"])
    weekly["player_name"] = weekly["player_name"].fillna("").astype(str).str.strip()
    weekly["recent_team"] = weekly["recent_team"].fillna("").astype(str).str.strip()
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
        weekly.groupby(["player_id", "player_name", "season", "position"], as_index=False, dropna=False)
        .agg(
            games=("week", "nunique"),
            team=("recent_team", _mode_or_empty),
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

    players_ref = pd.read_parquet(
        players_source,
        columns=["gsis_id", "birth_date", "draft_year", "draft_round", "draft_pick", "latest_team", "college_name"]
    )
    players_ref["birth_date"] = players_ref["birth_date"].astype(str)
    players_ref["birth_year"] = pd.to_numeric(players_ref["birth_date"].str[:4], errors="coerce")
    players_ref["draft_year"] = pd.to_numeric(players_ref["draft_year"], errors="coerce")
    players_ref["draft_round"] = pd.to_numeric(players_ref["draft_round"], errors="coerce")
    players_ref["draft_pick"] = pd.to_numeric(players_ref["draft_pick"], errors="coerce")
    players_ref["latest_team"] = players_ref["latest_team"].fillna("").astype(str).str.strip()
    players_ref["college_name"] = players_ref["college_name"].fillna("").astype(str).str.strip()
    birth_year_by_id = {
        str(row.gsis_id): int(row.birth_year)
        for row in players_ref.itertuples(index=False)
        if pd.notna(row.gsis_id) and pd.notna(row.birth_year)
    }
    draft_info_by_id = {
        str(row.gsis_id): (
            int(row.draft_year) if pd.notna(row.draft_year) else None,
            int(row.draft_round) if pd.notna(row.draft_round) else None,
            int(row.draft_pick) if pd.notna(row.draft_pick) else None,
        )
        for row in players_ref.itertuples(index=False)
        if pd.notna(row.gsis_id)
    }
    latest_team_by_id = {
        str(row.gsis_id): str(row.latest_team).strip()
        for row in players_ref.itertuples(index=False)
        if pd.notna(row.gsis_id) and str(row.latest_team).strip()
    }
    college_by_id = {
        str(row.gsis_id): str(row.college_name).strip()
        for row in players_ref.itertuples(index=False)
        if pd.notna(row.gsis_id) and str(row.college_name).strip()
    }

    champion_teams_by_season = {
        1999: {"STL"},
        2000: {"BAL"},
        2001: {"NE"},
        2002: {"TB"},
        2003: {"NE"},
        2004: {"NE"},
        2005: {"PIT"},
        2006: {"IND"},
        2007: {"NYG"},
        2008: {"PIT"},
        2009: {"NO"},
        2010: {"GB"},
        2011: {"NYG"},
        2012: {"BAL"},
        2013: {"SEA"},
        2014: {"NE"},
        2015: {"DEN"},
        2016: {"NE"},
        2017: {"PHI"},
        2018: {"NE"},
        2019: {"KC"},
        2020: {"TB"},
        2021: {"LA", "LAR"},
        2022: {"KC"},
        2023: {"KC"},
        2024: {"PHI"},
    }
    super_bowl_wins_by_id: dict[str, int] = {}
    champion_player_seasons: set[tuple[str, int]] = set()
    for row in playable.itertuples(index=False):
        player_id = str(row.player_id).strip()
        if not player_id:
            continue
        season = int(row.season)
        team = str(row.team).strip().upper()
        if season in champion_teams_by_season and team in champion_teams_by_season[season]:
            key = (player_id, season)
            if key not in champion_player_seasons:
                champion_player_seasons.add(key)
                super_bowl_wins_by_id[player_id] = super_bowl_wins_by_id.get(player_id, 0) + 1

    seasons_by_player: dict[str, dict[str, dict[str, int | str]]] = {}
    names_by_player: dict[str, str] = {}

    for row in playable.itertuples(index=False):
        player_id = str(row.player_id).strip()
        if not player_id:
            continue
        name = str(row.player_name).strip()
        season_key = str(int(row.season))
        position = str(row.position).strip()
        line = {
            "position": position,
            "team": str(row.team).strip() or None,
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

    players_payload = []
    for player_id, seasons in sorted(seasons_by_player.items(), key=lambda kv: names_by_player[kv[0]].lower()):
        name = names_by_player[player_id]
        aliases = build_aliases(name)
        season_teams = {
            (line.get("team") or "").strip().upper()
            for line in seasons.values()
            if (line.get("team") or "").strip()
        }
        latest_team = latest_team_by_id.get(player_id, "").strip().upper()
        if latest_team:
            season_teams.add(latest_team)
        players_payload.append(
            {
                "id": sanitize_id(player_id, name),
                "displayName": name,
                "aliases": aliases,
                "birthYear": birth_year_by_id.get(player_id),
                "draftYear": draft_info_by_id.get(player_id, (None, None, None))[0],
                "draftRound": draft_info_by_id.get(player_id, (None, None, None))[1],
                "draftPick": draft_info_by_id.get(player_id, (None, None, None))[2],
                "superBowlWins": super_bowl_wins_by_id.get(player_id, 0),
                "collegeName": college_by_id.get(player_id),
                "careerTeams": sorted(season_teams),
                "seasons": seasons,
            }
        )

    payload = {"players": players_payload}
    out = Path("StatDraft/Resources/demo_stats.json")
    out.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")

    print(f"Built players: {len(players_payload)}")
    print(f"Season range: {MIN_SEASON}-{MAX_SEASON}")


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


def _mode_or_empty(series: pd.Series) -> str:
    cleaned = series.dropna().astype(str).str.strip()
    cleaned = cleaned[cleaned != ""]
    if cleaned.empty:
        return ""
    mode = cleaned.mode()
    if mode.empty:
        return ""
    return str(mode.iloc[0])


if __name__ == "__main__":
    main()
