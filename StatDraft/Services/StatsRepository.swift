import Foundation

enum StatsError: LocalizedError {
    case notFound
    case wrongPosition(expected: Position, actual: Position)
    case noStatsForSeason(Int)

    var errorDescription: String? {
        switch self {
        case .notFound:
            return "No player matched that name in our database."
        case .wrongPosition(let expected, let actual):
            return "That player was a \(actual.rawValue) in that season; this round needs a \(expected.rawValue)."
        case .noStatsForSeason(let year):
            return "No stats for that player in \(year)."
        }
    }
}

final class StatsRepository {
    private let playersById: [String: PlayerRecord]
    private let allPlayers: [PlayerRecord]

    init(bundle: Bundle = .main) {
        let url = bundle.url(forResource: "demo_stats", withExtension: "json")
        let data: Data
        if let url {
            data = (try? Data(contentsOf: url)) ?? Data()
        } else {
            data = Data()
        }
        let decoded = (try? JSONDecoder().decode(StatsDatabase.self, from: data)) ?? StatsDatabase(players: [])
        self.allPlayers = decoded.players
        self.playersById = Dictionary(uniqueKeysWithValues: decoded.players.map { ($0.id, $0) })
    }

    func resolvePick(
        rawName: String,
        season: Int,
        requiredPosition: Position
    ) -> Result<(PlayerRecord, SeasonStatLine), StatsError> {
        let trimmed = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .failure(.notFound) }

        guard let player = allPlayers.first(where: { $0.matches(query: trimmed) }) else {
            return .failure(.notFound)
        }

        guard let line = player.line(for: season) else {
            return .failure(.noStatsForSeason(season))
        }

        guard line.position == requiredPosition else {
            return .failure(.wrongPosition(expected: requiredPosition, actual: line.position))
        }

        return .success((player, line))
    }

    func player(id: String) -> PlayerRecord? {
        playersById[id]
    }
}
