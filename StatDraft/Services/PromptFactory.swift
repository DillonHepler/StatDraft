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
        var selected: [Template] = []

        // Ensure baseline variety (including TE) so drafts don't miss positions.
        for position in Position.allCases {
            if let pick = pool.filter({ $0.position == position }).randomElement(using: &rng) {
                selected.append(pick)
            }
        }

        let existingKeys = Set(selected.map(templateKey))
        let remaining = pool.shuffled().filter { !existingKeys.contains(templateKey($0)) }
        let needed = max(0, count - selected.count)
        selected.append(contentsOf: remaining.prefix(needed))
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

        let baselineYears = [2005, 2006, 2007, 2008, 2009, 2010, 2011, 2012, 2013, 2014, 2015, 2016, 2017, 2018, 2019, 2020]

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

        // Team-based prompts using any-career affiliation to avoid one-player traps.
        add(2018, .QB, .passingTouchdowns, .playedForTeamAnyCareer("KC"), "2018 QB with Chiefs history", "Name a QB from 2018 who played for KC at any point in their career. Points = 4× passing TDs.")
        add(2016, .QB, .fantasyHalfPPR, .playedForTeamAnyCareer("ATL"), "2016 QB with Falcons history", "Name a QB from 2016 who played for ATL at any point in their career. Points = half-PPR fantasy.")
        add(2019, .WR, .receivingYards, .playedForTeamAnyCareer("TB"), "2019 WR with Bucs history", "Name a WR from 2019 who played for TB at any point in their career. Points = receiving yards.")
        add(2020, .TE, .receivingTouchdowns, .playedForTeamAnyCareer("KC"), "2020 TE with Chiefs history", "Name a TE from 2020 who played for KC at any point in their career. Points = 6× receiving TDs.")
        add(2017, .RB, .rushingTouchdowns, .playedForTeamAnyCareer("LA"), "2017 RB with Rams history", "Name an RB from 2017 who played for LA at any point in their career. Points = 6× rushing TDs.")

        // Birth-year novelty prompts.
        add(2020, .WR, .receptions, .bornInYear(1999), "2020 WR born in 1999", "Name a WR from 2020 born in 1999. Points = 0.5× receptions.")
        add(2020, .RB, .fantasyHalfPPR, .bornInYear(1995), "2020 RB born in 1995", "Name an RB from 2020 born in 1995. Points = half-PPR fantasy.")
        add(2019, .QB, .passingYards, .bornInYear(1995), "2019 QB born in 1995", "Name a QB from 2019 born in 1995. Points = passing yards.")
        add(2018, .TE, .receptions, .bornInYear(1989), "2018 TE born in 1989", "Name a TE from 2018 born in 1989. Points = 0.5× receptions.")

        // Over/under style categories for extra uniqueness.
        add(2018, .QB, .passingYards, .statAtLeast(.passingYards, 4000), "2018 QB 4k club", "Name a QB from 2018 with at least 4,000 passing yards. Points = passing yards.")
        add(2019, .QB, .passingTouchdowns, .statAtMost(.interceptions, 10), "2019 QB careful passer", "Name a QB from 2019 with 10 or fewer interceptions. Points = 4× passing TDs.")
        add(2017, .RB, .rushingYards, .statAtLeast(.rushingYards, 1000), "2017 RB 1k rusher", "Name an RB from 2017 with at least 1,000 rushing yards. Points = rushing yards.")
        add(2020, .RB, .fantasyHalfPPR, .statAtLeast(.receptions, 45), "2020 RB pass-game role", "Name an RB from 2020 with at least 45 receptions. Points = half-PPR fantasy.")
        add(2019, .WR, .receivingYards, .statAtLeast(.receivingYards, 1000), "2019 WR 1k season", "Name a WR from 2019 with at least 1,000 receiving yards. Points = receiving yards.")
        add(2018, .WR, .receivingTouchdowns, .statAtLeast(.receivingTouchdowns, 8), "2018 WR touchdown threat", "Name a WR from 2018 with at least 8 receiving TDs. Points = 6× receiving TDs.")
        add(2020, .TE, .receivingYards, .statAtLeast(.receivingYards, 600), "2020 TE 600+ yards", "Name a TE from 2020 with at least 600 receiving yards. Points = receiving yards.")
        add(2016, .TE, .receivingTouchdowns, .statAtMost(.receivingTouchdowns, 5), "2016 TE under-6 TD", "Name a TE from 2016 with 5 or fewer receiving TDs. Points = 6× receiving TDs.")

        return templates
    }
}
