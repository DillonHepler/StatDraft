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

    private static let minEligibleForConstraint = 5
    private static let pool: [Template] = makePool()

    /// Caps how many prompts from the same *family* appear in one draft (e.g. name-letter games).
    private static func maxPerDiversityBucket(_ bucket: String) -> Int {
        switch bucket {
        case "nameLetter": return 2
        case "alliteration": return 2
        case "college": return 4
        case "draft12", "draft37": return 2
        case "draftYear", "draftSingleRound", "draftAfterRound", "draftPickBand": return 2
        case "teamCareer": return 3
        case "teamStatCombo": return 2
        case "statThreshold": return 3
        case "rings": return 2
        case "teamCount": return 2
        case "plain": return 99
        default: return 2
        }
    }

    private static func diversityBucket(for requirement: PromptRequirement) -> String {
        switch requirement {
        case .any: return "plain"
        case .nameStartsWithLetter: return "nameLetter"
        case .alliterativeName: return "alliteration"
        case .attendedCollege: return "college"
        case .draftedInRounds1Or2: return "draft12"
        case .draftedInRounds3Through7: return "draft37"
        case .draftedInYear: return "draftYear"
        case .draftedInRound: return "draftSingleRound"
        case .draftedAfterRound: return "draftAfterRound"
        case .draftedAtPickAtMost, .draftedAtPickRange: return "draftPickBand"
        case .playedForTeamAnyCareer: return "teamCareer"
        case .playedForTeamInSeason: return "teamCareer"
        case .playedForTeamAnyCareerAndStatAtLeast, .playedForTeamAnyCareerAndStatAtMost: return "teamStatCombo"
        case .statAtLeast, .statAtMost: return "statThreshold"
        case .superBowlWinsAtLeast, .superBowlWinsExactly: return "rings"
        case .playedForAtLeastTeams, .playedForExactlyTeams: return "teamCount"
        case .bornInYear: return "birthYear"
        }
    }

    static func makePrompts(
        roundCount: Int,
        stats: StatsRepository?,
        minimumEligibleAnswers: Int = 5
    ) -> [Prompt] {
        let viablePool = filteredPool(using: stats, minimumEligibleAnswers: minimumEligibleAnswers)
        let count = min(max(roundCount, 4), max(1, viablePool.count))
        var rng = SystemRandomNumberGenerator()

        let noveltyPool = viablePool.filter { !isPlainTemplate($0) }
        let baselinePool = viablePool.filter(isPlainTemplate)

        var selected: [Template] = []
        var usedKeys = Set<String>()
        var bucketCounts: [String: Int] = [:]

        func key(_ t: Template) -> String { templateKey(t) }

        func canAdd(_ t: Template) -> Bool {
            guard !usedKeys.contains(key(t)) else { return false }
            let b = diversityBucket(for: t.requirement)
            let cap = maxPerDiversityBucket(b)
            return (bucketCounts[b] ?? 0) < cap
        }

        func appendIfCan(_ t: Template) -> Bool {
            guard canAdd(t) else { return false }
            selected.append(t)
            usedKeys.insert(key(t))
            let b = diversityBucket(for: t.requirement)
            bucketCounts[b, default: 0] += 1
            return true
        }

        func firstMatching(in pool: [Template], where matches: (PromptRequirement) -> Bool) -> Template? {
            pool.shuffled(using: &rng).first { matches($0.requirement) }
        }

        // Prefer one early-round and one mid/late-round draft prompt when data supports them.
        if let t = firstMatching(in: noveltyPool, where: { if case .draftedInRounds1Or2 = $0 { return true }; return false }) {
            _ = appendIfCan(t)
        }
        if selected.count < count, let t = firstMatching(in: noveltyPool, where: { if case .draftedInRounds3Through7 = $0 { return true }; return false }) {
            _ = appendIfCan(t)
        }
        if selected.count < count, let t = firstMatching(in: noveltyPool, where: { if case .attendedCollege = $0 { return true }; return false }) {
            _ = appendIfCan(t)
        }

        // Ensure every position appears once, favoring non-plain prompts.
        for position in Position.allCases.shuffled(using: &rng) {
            guard selected.count < count else { break }
            let noveltyForPos = noveltyPool.shuffled(using: &rng).filter { $0.position == position }
            let baselineForPos = baselinePool.shuffled(using: &rng).filter { $0.position == position }
            if let pick = noveltyForPos.first(where: canAdd) ?? baselineForPos.first(where: canAdd) {
                _ = appendIfCan(pick)
            }
        }

        let noveltyTarget = min(max(Int(Double(count) * 0.70), 1), count)
        var noveltyRemaining = noveltyPool.shuffled(using: &rng).filter { !usedKeys.contains(key($0)) }
        var baselineRemaining = baselinePool.shuffled(using: &rng).filter { !usedKeys.contains(key($0)) }

        while selected.count < min(noveltyTarget, count), let idx = noveltyRemaining.firstIndex(where: canAdd) {
            let pick = noveltyRemaining.remove(at: idx)
            _ = appendIfCan(pick)
        }
        while selected.count < count, let idx = noveltyRemaining.firstIndex(where: canAdd) {
            let pick = noveltyRemaining.remove(at: idx)
            _ = appendIfCan(pick)
        }
        while selected.count < count, let idx = baselineRemaining.firstIndex(where: canAdd) {
            let pick = baselineRemaining.remove(at: idx)
            _ = appendIfCan(pick)
        }

        // If caps blocked filling, relax duplicate-key only (same template twice is still wrong — relax bucket caps by refilling from full viable pool).
        if selected.count < count {
            let filler = viablePool.shuffled(using: &rng).filter { !usedKeys.contains(key($0)) }
            for t in filler where selected.count < count {
                selected.append(t)
                usedKeys.insert(key(t))
            }
        }

        selected.shuffle(using: &rng)

        return selected.prefix(count).enumerated().map { idx, t in
            Prompt(
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

    private static func filteredPool(
        using stats: StatsRepository?,
        minimumEligibleAnswers: Int
    ) -> [Template] {
        guard let stats else { return pool }
        let requiredAnswers = max(5, minimumEligibleAnswers)
        let constrained = pool.filter { !isPlainTemplate($0) }.filter { template in
            stats.eligiblePlayerCount(
                season: template.season,
                position: template.position,
                requirement: template.requirement
            ) >= max(minEligibleForConstraint, requiredAnswers)
        }
        let baseline = pool.filter(isPlainTemplate).filter { template in
            stats.eligiblePlayerCount(
                season: template.season,
                position: template.position,
                requirement: template.requirement
            ) >= requiredAnswers
        }
        let combined = constrained + baseline
        return combined.isEmpty ? pool : combined
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

        let baselineYears = [1999, 2001, 2003, 2005, 2007, 2009, 2011, 2013, 2015, 2017, 2019, 2021, 2023]

        for year in baselineYears {
            add(year, .QB, .passingYards, .any, "\(year) QB — Air yards", "Name a QB from \(year). Points = passing yards.")
            add(year, .QB, .passingTouchdowns, .any, "\(year) QB — TD race", "Name a QB from \(year). Points = 4× passing TDs.")
        }
        for year in [1999, 2003, 2007, 2011, 2015, 2019, 2023] {
            add(year, .RB, .rushingYards, .any, "\(year) RB — Ground game", "Name an RB from \(year). Points = rushing yards.")
            add(year, .RB, .rushingTouchdowns, .any, "\(year) RB — Goal line", "Name an RB from \(year). Points = 6× rushing TDs.")
            add(year, .RB, .fantasyHalfPPR, .any, "\(year) RB — All around", "Name an RB from \(year). Points = half-PPR fantasy.")
        }
        for year in [2000, 2004, 2008, 2012, 2016, 2020, 2024] {
            add(year, .WR, .receivingYards, .any, "\(year) WR — Big plays", "Name a WR from \(year). Points = receiving yards.")
            add(year, .WR, .receptions, .any, "\(year) WR — PPR style", "Name a WR from \(year). Points = 0.5× receptions.")
            add(year, .WR, .receivingTouchdowns, .any, "\(year) WR — End zone", "Name a WR from \(year). Points = 6× receiving TDs.")
        }
        for year in [2001, 2005, 2009, 2013, 2017, 2021, 2024] {
            add(year, .TE, .receivingYards, .any, "\(year) TE — Chain mover", "Name a TE from \(year). Points = receiving yards.")
            add(year, .TE, .receivingTouchdowns, .any, "\(year) TE — Red zone", "Name a TE from \(year). Points = 6× receiving TDs.")
            add(year, .TE, .receptions, .any, "\(year) TE — Volume", "Name a TE from \(year). Points = 0.5× receptions.")
        }

        let teamYears = [2008, 2012, 2016, 2020, 2024]
        let teams = ["KC", "ATL", "TB", "LAC", "BUF", "DAL", "SEA", "GB", "SF", "PIT", "NE", "PHI"]

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

        // Name-letter prompts: keep the pool small so they do not drown out college/draft; selection also caps this family at 2 per game.
        let initialLetters = ["A", "M", "R", "T"]
        for year in [2016, 2024] {
            for letter in initialLetters {
                add(year, .QB, .passingYards, .nameStartsWithLetter(letter), "\(year) QB starts with \(letter)", "Name a QB from \(year) whose name starts with \(letter). Points = passing yards.")
                add(year, .RB, .rushingYards, .nameStartsWithLetter(letter), "\(year) RB starts with \(letter)", "Name an RB from \(year) whose name starts with \(letter). Points = rushing yards.")
                add(year, .WR, .receivingYards, .nameStartsWithLetter(letter), "\(year) WR starts with \(letter)", "Name a WR from \(year) whose name starts with \(letter). Points = receiving yards.")
                add(year, .TE, .receivingTouchdowns, .nameStartsWithLetter(letter), "\(year) TE starts with \(letter)", "Name a TE from \(year) whose name starts with \(letter). Points = 6× receiving TDs.")
            }
            add(year, .QB, .passingTouchdowns, .alliterativeName, "\(year) QB alliterative name", "Name a QB from \(year) with an alliterative name. Points = 4× passing TDs.")
            add(year, .RB, .fantasyHalfPPR, .alliterativeName, "\(year) RB alliterative name", "Name an RB from \(year) with an alliterative name. Points = half-PPR fantasy.")
            add(year, .WR, .receivingYards, .alliterativeName, "\(year) WR alliterative name", "Name a WR from \(year) with an alliterative name. Points = receiving yards.")
            add(year, .TE, .receptions, .alliterativeName, "\(year) TE alliterative name", "Name a TE from \(year) with an alliterative name. Points = 0.5× receptions.")
        }

        // Over/under style categories and combo rules.
        for year in [2006, 2010, 2014, 2018, 2022, 2024] {
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

        for year in [2012, 2016, 2020, 2024] {
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

        // Championship-constraint prompts.
        for year in [2008, 2012, 2016, 2020, 2024] {
            add(year, .QB, .passingTouchdowns, .superBowlWinsExactly(0), "\(year) QB no titles", "Name a QB from \(year) who never won a championship. Points = 4× passing TDs.")
            add(year, .RB, .rushingYards, .superBowlWinsExactly(0), "\(year) RB no titles", "Name an RB from \(year) who never won a championship. Points = rushing yards.")
            add(year, .WR, .receivingYards, .superBowlWinsExactly(0), "\(year) WR no titles", "Name a WR from \(year) who never won a championship. Points = receiving yards.")
            add(year, .TE, .receivingTouchdowns, .superBowlWinsExactly(0), "\(year) TE no titles", "Name a TE from \(year) who never won a championship. Points = 6× receiving TDs.")
            add(year, .QB, .passingYards, .superBowlWinsAtLeast(2), "\(year) QB 2+ rings", "Name a QB from \(year) with 2+ Super Bowl wins. Points = passing yards.")
            add(year, .RB, .fantasyHalfPPR, .superBowlWinsAtLeast(2), "\(year) RB 2+ rings", "Name an RB from \(year) with 2+ Super Bowl wins. Points = half-PPR fantasy.")
            add(year, .WR, .receivingTouchdowns, .superBowlWinsAtLeast(2), "\(year) WR 2+ rings", "Name a WR from \(year) with 2+ Super Bowl wins. Points = 6× receiving TDs.")
            add(year, .TE, .receivingYards, .superBowlWinsAtLeast(2), "\(year) TE 2+ rings", "Name a TE from \(year) with 2+ Super Bowl wins. Points = receiving yards.")
        }

        // College prompts — wording matches user-facing “attended {school}”.
        let colleges = [
            "Alabama", "Georgia", "LSU", "Ohio State", "Michigan", "USC", "Clemson", "Notre Dame",
            "Oklahoma", "Texas", "Penn State", "Florida", "Oregon", "Wisconsin", "Iowa",
            "Miami", "UCLA", "Stanford", "Tennessee", "Nebraska", "Auburn", "TCU", "Washington",
            "Ole Miss", "Mississippi State", "South Carolina", "Arkansas", "Kentucky", "NC State",
            "Utah", "Arizona State", "Baylor", "West Virginia", "Pittsburgh", "Duke", "North Carolina",
            "Virginia Tech", "Louisville", "Texas A&M", "California", "Colorado", "Minnesota",
            "Syracuse", "Boston College", "Cincinnati", "Houston", "SMU", "Wake Forest"
        ]
        for year in [2008, 2012, 2016, 2020, 2024] {
            for college in colleges {
                add(year, .QB, .passingYards, .attendedCollege(college), "\(year) QB from \(college)", "Name a QB from \(year) who attended \(college). Points = passing yards.")
                add(year, .RB, .rushingYards, .attendedCollege(college), "\(year) RB from \(college)", "Name an RB from \(year) who attended \(college). Points = rushing yards.")
                add(year, .WR, .receivingYards, .attendedCollege(college), "\(year) WR from \(college)", "Name a WR from \(year) who attended \(college). Points = receiving yards.")
                add(year, .TE, .receivingTouchdowns, .attendedCollege(college), "\(year) TE from \(college)", "Name a TE from \(year) who attended \(college). Points = 6× receiving TDs.")
            }
        }

        // Team-count prompts.
        for year in [2008, 2012, 2016, 2020, 2024] {
            for teamCount in [2, 3, 4, 5] {
                add(year, .QB, .passingTouchdowns, .playedForAtLeastTeams(teamCount), "\(year) QB played for \(teamCount)+ teams", "Name a QB from \(year) who played for at least \(teamCount) teams. Points = 4× passing TDs.")
                add(year, .RB, .fantasyHalfPPR, .playedForAtLeastTeams(teamCount), "\(year) RB played for \(teamCount)+ teams", "Name an RB from \(year) who played for at least \(teamCount) teams. Points = half-PPR fantasy.")
                add(year, .WR, .receivingYards, .playedForAtLeastTeams(teamCount), "\(year) WR played for \(teamCount)+ teams", "Name a WR from \(year) who played for at least \(teamCount) teams. Points = receiving yards.")
                add(year, .TE, .receptions, .playedForAtLeastTeams(teamCount), "\(year) TE played for \(teamCount)+ teams", "Name a TE from \(year) who played for at least \(teamCount) teams. Points = 0.5× receptions.")
            }
            for exactCount in [1, 2, 3] {
                add(year, .QB, .passingYards, .playedForExactlyTeams(exactCount), "\(year) QB exactly \(exactCount) teams", "Name a QB from \(year) who played for exactly \(exactCount) teams. Points = passing yards.")
                add(year, .WR, .receivingTouchdowns, .playedForExactlyTeams(exactCount), "\(year) WR exactly \(exactCount) teams", "Name a WR from \(year) who played for exactly \(exactCount) teams. Points = 6× receiving TDs.")
            }
        }

        // Draft-oriented prompts. Season is where scoring comes from; draft filter checks career metadata.
        let draftSeasons = [2008, 2012, 2016, 2020, 2024]
        for season in draftSeasons {
            add(season, .QB, .passingYards, .draftedInRounds1Or2, "\(season) QB — rounds 1–2 pick", "Name a QB from \(season) who was drafted in round 1 or 2. Points = passing yards.")
            add(season, .RB, .rushingYards, .draftedInRounds1Or2, "\(season) RB — rounds 1–2 pick", "Name an RB from \(season) who was drafted in round 1 or 2. Points = rushing yards.")
            add(season, .WR, .receivingYards, .draftedInRounds1Or2, "\(season) WR — rounds 1–2 pick", "Name a WR from \(season) who was drafted in round 1 or 2. Points = receiving yards.")
            add(season, .TE, .receivingTouchdowns, .draftedInRounds1Or2, "\(season) TE — rounds 1–2 pick", "Name a TE from \(season) who was drafted in round 1 or 2. Points = 6× receiving TDs.")

            add(season, .QB, .passingTouchdowns, .draftedInRounds3Through7, "\(season) QB — rounds 3–7 pick", "Name a QB from \(season) who was drafted in rounds 3–7. Points = 4× passing TDs.")
            add(season, .RB, .fantasyHalfPPR, .draftedInRounds3Through7, "\(season) RB — rounds 3–7 pick", "Name an RB from \(season) who was drafted in rounds 3–7. Points = half-PPR fantasy.")
            add(season, .WR, .receivingTouchdowns, .draftedInRounds3Through7, "\(season) WR — rounds 3–7 pick", "Name a WR from \(season) who was drafted in rounds 3–7. Points = 6× receiving TDs.")
            add(season, .TE, .receptions, .draftedInRounds3Through7, "\(season) TE — rounds 3–7 pick", "Name a TE from \(season) who was drafted in rounds 3–7. Points = 0.5× receptions.")
        }

        for season in draftSeasons {
            for draftYear in stride(from: 1976, through: 2020, by: 8) {
                add(season, .QB, .passingYards, .draftedInYear(draftYear), "\(season) QB drafted in \(draftYear)", "Name a QB from \(season) who was drafted in \(draftYear). Points = passing yards.")
                add(season, .RB, .rushingYards, .draftedInYear(draftYear), "\(season) RB drafted in \(draftYear)", "Name an RB from \(season) who was drafted in \(draftYear). Points = rushing yards.")
                add(season, .WR, .receivingYards, .draftedInYear(draftYear), "\(season) WR drafted in \(draftYear)", "Name a WR from \(season) who was drafted in \(draftYear). Points = receiving yards.")
                add(season, .TE, .receivingYards, .draftedInYear(draftYear), "\(season) TE drafted in \(draftYear)", "Name a TE from \(season) who was drafted in \(draftYear). Points = receiving yards.")
            }
            for round in [1, 2, 3, 4, 5] {
                add(season, .QB, .passingTouchdowns, .draftedInRound(round), "\(season) QB round \(round) pick", "Name a QB from \(season) drafted in round \(round). Points = 4× passing TDs.")
                add(season, .RB, .fantasyHalfPPR, .draftedInRound(round), "\(season) RB round \(round) pick", "Name an RB from \(season) drafted in round \(round). Points = half-PPR fantasy.")
                add(season, .WR, .receivingTouchdowns, .draftedInRound(round), "\(season) WR round \(round) pick", "Name a WR from \(season) drafted in round \(round). Points = 6× receiving TDs.")
                add(season, .TE, .receptions, .draftedInRound(round), "\(season) TE round \(round) pick", "Name a TE from \(season) drafted in round \(round). Points = 0.5× receptions.")
            }
            add(season, .QB, .passingTouchdowns, .draftedAfterRound(2), "\(season) QB drafted after round 2", "Name a QB from \(season) drafted after round 2. Points = 4× passing TDs.")
            add(season, .RB, .fantasyHalfPPR, .draftedAfterRound(2), "\(season) RB drafted after round 2", "Name an RB from \(season) drafted after round 2. Points = half-PPR fantasy.")
            add(season, .WR, .receivingYards, .draftedAfterRound(2), "\(season) WR drafted after round 2", "Name a WR from \(season) drafted after round 2. Points = receiving yards.")
            add(season, .TE, .receivingYards, .draftedAfterRound(2), "\(season) TE drafted after round 2", "Name a TE from \(season) drafted after round 2. Points = receiving yards.")
            add(season, .QB, .passingYards, .draftedAtPickAtMost(32), "\(season) QB first-rounder", "Name a QB from \(season) drafted in the first round (pick 1-32). Points = passing yards.")
            add(season, .RB, .rushingYards, .draftedAtPickAtMost(32), "\(season) RB first-rounder", "Name an RB from \(season) drafted in the first round (pick 1-32). Points = rushing yards.")
            add(season, .WR, .receivingYards, .draftedAtPickAtMost(32), "\(season) WR first-rounder", "Name a WR from \(season) drafted in the first round (pick 1-32). Points = receiving yards.")
            add(season, .TE, .receivingYards, .draftedAtPickAtMost(32), "\(season) TE first-rounder", "Name a TE from \(season) drafted in the first round (pick 1-32). Points = receiving yards.")
            add(season, .WR, .receivingTouchdowns, .draftedAtPickRange(33, 96), "\(season) WR day-2 pick", "Name a WR from \(season) drafted on day 2 (pick 33-96). Points = 6× receiving TDs.")
            add(season, .RB, .fantasyHalfPPR, .draftedAtPickRange(97, 224), "\(season) RB day-3 pick", "Name an RB from \(season) drafted on day 3 (pick 97-224). Points = half-PPR fantasy.")
        }

        return templates
    }
}
