import SwiftUI

struct LobbyView: View {
    @ObservedObject var game: DraftGame
    @State private var names: [String] = ["Alex", "Sam"]
    @State private var rounds: Int = 8

    var body: some View {
        Form {
            Section {
                Stepper("Rounds: \(rounds)", value: $rounds, in: 4...16, step: 1)
                Text("Snake draft: each round uses a new stat prompt. Players cannot repeat the same NFL player.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Players (2–8)") {
                ForEach(names.indices, id: \.self) { i in
                    TextField("Player \(i + 1)", text: $names[i])
                        .textInputAutocapitalization(.words)
                }
                if names.count < 8 {
                    Button("Add player") {
                        names.append("")
                    }
                }
                if names.count > 2 {
                    Button("Remove last", role: .destructive) {
                        names.removeLast()
                    }
                }
            }

            Section {
                Button("Start draft") {
                    game.configureLobby(playerNames: names, rounds: rounds)
                    game.startDraft()
                }
                .disabled(!canStart)

                if let err = game.lastError {
                    Text(err)
                        .foregroundStyle(.red)
                        .font(.callout)
                }
            }
        }
        .navigationTitle("Stat Draft")
        .onAppear {
            if game.seats.count >= 2 {
                names = game.seats.map(\.name)
            }
        }
    }

    private var canStart: Bool {
        let trimmed = names.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        return trimmed.count >= 2 && trimmed.count == Set(trimmed).count
    }
}
