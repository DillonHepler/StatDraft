import Foundation

/// Per-season counting stats used for scoring (demo data; expand for production API).
struct SeasonStatLine: Codable, Equatable {
    var position: Position
    var games: Int
    var passingYards: Int
    var passingTD: Int
    var interceptions: Int
    var rushingYards: Int
    var rushingTD: Int
    var receptions: Int
    var receivingYards: Int
    var receivingTD: Int
}

struct PlayerRecord: Codable, Identifiable, Equatable {
    let id: String
    let displayName: String
    let aliases: [String]
    /// Key is season year as string e.g. "2007"
    var seasons: [String: SeasonStatLine]

    func line(for season: Int) -> SeasonStatLine? {
        seasons[String(season)]
    }

    func matches(query: String) -> Bool {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return false }
        if displayName.lowercased() == q { return true }
        if aliases.contains(where: { $0.lowercased() == q }) { return true }
        return false
    }
}

struct StatsDatabase: Codable {
    let players: [PlayerRecord]
}
