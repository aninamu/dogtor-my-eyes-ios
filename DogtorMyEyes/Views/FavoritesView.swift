import SwiftUI

struct FavoritesView: View {
    @Environment(ProviderStore.self) private var store

    var body: some View {
        NavigationStack {
            Group {
                if store.favoriteProviders.isEmpty {
                    ContentUnavailableView(
                        "No favorites yet",
                        systemImage: "heart",
                        description: Text("Tap the heart on a provider to save them here.")
                    )
                } else {
                    List(store.favoriteProviders) { provider in
                        NavigationLink(value: provider.id) {
                            ProviderRow(
                                provider: provider,
                                networkStatus: provider.networkStatus(for: store.coverage),
                                isFavorite: true,
                                onToggleFavorite: { store.toggleFavorite(provider) }
                            )
                        }
                        .accessibilityIdentifier(AccessibilityID.ProviderRow.row(provider.id))
                    }
                }
            }
            .navigationTitle("Favorites")
            .navigationDestination(for: String.self) { id in
                if let provider = store.provider(id: id) {
                    ProviderDetailView(provider: provider)
                } else {
                    ContentUnavailableView("Provider not found", systemImage: "questionmark.circle")
                }
            }
            .background(Theme.sand.ignoresSafeArea())
        }
    }
}

#Preview {
    FavoritesView()
        .environment(ProviderStore())
        .environment(AppointmentStore(userDefaults: nil))
}
