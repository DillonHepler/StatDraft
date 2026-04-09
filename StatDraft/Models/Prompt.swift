import Foundation

/// How we turn a season stat line into a single round score.
enum ScoringRule: String, Codable, CaseIterable, Identifiable {
    case passingYards
    case passingTouchdowns
    case rushingYards
    case rushingTouchdowns
    case receptions
    case receivingYards
    case receivingTouchdowns
    case fantasyHalfPPR

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .passingYards: return "Passing yards"
        case .passingTouchdowns: return "Passing TDs"
        case .rushingYards: return "Rushing yards"
        case .rushingTouchdowns: return "Rushing TDs"
        case .receptions: return "Receptions"
        case .receivingYards: return "Receiving yards"
        case .receivingTouchdowns: return "Receiving TDs"
        case .fantasyHalfPPR: return "Half-PPR fantasy points"
        }
    }

    func points(for line: SeasonStatLine) -> Double {
        switch self {
        case .passingYards: return Double(line.passingYards)
        case .passingTouchdowns: return Double(line.passingTD) * 4
        case .rushingYards: return Double(line.rushingYards)
        case .rushingTouchdowns: return Double(line.rushingTD) * 6
        case .receptions: return Double(line.receptions) * 0.5
        case .receivingYards: return Double(line.receivingYards)
        case .receivingTouchdowns: return Double(line.receivingTD) * 6
        case .fantasyHalfPPR:
            return Double(line.passingTD) * 4
                + Double(line.rushingTD + line.receivingTD) * 6
                + Double(line.passingYards) / 25
                + Double(line.rushingYards + line.receivingYards) / 10
                + Double(line.receptions) * 0.5
                - Double(line.interceptions) * 2
        }
    }
}

struct Prompt: Identifiable, Codable, Equatable {
    let id: UUID
    let roundIndex: Int
    let season: Int
    let position: Position
    let scoringRule: ScoringRule
    let requirement: PromptRequirement
    let title: String
    let detail: String

    init(
        id: UUID = UUID(),
        roundIndex: Int,
        season: Int,
        position: Position,
        scoringRule: ScoringRule,
        requirement: PromptRequirement = .any,
        title: String,
        detail: String
    ) {
        self.id = id
        self.roundIndex = roundIndex
        self.season = season
        self.position = position
        self.scoringRule = scoringRule
        self.requirement = requirement
        self.title = title
        self.detail = detail
    }
}

enum PromptRequirement: Codable, Equatable {
    case any
    case playedForTeam(String)
    case bornInYear(Int)

    func isSatisfied(player: PlayerRecord, line: SeasonStatLine) -> Bool {
        switch self {
        case .any:
            return true
        case .playedForTeam(let team):
            return line.team?.caseInsensitiveCompare(team) == .orderedSame
        case .bornInYear(let year):
            return player.birthYear == year
        }
    }

    var failureMessage: String {
        switch self {
        case .any:
            return "That pick does not match this round's rule."
        case .playedForTeam(let team):
            return "That player did not play for \(team) in that season."
        case .bornInYear(let year):
            return "That player was not born in \(year)."
        }
    }
}

enum Position: String, Codable, CaseIterable, Identifiable {
    case QB
    case RB
    case WR
    case TE

    var id: String { rawValue }
}
