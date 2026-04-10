import SwiftUI

struct DraftView: View {
    @ObservedObject var game: DraftGame
    @State private var entry = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let prompt = game.currentPrompt, let seat = game.currentSeat, game.phase == .drafting {
                progressHeader
                Text(prompt.title)
                    .font(.title2.weight(.semibold))
                Text(prompt.detail)
                    .font(.body)
                    .foregroundStyle(.secondary)

                Divider()

                HStack(spacing: 4) {
                    Text("On the clock:")
                    Text(seat.name).fontWeight(.bold)
                }
                .font(.headline)
                HStack(spacing: 8) {
                    Image(systemName: "timer")
                    Text("Time left: \(game.secondsRemaining)s")
                        .monospacedDigit()
                        .fontWeight(.semibold)
                }
                .font(.subheadline)
                .foregroundStyle(game.secondsRemaining <= 10 ? .red : .secondary)

                TextField("Type full player name (e.g. Tom Brady)", text: $entry)
                    .textFieldStyle(.roundedBorder)
                    .textInputAutocapitalization(.words)
                    .onSubmit(submit)

                Button(action: submit) {
                    Label("Lock pick", systemImage: "checkmark.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(entry.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                if let err = game.lastError {
                    Text(err)
                        .foregroundStyle(.red)
                        .font(.callout)
                }

                if let summary = game.lastPickSummary {
                    Text(summary)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                standings
            } else if game.phase == .finished {
                EmptyView()
            } else {
                Text("Draft not active.")
            }

            Spacer(minLength: 0)
        }
        .padding()
        .navigationTitle("Live draft")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: game.currentRoundIndex) { _ in
            entry = ""
        }
        .onChange(of: game.currentPickInRound) { _ in
            entry = ""
        }
    }

    private var progressHeader: some View {
        let total = max(game.roundCount * max(game.seats.count, 1), 1)
        let done = game.picks.count
        return Text("Pick \(done + 1) of \(total) · Round \(game.currentRoundIndex + 1) of \(game.roundCount)")
            .font(.subheadline)
            .foregroundStyle(.secondary)
    }

    private var standings: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Standings")
                .font(.headline)
            ForEach(game.seats.sorted(by: { $0.totalScore > $1.totalScore })) { s in
                HStack {
                    Text(s.name)
                    Spacer()
                    Text(String(format: "%.0f", s.totalScore))
                        .monospacedDigit()
                }
                .font(.subheadline)
            }
        }
        .padding(.top, 8)
    }

    private func submit() {
        game.submitPick(rawName: entry)
        if game.lastError == nil {
            entry = ""
        }
    }
}
