import Foundation
import SwiftUI

@MainActor
final class DraftGame: ObservableObject {
    @Published private(set) var phase: DraftPhase = .loading
    @Published private(set) var seats: [PlayerSeat] = []
    @Published private(set) var prompts: [Prompt] = []
    @Published private(set) var picks: [DraftPick] = []
    @Published private(set) var takenPlayerIds: Set<String> = []
    @Published private(set) var currentRoundIndex: Int = 0
    @Published private(set) var currentPickInRound: Int = 0
    @Published var lastError: String?
    @Published var lastPickSummary: String?

    private var stats: StatsRepository?

    init(stats: StatsRepository? = nil) {
        self.stats = stats
        if stats == nil {
            Task {
                let loaded = await Task.detached(priority: .userInitiated) {
                    StatsRepository()
                }.value
                self.stats = loaded
                self.lastError = loaded.loadError
                self.phase = .lobby
            }
        } else {
            self.lastError = stats?.loadError
            self.phase = .lobby
        }
    }

    var roundCount: Int { prompts.count }

    var currentPrompt: Prompt? {
        guard currentRoundIndex < prompts.count else { return nil }
        return prompts[currentRoundIndex]
    }

    /// Whose turn in snake order.
    var currentSeat: PlayerSeat? {
        guard !seats.isEmpty else { return nil }
        let idx = snakeSeatIndex(
            round: currentRoundIndex,
            pickInRound: currentPickInRound,
            playerCount: seats.count
        )
        return seats[idx]
    }

    var isDraftComplete: Bool {
        picks.count >= seats.count * prompts.count && !prompts.isEmpty && !seats.isEmpty
    }

    func configureLobby(playerNames: [String], rounds: Int) {
        let trimmed = playerNames.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        seats = trimmed.map { PlayerSeat(name: $0) }
        prompts = PromptFactory.makePrompts(roundCount: rounds)
        picks = []
        takenPlayerIds = []
        currentRoundIndex = 0
        currentPickInRound = 0
        lastError = nil
        lastPickSummary = nil
        phase = .lobby
    }

    func startDraft() {
        guard let stats else {
            lastError = "Stats are still loading. Try again in a moment."
            return
        }
        if let loadError = stats.loadError {
            lastError = loadError
            return
        }
        guard seats.count >= 2, prompts.count >= 4 else {
            lastError = "Need at least 2 players and 4 rounds."
            return
        }
        phase = .drafting
        lastError = nil
    }

    func submitPick(rawName: String) {
        lastError = nil
        lastPickSummary = nil

        guard phase == .drafting else { return }
        guard let prompt = currentPrompt, let seat = currentSeat else {
            lastError = "Draft state error."
            return
        }
        guard let stats else {
            lastError = "Stats are still loading. Try again in a moment."
            return
        }

        switch stats.resolvePick(rawName: rawName, season: prompt.season, requiredPosition: prompt.position) {
        case .failure(let err):
            lastError = err.localizedDescription
        case .success(let pair):
            let (player, line) = pair
            if takenPlayerIds.contains(player.id) {
                lastError = "\(player.displayName) is already off the board."
                return
            }

            let points = prompt.scoringRule.points(for: line)
            let pick = DraftPick(
                roundIndex: currentRoundIndex,
                seatId: seat.id,
                promptId: prompt.id,
                resolvedPlayerId: player.id,
                displayName: player.displayName,
                season: prompt.season,
                score: points
            )
            picks.append(pick)
            takenPlayerIds.insert(player.id)

            if let i = seats.firstIndex(where: { $0.id == seat.id }) {
                seats[i].totalScore += points
            }

            lastPickSummary =
                "\(seat.name) takes \(player.displayName) (\(prompt.season)) — \(Int(points.rounded())) pts"

            advanceCursor()
            if isDraftComplete {
                phase = .finished
            }
        }
    }

    func resetToLobby() {
        phase = .lobby
        picks = []
        takenPlayerIds = []
        currentRoundIndex = 0
        currentPickInRound = 0
        seats = seats.map { PlayerSeat(id: $0.id, name: $0.name, totalScore: 0) }
        lastError = nil
        lastPickSummary = nil
    }

    private func advanceCursor() {
        currentPickInRound += 1
        if currentPickInRound >= seats.count {
            currentPickInRound = 0
            currentRoundIndex += 1
        }
    }

    private func snakeSeatIndex(round: Int, pickInRound: Int, playerCount: Int) -> Int {
        guard playerCount > 0 else { return 0 }
        if round % 2 == 0 {
            return pickInRound
        }
        return playerCount - 1 - pickInRound
    }
}
