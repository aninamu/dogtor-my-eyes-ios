import SwiftUI

struct BrowseView: View {
    @Environment(ProviderStore.self) private var store
    @Environment(FinderModel.self) private var finder
    @Environment(ConnectivityMonitor.self) private var connectivity
    @Environment(\.featureFlags) private var featureFlags

    private var finderEnabled: Bool {
        featureFlags.isEnabled(.phase1Finder)
    }

    var body: some View {
        @Bindable var store = store
        @Bindable var finder = finder

        NavigationStack {
            List {
                if finderEnabled && finder.isActive {
                    finderSections
                } else {
                    classicSections
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
            .safeAreaInset(edge: .top, spacing: 0) {
                if finderEnabled {
                    FinderSearchBar(
                        text: $finder.query,
                        isParsing: finder.phase == .parsing,
                        onSubmit: submitFinder,
                        onClear: finder.clear
                    )
                }
            }
            .background(Theme.sand.ignoresSafeArea())
        }
    }

    private func submitFinder() {
        Task {
            await finder.submit(knownAreas: store.knownAreas, savedCoverage: store.coverage)
        }
    }

    // MARK: - Finder

    @ViewBuilder
    private var finderSections: some View {
        if connectivity.isOffline {
            Section {
                FinderStatusView(kind: .offline)
            }
        }

        switch finder.phase {
        case .idle:
            EmptyView()
        case .parsing:
            Section {
                FinderStatusView(kind: .thinking)
            }
        case .failed(let message):
            Section {
                FinderStatusView(kind: .error(message), onRetry: submitFinder)
            }
        case .ready:
            if finder.filters.triage != .none {
                Section {
                    TriageNotice(triage: finder.filters.triage)
                }
            }

            Section {
                UnderstoodChipsRow(finder: finder, areas: store.knownAreas)
                if finder.filters.confidence == .notSure {
                    FinderStatusView(kind: .notSure)
                }
                if finder.usedBasicMatching, finder.fallbackReason != .disabled {
                    FinderStatusView(kind: .basicMatching(finder.fallbackReason))
                }
            }

            finderResults
        }
    }

    @ViewBuilder
    private var finderResults: some View {
        let matches = finder.results(from: store.providers)
        Section {
            if let loadError = store.loadError {
                ContentUnavailableView(
                    "Couldn’t load providers",
                    systemImage: "exclamationmark.triangle",
                    description: Text(loadError)
                )
            } else if matches.isEmpty {
                ContentUnavailableView(
                    "No providers match",
                    systemImage: "eye.slash",
                    description: Text("Tap a chip above to widen your search, or clear it to browse everyone.")
                )
            } else {
                ForEach(matches) { match in
                    NavigationLink(value: match.provider.id) {
                        FinderResultRow(
                            match: match,
                            isFavorite: store.isFavorite(match.provider),
                            onToggleFavorite: { store.toggleFavorite(match.provider) }
                        )
                    }
                    .accessibilityIdentifier(AccessibilityID.ProviderRow.row(match.provider.id))
                }
            }
        } header: {
            Text("\(matches.count) matches")
                .accessibilityIdentifier(AccessibilityID.Finder.resultsHeader)
        } footer: {
            Text("Network status comes from this directory, not your plan. Confirm coverage with your plan before you book.")
                .font(Theme.captionFont)
                .foregroundStyle(Theme.muted)
        }
    }

    // MARK: - Classic browse

    @ViewBuilder
    private var classicSections: some View {
        @Bindable var store = store
        let providers = store.filteredProviders

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
        .environment(FinderModel(parser: ResilientFinderParser(primary: nil)))
        .environment(ConnectivityMonitor())
}
