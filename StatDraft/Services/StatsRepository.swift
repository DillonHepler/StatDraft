import Foundation

enum StatsError: LocalizedError {
    case notFound
    case unavailable(String)
    case wrongPosition(expected: Position, actual: Position)
    case noStatsForSeason(Int)

    var errorDescription: String? {
        switch self {
        case .notFound:
            return "No player matched that name in our database."
        case .unavailable(let message):
            return message
        case .wrongPosition(let expected, let actual):
            return "That player was a \(actual.rawValue) in that season; this round needs a \(expected.rawValue)."
        case .noStatsForSeason(let year):
            return "No stats for that player in \(year)."
        }
    }
}

final class StatsRepository {
    let loadError: String?
    private let playersById: [String: PlayerRecord]
    private let allPlayers: [PlayerRecord]

    init(bundle: Bundle = .main) {
        let url = bundle.url(forResource: "demo_stats", withExtension: "json")
        let data: Data
        var resolvedLoadError: String?
        if let url {
            do {
                data = try Data(contentsOf: url)
            } catch {
                data = Data()
                resolvedLoadError = "Could not read bundled stats file."
            }
        } else {
            data = Data()
            resolvedLoadError = "Bundled stats file was not found."
        }
        let decoded: StatsDatabase
        do {
            decoded = try JSONDecoder().decode(StatsDatabase.self, from: data)
        } catch {
            decoded = StatsDatabase(players: [])
            if resolvedLoadError == nil {
                resolvedLoadError = "Bundled stats file failed to decode."
            }
        }
        self.allPlayers = decoded.players
        self.playersById = Dictionary(uniqueKeysWithValues: decoded.players.map { ($0.id, $0) })
        if decoded.players.isEmpty && resolvedLoadError == nil {
            resolvedLoadError = "The bundled stats database is empty."
        }
        self.loadError = resolvedLoadError
    }

    func resolvePick(
        rawName: String,
        season: Int,
        requiredPosition: Position
    ) -> Result<(PlayerRecord, SeasonStatLine), StatsError> {
        if let loadError {
            return .failure(.unavailable(loadError))
        }
        let trimmed = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .failure(.notFound) }

        guard let player = resolvePlayer(from: trimmed, season: season, requiredPosition: requiredPosition) else {
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

    func eligiblePlayerCount(season: Int, position: Position, requirement: PromptRequirement) -> Int {
        allPlayers.reduce(into: 0) { count, player in
            guard let line = player.line(for: season), line.position == position else { return }
            if requirement.isSatisfied(player: player, line: line) {
                count += 1
            }
        }
    }

    private func resolvePlayer(from rawQuery: String, season: Int, requiredPosition: Position) -> PlayerRecord? {
        let query = normalized(rawQuery)
        if query.isEmpty { return nil }

        let exactMatches = allPlayers.filter { normalized($0.displayName) == query }
        if let exact = bestCandidate(from: exactMatches, season: season, requiredPosition: requiredPosition) {
            return exact
        }
        let aliasMatches = allPlayers.filter { $0.aliases.contains(where: { normalized($0) == query }) }
        if let aliasMatch = bestCandidate(from: aliasMatches, season: season, requiredPosition: requiredPosition) {
            return aliasMatch
        }

        // Fuzzy fallback for common inputs like punctuation/spacing variants.
        let fuzzyMatches = allPlayers.filter { player in
            normalized(player.displayName).contains(query)
                || query.contains(normalized(player.displayName))
                || player.aliases.contains(where: {
                    let alias = normalized($0)
                    return alias.contains(query) || query.contains(alias)
                })
        }
        return bestCandidate(from: fuzzyMatches, season: season, requiredPosition: requiredPosition)
    }

    private func bestCandidate(from candidates: [PlayerRecord], season: Int, requiredPosition: Position) -> PlayerRecord? {
        if candidates.isEmpty { return nil }
        if let seasonAndPosition = candidates.first(where: { player in
            guard let line = player.line(for: season) else { return false }
            return line.position == requiredPosition
        }) {
            return seasonAndPosition
        }
        if let hasSeason = candidates.first(where: { $0.line(for: season) != nil }) {
            return hasSeason
        }
        return candidates.first
    }

    private func normalized(_ value: String) -> String {
        let lowered = value.lowercased()
        let folded = lowered.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        let cleaned = folded.replacingOccurrences(of: "[^a-z0-9]+", with: " ", options: .regularExpression)
        return cleaned.split(separator: " ").joined(separator: " ")
    }
}
