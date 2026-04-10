import SwiftUI

struct ResultsView: View {
    @ObservedObject var game: DraftGame

    var body: some View {
        List {
            if let winner = winnerInfo {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Label(winner.title, systemImage: "trophy.fill")
                            .font(.title2.weight(.bold))
                            .foregroundStyle(.orange)
                        Text(winner.subtitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }

            Section("Final standings") {
                ForEach(Array(rankings.enumerated()), id: \.offset) { idx, seat in
                    HStack {
                        Text("\(idx + 1).")
                            .foregroundStyle(.secondary)
                            .frame(width: 28, alignment: .leading)
                        Text(seat.name)
                        Spacer()
                        Text(String(format: "%.0f pts", seat.totalScore))
                            .monospacedDigit()
                            .fontWeight(.semibold)
                    }
                }
            }

            Section("Every pick") {
                ForEach(Array(game.picks.enumerated()), id: \.element.id) { index, pick in
                    let seatName = game.seats.first(where: { $0.id == pick.seatId })?.name ?? "?"
                    let promptTitle = game.prompts.first(where: { $0.id == pick.promptId })?.title ?? "Round \(pick.roundIndex + 1)"
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Round \(pick.roundIndex + 1) · Pick \(index + 1)")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text(promptTitle)
                            .font(.footnote)
                            .foregroundStyle(.tertiary)
                        HStack(alignment: .firstTextBaseline) {
                            Text(seatName)
                                .fontWeight(.semibold)
                            Text("→")
                                .foregroundStyle(.secondary)
                            Text(pick.displayName)
                            Spacer(minLength: 8)
                            Text(String(format: "%.0f pts", pick.score))
                                .monospacedDigit()
                                .fontWeight(.semibold)
                        }
                        .font(.subheadline)
                        Text("Season \(pick.season) stats for scoring")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.vertical, 4)
                }
            }

            Section {
                Button("New game (same players)") {
                    game.resetToLobby()
                }
            }
        }
        .navigationTitle("Results")
    }

    private var rankings: [PlayerSeat] {
        game.seats.sorted(by: { $0.totalScore > $1.totalScore })
    }

    private var winnerInfo: (title: String, subtitle: String)? {
        let ranked = rankings
        guard let first = ranked.first else { return nil }
        let topScore = first.totalScore
        let tied = ranked.filter { abs($0.totalScore - topScore) < 0.01 }
        if tied.count > 1 {
            let names = tied.map(\.name).joined(separator: " · ")
            return ("Tied for first", names)
        }
        return ("Winner: \(first.name)", String(format: "%.0f total points", first.totalScore))
    }
}
