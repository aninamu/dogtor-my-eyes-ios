import SwiftUI

struct BrowseView: View {
    @Environment(ProviderStore.self) private var store

    var body: some View {
        @Bindable var store = store

        NavigationStack {
            List {
                Section {
                    Picker("Insurance plan", selection: $store.selectedPlan) {
                        ForEach(InsurancePlan.allCases) { plan in
                            Text(plan.displayName).tag(plan)
                        }
                    }
                    .pickerStyle(.menu)

                    Toggle("In-network only", isOn: $store.inNetworkOnly)

                    Picker("Sort by", selection: $store.sort) {
                        ForEach(ProviderSort.allCases) { option in
                            Text(option.displayName).tag(option)
                        }
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("Your coverage")
                }

                Section {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            SpecialtyChip(
                                title: "All",
                                systemImage: "pawprint.fill",
                                selected: store.selectedSpecialty == nil
                            ) {
                                store.selectedSpecialty = nil
                            }

                            ForEach(Specialty.allCases) { specialty in
                                SpecialtyChip(
                                    title: specialty.displayName,
                                    systemImage: specialty.systemImage,
                                    selected: store.selectedSpecialty == specialty
                                ) {
                                    store.selectedSpecialty = specialty
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                }

                Section {
                    if let loadError = store.loadError {
                        ContentUnavailableView(
                            "Couldn’t load providers",
                            systemImage: "exclamationmark.triangle",
                            description: Text(loadError)
                        )
                    } else if store.filteredProviders.isEmpty {
                        ContentUnavailableView(
                            "No providers match",
                            systemImage: "eye.slash",
                            description: Text("Try another plan, specialty, or search term.")
                        )
                    } else {
                        ForEach(store.filteredProviders) { provider in
                            NavigationLink(value: provider.id) {
                                ProviderRow(
                                    provider: provider,
                                    plan: store.selectedPlan,
                                    isFavorite: store.isFavorite(provider),
                                    onToggleFavorite: { store.toggleFavorite(provider) }
                                )
                            }
                        }
                    }
                } header: {
                    Text("\(store.filteredProviders.count) providers")
                }
            }
            .navigationTitle("Dogtor My Eyes")
            .navigationDestination(for: String.self) { id in
                if let provider = store.provider(id: id) {
                    ProviderDetailView(provider: provider)
                } else {
                    ContentUnavailableView("Provider not found", systemImage: "questionmark.circle")
                }
            }
            .searchable(text: $store.searchText, prompt: "Name, breed, or specialty")
            .background(Theme.sand.ignoresSafeArea())
        }
    }
}

private struct SpecialtyChip: View {
    let title: String
    let systemImage: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(Theme.captionFont.weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .foregroundStyle(selected ? .white : Theme.deepTeal)
                .background(selected ? Theme.teal : Theme.teal.opacity(0.12), in: Capsule())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    BrowseView()
        .environment(ProviderStore())
}
