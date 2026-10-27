import SwiftUI

@main
struct DogtorMyEyesApp: App {
    @State private var store = ProviderStore()
    @State private var appointments = AppointmentStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(store)
                .environment(appointments)
        }
    }
}

enum AppTab: Hashable {
    case browse
    case favorites
    case appointments
}

struct ContentView: View {
    @State private var selectedTab: AppTab = .browse

    var body: some View {
        TabView(selection: $selectedTab) {
            BrowseView()
                .tabItem {
                    Label("Browse", systemImage: "magnifyingglass")
                }
                .tag(AppTab.browse)

            FavoritesView()
                .tabItem {
                    Label("Favorites", systemImage: "heart.fill")
                }
                .tag(AppTab.favorites)

            AppointmentsView(onBrowse: { selectedTab = .browse })
                .tabItem {
                    Label("Appointments", systemImage: "calendar")
                }
                .tag(AppTab.appointments)
        }
        .tint(Theme.teal)
        .preferredColorScheme(.light)
    }
}

#Preview {
    ContentView()
        .environment(ProviderStore())
        .environment(AppointmentStore(userDefaults: nil))
}
