import Foundation

/// Builds a fixed-length prompt list for a draft (curated templates + shuffled variety).
enum PromptFactory {
    private struct Template {
        let season: Int
        let position: Position
        let scoring: ScoringRule
        let title: String
        let detail: String
    }

    private static let pool: [Template] = [
        Template(
            season: 2007,
            position: .QB,
            scoring: .passingYards,
            title: "2007 QB — Air show",
            detail: "Name a QB who played in 2007. Points = passing yards that season."
        ),
        Template(
            season: 2011,
            position: .QB,
            scoring: .passingTouchdowns,
            title: "2011 QB — Touchdown factory",
            detail: "Name a QB from 2011. Points = 4× passing TDs."
        ),
        Template(
            season: 2006,
            position: .RB,
            scoring: .rushingYards,
            title: "2006 RB — Ground game",
            detail: "Name an RB from 2006. Points = rushing yards."
        ),
        Template(
            season: 2012,
            position: .RB,
            scoring: .fantasyHalfPPR,
            title: "2012 RB — Half-PPR monster",
            detail: "Name an RB from 2012. Points = half-PPR fantasy using combined stats."
        ),
        Template(
            season: 2014,
            position: .WR,
            scoring: .receivingYards,
            title: "2014 WR — Downfield",
            detail: "Name a WR from 2014. Points = receiving yards."
        ),
        Template(
            season: 2018,
            position: .WR,
            scoring: .receptions,
            title: "2018 WR — PPR lean",
            detail: "Name a WR from 2018. Points = 0.5× receptions."
        ),
        Template(
            season: 2013,
            position: .TE,
            scoring: .receivingTouchdowns,
            title: "2013 TE — Red zone",
            detail: "Name a TE from 2013. Points = 6× receiving TDs."
        ),
        Template(
            season: 2009,
            position: .QB,
            scoring: .fantasyHalfPPR,
            title: "2009 QB — Scramble & sling",
            detail: "Name a QB from 2009. Points = half-PPR fantasy from all QB stats."
        ),
        Template(
            season: 2015,
            position: .RB,
            scoring: .rushingTouchdowns,
            title: "2015 RB — Goal line",
            detail: "Name an RB from 2015. Points = 6× rushing TDs."
        ),
        Template(
            season: 2010,
            position: .WR,
            scoring: .receivingTouchdowns,
            title: "2010 WR — End zone",
            detail: "Name a WR from 2010. Points = 6× receiving TDs."
        ),
        Template(
            season: 2016,
            position: .TE,
            scoring: .receivingYards,
            title: "2016 TE — Move the chains",
            detail: "Name a TE from 2016. Points = receiving yards."
        ),
        Template(
            season: 2008,
            position: .QB,
            scoring: .passingYards,
            title: "2008 QB — Pure volume",
            detail: "Name a QB from 2008. Points = passing yards."
        ),
        Template(
            season: 2017,
            position: .RB,
            scoring: .rushingYards,
            title: "2017 RB — Workhorse",
            detail: "Name an RB from 2017. Points = rushing yards."
        ),
        Template(
            season: 2019,
            position: .WR,
            scoring: .fantasyHalfPPR,
            title: "2019 WR — Total package",
            detail: "Name a WR from 2019. Points = half-PPR fantasy from WR stats."
        ),
        Template(
            season: 2005,
            position: .QB,
            scoring: .passingTouchdowns,
            title: "2005 QB — Scoring",
            detail: "Name a QB from 2005. Points = 4× passing TDs."
        ),
        Template(
            season: 2020,
            position: .RB,
            scoring: .fantasyHalfPPR,
            title: "2020 RB — Weird year, real points",
            detail: "Name an RB from 2020. Points = half-PPR fantasy."
        ),
    ]

    static func makePrompts(roundCount: Int) -> [Prompt] {
        let count = min(max(roundCount, 4), min(16, pool.count))
        let shuffled = pool.shuffled()
        return (0..<count).map { idx in
            let t = shuffled[idx % shuffled.count]
            return Prompt(
                roundIndex: idx,
                season: t.season,
                position: t.position,
                scoringRule: t.scoring,
                title: t.title,
                detail: t.detail
            )
        }
    }
}
