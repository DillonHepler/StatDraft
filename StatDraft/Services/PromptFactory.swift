import Foundation

/// Builds a fixed-length prompt list for a draft with broad random variety.
enum PromptFactory {
    private struct Template {
        let season: Int
        let position: Position
        let scoring: ScoringRule
        let requirement: PromptRequirement
        let title: String
        let detail: String
    }

    private static let pool: [Template] = makePool()

    static func makePrompts(roundCount: Int) -> [Prompt] {
        let count = min(max(roundCount, 4), pool.count)
        var rng = SystemRandomNumberGenerator()
        let noveltyPool = pool.filter { !isPlainTemplate($0) }
        let baselinePool = pool.filter(isPlainTemplate)

        var selected: [Template] = []

        // Ensure every position appears, preferring novelty prompts.
        for position in Position.allCases {
            if let pick = noveltyPool.filter({ $0.position == position }).randomElement(using: &rng)
                ?? baselinePool.filter({ $0.position == position }).randomElement(using: &rng)
            {
                selected.append(pick)
            }
        }

        let noveltyTarget = min(max(Int(Double(count) * 0.75), 1), count)
        let existingKeys = Set(selected.map(templateKey))
        var noveltyRemaining = noveltyPool.shuffled().filter { !existingKeys.contains(templateKey($0)) }
        var baselineRemaining = baselinePool.shuffled().filter { !existingKeys.contains(templateKey($0)) }

        while selected.count < min(noveltyTarget, count), !noveltyRemaining.isEmpty {
            selected.append(noveltyRemaining.removeFirst())
        }
        while selected.count < count, !noveltyRemaining.isEmpty {
            selected.append(noveltyRemaining.removeFirst())
        }
        while selected.count < count, !baselineRemaining.isEmpty {
            selected.append(baselineRemaining.removeFirst())
        }
        selected.shuffle()

        return selected.prefix(count).enumerated().map { idx, t in
            return Prompt(
                roundIndex: idx,
                season: t.season,
                position: t.position,
                scoringRule: t.scoring,
                requirement: t.requirement,
                title: t.title,
                detail: t.detail
            )
        }
    }

    private static func templateKey(_ template: Template) -> String {
        "\(template.season)|\(template.position.rawValue)|\(template.scoring.rawValue)|\(template.title)"
    }

    private static func isPlainTemplate(_ template: Template) -> Bool {
        if case .any = template.requirement {
            return true
        }
        return false
    }

