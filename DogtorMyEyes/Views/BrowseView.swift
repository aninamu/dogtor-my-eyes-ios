import SwiftUI

struct BrowseView: View {
    @Environment(ProviderStore.self) private var store

    var body: some View {
        @Bindable var store = store
        let providers = store.filteredProviders

        NavigationStack {
            List {
                Section {
                    Picker("Insurance plan", selection: $store.coverage) {
                        ForEach(Coverage.allCases) { coverage in
                            Text(coverage.displayName).tag(coverage)
                        }
                    }
                    .pickerStyle(.menu)
                    .accessibilityIdentifier(AccessibilityID.Browse.planPicker)

                    if store.coverage == .selfPay {
                        Text("Self-pay isn’t an insurance network, so network badges are hidden. Showing providers that accept self-pay.")
                            .font(Theme.captionFont)
                            .foregroundStyle(Theme.muted)
                    } else {
                        Toggle("In-network only", isOn: $store.inNetworkOnly)
                            .accessibilityIdentifier(AccessibilityID.Browse.inNetworkToggle)
                    }

                    Picker("Sort by", selection: $store.sort) {
                        ForEach(ProviderSort.allCases) { option in
                            Text(option.displayName).tag(option)
                        }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier(AccessibilityID.Browse.sortPicker)
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
                            .accessibilityIdentifier(AccessibilityID.Browse.allSpecialtiesChip)

                            ForEach(Specialty.allCases) { specialty in
                                SpecialtyChip(
                                    title: specialty.displayName,
                                    systemImage: specialty.systemImage,
                                    selected: store.selectedSpecialty == specialty
                                ) {
                                    store.selectedSpecialty = specialty
                                }
                                .accessibilityIdentifier(AccessibilityID.Browse.specialtyChip(specialty))
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
                    } else if providers.isEmpty {
                        ContentUnavailableView(
                            "No providers match",
                            systemImage: "eye.slash",
                            description: Text("Try another plan, specialty, or search term.")
                        )
                    } else {
                        ForEach(providers) { provider in
                            NavigationLink(value: provider.id) {
                                ProviderRow(
                                    provider: provider,
                                    networkStatus: provider.networkStatus(for: store.coverage),
                                    isFavorite: store.isFavorite(provider),
                                    onToggleFavorite: { store.toggleFavorite(provider) }
                                )
                            }
                            .accessibilityIdentifier(AccessibilityID.ProviderRow.row(provider.id))
                        }
                    }
                } header: {
                    Text("\(providers.count) providers")
                        .accessibilityIdentifier(AccessibilityID.Browse.resultsHeader)
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
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

#Preview {
    BrowseView()
        .environment(ProviderStore())
        .environment(AppointmentStore(userDefaults: nil))
}
