import SwiftUI

struct ResultsView: View {
    @ObservedObject var game: DraftGame

    var body: some View {
        List {
            Section("Final") {
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

            Section("Pick log") {
                ForEach(game.picks) { pick in
                    let seatName = game.seats.first(where: { $0.id == pick.seatId })?.name ?? "?"
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(seatName) — \(pick.displayName) (\(String(pick.season)))")
                            .font(.subheadline.weight(.medium))
                        Text(String(format: "%.0f points", pick.score))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 2)
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
}
