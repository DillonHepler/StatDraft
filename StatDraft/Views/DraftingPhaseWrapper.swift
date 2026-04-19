import SwiftUI

/// Keeps one stable container while the draft runs so switching to results does not rely on
/// replacing the `NavigationStack` root (which can fail to show `ResultsView`).
struct DraftingPhaseWrapper: View {
    @ObservedObject var game: DraftGame

    var body: some View {
        Group {
            if game.phase == .finished {
                ResultsView(game: game)
            } else {
                DraftView(game: game)
            }
        }
    }
}
