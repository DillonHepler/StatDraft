import SwiftUI

struct ContentView: View {
    @StateObject private var game = DraftGame()

    var body: some View {
        NavigationStack {
            Group {
                switch game.phase {
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
