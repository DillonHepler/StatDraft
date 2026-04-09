import Foundation

struct PlayerSeat: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var totalScore: Double

    init(id: UUID = UUID(), name: String, totalScore: Double = 0) {
        self.id = id
        self.name = name
        self.totalScore = totalScore
    }
}

struct DraftPick: Identifiable, Codable, Equatable {
    let id: UUID
    let roundIndex: Int
    let seatId: UUID
    let promptId: UUID
    let resolvedPlayerId: String
    let displayName: String
    let season: Int
    let score: Double

    init(
        id: UUID = UUID(),
        roundIndex: Int,
        seatId: UUID,
        promptId: UUID,
        resolvedPlayerId: String,
        displayName: String,
        season: Int,
        score: Double
    ) {
        self.id = id
        self.roundIndex = roundIndex
        self.seatId = seatId
        self.promptId = promptId
        self.resolvedPlayerId = resolvedPlayerId
        self.displayName = displayName
        self.season = season
        self.score = score
    }
}

enum DraftPhase: Equatable {
    case loading
    case lobby
    case drafting
    case finished
}

struct DraftConfiguration: Codable, Equatable {
    var seats: [PlayerSeat]
    var roundCount: Int
    var prompts: [Prompt]

    var isValid: Bool {
        seats.count >= 2 && seats.count <= 8 && roundCount >= 4 && roundCount <= 16
            && prompts.count == roundCount
    }
}
