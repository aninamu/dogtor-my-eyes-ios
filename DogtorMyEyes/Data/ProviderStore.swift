import Foundation
import Observation

@Observable
final class ProviderStore {
    private(set) var providers: [Provider] = []
    private(set) var loadError: String?

    var searchText = ""
    var selectedSpecialty: Specialty?
    var inNetworkOnly = true
    var sort: ProviderSort = .distance
    var selectedPlanRaw: String = InsurancePlan.vsp.rawValue {
        didSet { persistPlan() }
    }

    var favoriteIDs: Set<String> = [] {
        didSet { persistFavorites() }
    }

    var selectedPlan: InsurancePlan {
        get { InsurancePlan(rawValue: selectedPlanRaw) ?? .vsp }
        set { selectedPlanRaw = newValue.rawValue }
    }

    private let persistenceEnabled: Bool

    var filteredProviders: [Provider] {
        var result = providers

        if inNetworkOnly {
            result = result.filter { $0.isInNetwork(for: selectedPlan) }
        }

        if let specialty = selectedSpecialty {
            result = result.filter { $0.specialty == specialty }
        }

        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !query.isEmpty {
            result = result.filter { provider in
                provider.name.localizedCaseInsensitiveContains(query)
                    || provider.breed.localizedCaseInsensitiveContains(query)
                    || provider.specialty.displayName.localizedCaseInsensitiveContains(query)
            }
        }

        switch sort {
        case .distance:
            result.sort { $0.distanceMiles < $1.distanceMiles }
        case .rating:
            result.sort {
                if $0.rating == $1.rating {
                    return $0.reviewCount > $1.reviewCount
                }
                return $0.rating > $1.rating
            }
        }

        return result
    }

    var favoriteProviders: [Provider] {
        providers
            .filter { favoriteIDs.contains($0.id) }
            .sorted { $0.name < $1.name }
    }

    init(userDefaults: UserDefaults = .standard, bundle: Bundle = .main) {
        persistenceEnabled = true
        selectedPlanRaw = userDefaults.string(forKey: Self.planKey) ?? InsurancePlan.vsp.rawValue
        if let saved = userDefaults.array(forKey: Self.favoritesKey) as? [String] {
            favoriteIDs = Set(saved)
        }
        loadProviders(from: bundle)
    }

    /// Test-friendly initializer that skips disk I/O and UserDefaults writes.
    init(providers: [Provider], selectedPlan: InsurancePlan = .vsp, favoriteIDs: Set<String> = []) {
        persistenceEnabled = false
        self.providers = providers
        self.selectedPlanRaw = selectedPlan.rawValue
        self.favoriteIDs = favoriteIDs
    }

    func isFavorite(_ provider: Provider) -> Bool {
        favoriteIDs.contains(provider.id)
    }

    func toggleFavorite(_ provider: Provider) {
        if favoriteIDs.contains(provider.id) {
            favoriteIDs.remove(provider.id)
        } else {
            favoriteIDs.insert(provider.id)
        }
    }

    func provider(id: String) -> Provider? {
        providers.first { $0.id == id }
    }

    private func loadProviders(from bundle: Bundle) {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        guard let url = bundle.url(forResource: "providers", withExtension: "json") else {
            loadError = "Missing providers.json in app bundle."
            providers = []
            return
        }

        do {
            let data = try Data(contentsOf: url)
            providers = try decoder.decode([Provider].self, from: data)
            loadError = nil
        } catch {
            loadError = "Could not load providers: \(error.localizedDescription)"
            providers = []
        }
    }

    private func persistPlan() {
        guard persistenceEnabled else { return }
        UserDefaults.standard.set(selectedPlanRaw, forKey: Self.planKey)
    }

    private func persistFavorites() {
        guard persistenceEnabled else { return }
        UserDefaults.standard.set(Array(favoriteIDs), forKey: Self.favoritesKey)
    }

    private static let planKey = "selectedInsurancePlan"
    private static let favoritesKey = "favoriteProviderIDs"
}
