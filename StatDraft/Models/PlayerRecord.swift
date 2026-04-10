import Foundation

/// Per-season counting stats used for scoring (demo data; expand for production API).
struct SeasonStatLine: Codable, Equatable {
    var position: Position
    var team: String?
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
    let birthYear: Int?
    let draftYear: Int?
    let draftRound: Int?
    let draftPick: Int?
    let superBowlWins: Int?
    let collegeName: String?
    let careerTeams: [String]?
    /// Key is season year as string e.g. "2007"
    var seasons: [String: SeasonStatLine]

    func line(for season: Int) -> SeasonStatLine? {
        seasons[String(season)]
    }

    func playedForTeamInCareer(_ team: String) -> Bool {
        if let careerTeams, !careerTeams.isEmpty {
            return careerTeams.contains { $0.caseInsensitiveCompare(team) == .orderedSame }
        }
        return seasons.values.contains { line in
            line.team?.caseInsensitiveCompare(team) == .orderedSame
        }
    }

    var distinctTeamCount: Int {
        if let careerTeams, !careerTeams.isEmpty {
            return Set(careerTeams.map { $0.uppercased() }).count
        }
        return Set(seasons.values.compactMap(\.team).map { $0.uppercased() }).count
    }

    func startsWith(letter: String) -> Bool {
        let trimmed = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let first = trimmed.first else { return false }
        return String(first).caseInsensitiveCompare(letter) == .orderedSame
    }

    /// Normalizes school strings so prompt labels like "Ohio State" match data like "Ohio State University".
    static func normalizedCollegeToken(_ raw: String) -> String {
        var s = raw.lowercased()
        s = s.replacingOccurrences(of: "’", with: "'")
        s = s.replacingOccurrences(of: "^the\\s+", with: "", options: .regularExpression)
        s = s.replacingOccurrences(of: "\\s+university$", with: "", options: .regularExpression)
        s = s.replacingOccurrences(of: "\\s+college$", with: "", options: .regularExpression)
        s = s.trimmingCharacters(in: .whitespacesAndNewlines)
        return s
    }

    /// True if the player's `collegeName` matches the prompt fragment (abbreviation or full name).
    /// Supports nflverse-style multi-school strings separated by "; ".
    func attendedCollegeMatching(_ query: String) -> Bool {
        guard let raw = collegeName?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
            return false
        }
        let segments = raw.split(separator: ";").map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        for seg in segments {
            if Self.collegeTokensMatch(segment: seg, query: query) { return true }
        }
        return Self.collegeTokensMatch(segment: raw, query: query)
    }

    private static func collegeTokensMatch(segment: String, query: String) -> Bool {
        let a = normalizedCollegeToken(segment)
        let b = normalizedCollegeToken(query)
        if a == b { return true }
        if a.count < 2 || b.count < 2 { return false }
        if a.contains(b) || b.contains(a) { return true }
        // nflverse often stores "Mississippi" for Ole Miss.
        let oleMiss = (a == "mississippi" && b == "ole miss") || (b == "mississippi" && a == "ole miss")
        return oleMiss
    }

    var isAlliterativeName: Bool {
        let components = displayName
            .split(separator: " ")
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard components.count >= 2,
              let firstInitial = components.first?.first,
              let lastInitial = components.last?.first
        else {
            return false
        }
        return String(firstInitial).caseInsensitiveCompare(String(lastInitial)) == .orderedSame
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
