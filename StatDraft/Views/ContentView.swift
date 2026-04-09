import SwiftUI

struct ContentView: View {
    @StateObject private var game = DraftGame()

    var body: some View {
        NavigationStack {
            Group {
                switch game.phase {
                case .loading:
                    VStack(spacing: 12) {
                        ProgressView()
                        Text("Loading player database...")
                            .foregroundStyle(.secondary)
                    }
                case .lobby:
                    LobbyView(game: game)
                case .drafting:
                    DraftView(game: game)
                case .finished:
                    ResultsView(game: game)
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
