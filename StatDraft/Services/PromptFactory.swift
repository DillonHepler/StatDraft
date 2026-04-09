import Foundation

/// Builds a fixed-length prompt list for a draft (curated templates + shuffled variety).
enum PromptFactory {
    private struct Template {
        let season: Int
        let position: Position
        let scoring: ScoringRule
        let requirement: PromptRequirement
        let title: String
        let detail: String
    }

    private static let pool: [Template] = [
        Template(
            season: 2007,
            position: .QB,
            scoring: .passingYards,
            requirement: .any,
            title: "2007 QB — Air show",
            detail: "Name a QB who played in 2007. Points = passing yards that season."
        ),
        Template(
            season: 2011,
            position: .QB,
            scoring: .passingTouchdowns,
            requirement: .any,
            title: "2011 QB — Touchdown factory",
            detail: "Name a QB from 2011. Points = 4× passing TDs."
        ),
        Template(
            season: 2016,
            position: .QB,
            scoring: .fantasyHalfPPR,
            requirement: .playedForTeam("ATL"),
            title: "Falcons QB special",
            detail: "Name a QB from 2016 who played for ATL. Points = half-PPR fantasy."
        ),
        Template(
            season: 2018,
            position: .QB,
            scoring: .passingTouchdowns,
            requirement: .playedForTeam("KC"),
            title: "Chiefs QB — Big plays",
            detail: "Name a QB from 2018 who played for KC. Points = 4× passing TDs."
        ),
        Template(
            season: 2019,
            position: .QB,
            scoring: .passingYards,
            requirement: .bornInYear(1995),
            title: "2019 QB born in 1995",
            detail: "Name a QB from 2019 born in 1995. Points = passing yards."
        ),
        Template(
            season: 2006,
            position: .RB,
            scoring: .rushingYards,
            requirement: .any,
            title: "2006 RB — Ground game",
            detail: "Name an RB from 2006. Points = rushing yards."
        ),
        Template(
            season: 2012,
            position: .RB,
            scoring: .fantasyHalfPPR,
            requirement: .any,
            title: "2012 RB — Half-PPR monster",
            detail: "Name an RB from 2012. Points = half-PPR fantasy using combined stats."
        ),
        Template(
            season: 2017,
            position: .RB,
            scoring: .rushingTouchdowns,
            requirement: .playedForTeam("LA"),
            title: "Rams RB — End zone",
            detail: "Name an RB from 2017 who played for LA. Points = 6× rushing TDs."
        ),
        Template(
            season: 2020,
            position: .RB,
            scoring: .fantasyHalfPPR,
            requirement: .bornInYear(1995),
            title: "2020 RB born in 1995",
            detail: "Name an RB from 2020 born in 1995. Points = half-PPR fantasy."
        ),
        Template(
            season: 2014,
            position: .WR,
            scoring: .receivingYards,
            requirement: .any,
            title: "2014 WR — Downfield",
            detail: "Name a WR from 2014. Points = receiving yards."
        ),
        Template(
            season: 2018,
            position: .WR,
            scoring: .receptions,
            requirement: .any,
            title: "2018 WR — PPR lean",
            detail: "Name a WR from 2018. Points = 0.5× receptions."
        ),
        Template(
            season: 2020,
            position: .WR,
            scoring: .receptions,
            requirement: .bornInYear(1999),
            title: "2020 WR born in 1999",
            detail: "Name a WR from 2020 born in 1999. Points = 0.5× receptions."
        ),
        Template(
            season: 2019,
            position: .WR,
            scoring: .receivingYards,
            requirement: .playedForTeam("TB"),
            title: "Bucs WR — Chunk gains",
            detail: "Name a WR from 2019 who played for TB. Points = receiving yards."
        ),
        Template(
            season: 2013,
            position: .TE,
            scoring: .receivingTouchdowns,
            requirement: .any,
            title: "2013 TE — Red zone",
            detail: "Name a TE from 2013. Points = 6× receiving TDs."
        ),
        Template(
            season: 2016,
            position: .TE,
            scoring: .receivingYards,
            requirement: .any,
            title: "2016 TE — Move the chains",
            detail: "Name a TE from 2016. Points = receiving yards."
        ),
        Template(
            season: 2019,
            position: .TE,
            scoring: .fantasyHalfPPR,
            requirement: .any,
            title: "2019 TE — Full profile",
            detail: "Name a TE from 2019. Points = half-PPR fantasy."
        ),
        Template(
            season: 2020,
            position: .TE,
            scoring: .receivingTouchdowns,
            requirement: .playedForTeam("KC"),
            title: "Chiefs TE — Red zone",
            detail: "Name a TE from 2020 who played for KC. Points = 6× receiving TDs."
        ),
        Template(
            season: 2018,
            position: .TE,
            scoring: .receptions,
            requirement: .bornInYear(1989),
            title: "2018 TE born in 1989",
            detail: "Name a TE from 2018 born in 1989. Points = 0.5× receptions."
        ),
        Template(
            season: 2009,
            position: .QB,
            scoring: .fantasyHalfPPR,
            requirement: .any,
            title: "2009 QB — Scramble & sling",
            detail: "Name a QB from 2009. Points = half-PPR fantasy from all QB stats."
        ),
        Template(
            season: 2015,
            position: .RB,
            scoring: .rushingTouchdowns,
            requirement: .any,
            title: "2015 RB — Goal line",
            detail: "Name an RB from 2015. Points = 6× rushing TDs."
        ),
        Template(
            season: 2010,
            position: .WR,
            scoring: .receivingTouchdowns,
            requirement: .any,
            title: "2010 WR — End zone",
            detail: "Name a WR from 2010. Points = 6× receiving TDs."
        ),
        Template(
            season: 2008,
            position: .QB,
            scoring: .passingYards,
            requirement: .any,
            title: "2008 QB — Pure volume",
            detail: "Name a QB from 2008. Points = passing yards."
        ),
        Template(
            season: 2017,
            position: .RB,
            scoring: .rushingYards,
            requirement: .any,
            title: "2017 RB — Workhorse",
            detail: "Name an RB from 2017. Points = rushing yards."
        ),
        Template(
            season: 2019,
            position: .WR,
            scoring: .fantasyHalfPPR,
            requirement: .any,
            title: "2019 WR — Total package",
            detail: "Name a WR from 2019. Points = half-PPR fantasy from WR stats."
        ),
        Template(
            season: 2005,
            position: .QB,
            scoring: .passingTouchdowns,
            requirement: .any,
            title: "2005 QB — Scoring",
            detail: "Name a QB from 2005. Points = 4× passing TDs."
        ),
        Template(
            season: 2020,
            position: .RB,
            scoring: .fantasyHalfPPR,
            requirement: .any,
            title: "2020 RB — Weird year, real points",
            detail: "Name an RB from 2020. Points = half-PPR fantasy."
        ),
    ]

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
}
