import SwiftUI

@main
struct DogtorMyEyesApp: App {
    @State private var store = ProviderStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(store)
        }
    }
}

struct ContentView: View {
    var body: some View {
        TabView {
            BrowseView()
                .tabItem {
                    Label("Browse", systemImage: "magnifyingglass")
                }

            FavoritesView()
                .tabItem {
                    Label("Favorites", systemImage: "heart.fill")
                }

            AppointmentsView()
                .tabItem {
                    Label("Appointments", systemImage: "calendar")
                }
        }
        .tint(Theme.teal)
        .preferredColorScheme(.light)
    }
}

#Preview {
    ContentView()
        .environment(ProviderStore())
}