    private static func makePool() -> [Template] {
        var templates: [Template] = []

        func add(
            _ season: Int,
            _ position: Position,
            _ scoring: ScoringRule,
            _ requirement: PromptRequirement = .any,
            _ title: String,
            _ detail: String
        ) {
            templates.append(
                Template(
                    season: season,
                    position: position,
                    scoring: scoring,
                    requirement: requirement,
                    title: title,
                    detail: detail
                )
            )
        }

        let baselineYears = [2008, 2009, 2010, 2011, 2012, 2013, 2014, 2015, 2016, 2017, 2018, 2019, 2020]

        for year in baselineYears {
            add(year, .QB, .passingYards, .any, "\(year) QB — Air yards", "Name a QB from \(year). Points = passing yards.")
            add(year, .QB, .passingTouchdowns, .any, "\(year) QB — TD race", "Name a QB from \(year). Points = 4× passing TDs.")
        }
        for year in [2006, 2012, 2015, 2017, 2020] {
            add(year, .RB, .rushingYards, .any, "\(year) RB — Ground game", "Name an RB from \(year). Points = rushing yards.")
            add(year, .RB, .rushingTouchdowns, .any, "\(year) RB — Goal line", "Name an RB from \(year). Points = 6× rushing TDs.")
            add(year, .RB, .fantasyHalfPPR, .any, "\(year) RB — All around", "Name an RB from \(year). Points = half-PPR fantasy.")
        }
        for year in [2010, 2014, 2018, 2019, 2020] {
            add(year, .WR, .receivingYards, .any, "\(year) WR — Big plays", "Name a WR from \(year). Points = receiving yards.")
            add(year, .WR, .receptions, .any, "\(year) WR — PPR style", "Name a WR from \(year). Points = 0.5× receptions.")
            add(year, .WR, .receivingTouchdowns, .any, "\(year) WR — End zone", "Name a WR from \(year). Points = 6× receiving TDs.")
        }
        for year in [2013, 2016, 2018, 2019, 2020] {
            add(year, .TE, .receivingYards, .any, "\(year) TE — Chain mover", "Name a TE from \(year). Points = receiving yards.")
            add(year, .TE, .receivingTouchdowns, .any, "\(year) TE — Red zone", "Name a TE from \(year). Points = 6× receiving TDs.")
            add(year, .TE, .receptions, .any, "\(year) TE — Volume", "Name a TE from \(year). Points = 0.5× receptions.")
        }

        let teamYears = [2016, 2017, 2018, 2019, 2020]
        let teams = ["KC", "ATL", "TB", "LAC", "BUF", "DAL", "SEA", "GB", "SF", "PIT"]

        for year in teamYears {
            for team in teams {
                add(
                    year,
                    .QB,
                    .passingTouchdowns,
                    .playedForTeamAnyCareer(team),
                    "\(year) QB with \(team) history",
                    "Name a QB from \(year) who played for \(team) at any point in their career. Points = 4× passing TDs."
                )
                add(
                    year,
                    .RB,
                    .rushingYards,
                    .playedForTeamAnyCareer(team),
                    "\(year) RB with \(team) history",
                    "Name an RB from \(year) who played for \(team) at any point in their career. Points = rushing yards."
                )
                add(
                    year,
                    .WR,
                    .receivingYards,
                    .playedForTeamAnyCareer(team),
                    "\(year) WR with \(team) history",
                    "Name a WR from \(year) who played for \(team) at any point in their career. Points = receiving yards."
                )
                add(
                    year,
                    .TE,
                    .receivingTouchdowns,
                    .playedForTeamAnyCareer(team),
                    "\(year) TE with \(team) history",
                    "Name a TE from \(year) who played for \(team) at any point in their career. Points = 6× receiving TDs."
                )
            }
        }

        // Birth-year novelty prompts.
        let birthYears = [1988, 1989, 1990, 1991, 1992, 1993, 1994, 1995, 1996, 1997, 1998, 1999]
        for year in [2018, 2019, 2020] {
            for birthYear in birthYears {
                add(year, .QB, .passingYards, .bornInYear(birthYear), "\(year) QB born in \(birthYear)", "Name a QB from \(year) born in \(birthYear). Points = passing yards.")
                add(year, .RB, .fantasyHalfPPR, .bornInYear(birthYear), "\(year) RB born in \(birthYear)", "Name an RB from \(year) born in \(birthYear). Points = half-PPR fantasy.")
                add(year, .WR, .receptions, .bornInYear(birthYear), "\(year) WR born in \(birthYear)", "Name a WR from \(year) born in \(birthYear). Points = 0.5× receptions.")
                add(year, .TE, .receivingYards, .bornInYear(birthYear), "\(year) TE born in \(birthYear)", "Name a TE from \(year) born in \(birthYear). Points = receiving yards.")
            }
        }

        // Over/under style categories and combo rules.
        for year in [2017, 2018, 2019, 2020] {
            for threshold in [3200, 3600, 4000] {
                add(year, .QB, .passingYards, .statAtLeast(.passingYards, threshold), "\(year) QB \(threshold)+ pass yards", "Name a QB from \(year) with at least \(threshold) passing yards. Points = passing yards.")
            }
            for threshold in [8, 10, 12] {
                add(year, .QB, .passingTouchdowns, .statAtMost(.interceptions, threshold), "\(year) QB <=\(threshold) INT", "Name a QB from \(year) with \(threshold) or fewer interceptions. Points = 4× passing TDs.")
            }
            for threshold in [800, 1000, 1200] {
                add(year, .RB, .rushingYards, .statAtLeast(.rushingYards, threshold), "\(year) RB \(threshold)+ rush yards", "Name an RB from \(year) with at least \(threshold) rushing yards. Points = rushing yards.")
            }
            for threshold in [35, 45, 55] {
                add(year, .RB, .fantasyHalfPPR, .statAtLeast(.receptions, threshold), "\(year) RB \(threshold)+ catches", "Name an RB from \(year) with at least \(threshold) receptions. Points = half-PPR fantasy.")
            }
            for threshold in [900, 1000, 1200] {
                add(year, .WR, .receivingYards, .statAtLeast(.receivingYards, threshold), "\(year) WR \(threshold)+ rec yards", "Name a WR from \(year) with at least \(threshold) receiving yards. Points = receiving yards.")
                add(year, .WR, .receivingYards, .statAtMost(.receivingYards, threshold), "\(year) WR under \(threshold) rec yards", "Name a WR from \(year) with at most \(threshold) receiving yards. Points = receiving yards.")
            }
            for threshold in [6, 8, 10] {
                add(year, .WR, .receivingTouchdowns, .statAtLeast(.receivingTouchdowns, threshold), "\(year) WR \(threshold)+ rec TD", "Name a WR from \(year) with at least \(threshold) receiving TDs. Points = 6× receiving TDs.")
            }
            for threshold in [500, 650, 800] {
                add(year, .TE, .receivingYards, .statAtLeast(.receivingYards, threshold), "\(year) TE \(threshold)+ rec yards", "Name a TE from \(year) with at least \(threshold) receiving yards. Points = receiving yards.")
                add(year, .TE, .receivingYards, .statAtMost(.receivingYards, threshold), "\(year) TE under \(threshold) rec yards", "Name a TE from \(year) with at most \(threshold) receiving yards. Points = receiving yards.")
            }
        }

        for year in [2018, 2019, 2020] {
            for team in teams {
                add(
                    year,
                    .WR,
                    .receivingYards,
                    .playedForTeamAnyCareerAndStatAtLeast(team, .receivingYards, 1000),
                    "\(year) WR 1k+ with \(team) history",
                    "Name a WR from \(year) with at least 1,000 receiving yards who played for \(team) at any point in their career. Points = receiving yards."
                )
                add(
                    year,
                    .TE,
                    .receivingTouchdowns,
                    .playedForTeamAnyCareerAndStatAtMost(team, .receivingTouchdowns, 8),
                    "\(year) TE <=8 TD with \(team) history",
                    "Name a TE from \(year) with 8 or fewer receiving TDs who played for \(team) at any point in their career. Points = 6× receiving TDs."
                )
            }
        }

        return templates
    }
}
