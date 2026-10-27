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

    var coverage: Coverage = .insurance(.vsp) {
        didSet { defaults?.set(coverage.rawValue, forKey: Self.coverageKey) }
    }

    var favoriteIDs: Set<String> = [] {
        didSet { defaults?.set(Array(favoriteIDs).sorted(), forKey: Self.favoritesKey) }
    }

    /// `nil` disables persistence entirely; otherwise every read and write goes through this instance.
    @ObservationIgnored private let defaults: UserDefaults?

    var filteredProviders: [Provider] {
        var result = providers

        switch coverage {
        case .selfPay:
            result = result.filter(\.acceptsSelfPay)
        case .insurance(let plan):
            if inNetworkOnly {
                result = result.filter { $0.isInNetwork(for: plan) }
            }
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

    /// Areas present in the catalog; the finder may only filter to one of these.
    var knownAreas: [String] {
        Array(Set(providers.map(\.area).filter { !$0.isEmpty })).sorted()
    }

    var favoriteProviders: [Provider] {
        providers
            .filter { favoriteIDs.contains($0.id) }
            .sorted { $0.name < $1.name }
    }

    convenience init(userDefaults: UserDefaults = .standard, bundle: Bundle = .main, now: Date = .now) {
        let catalog = ProviderCatalog.load(from: bundle, now: now)
        self.init(providers: catalog.providers, loadError: catalog.errorMessage, userDefaults: userDefaults)
    }

    /// Pass `userDefaults: nil` (the default) for an in-memory store with no persistence.
    init(providers: [Provider], loadError: String? = nil, userDefaults: UserDefaults? = nil) {
        defaults = userDefaults
        self.providers = providers
        self.loadError = loadError
        if let userDefaults {
            coverage = userDefaults.string(forKey: Self.coverageKey).flatMap(Coverage.init(rawValue:)) ?? .insurance(.vsp)
            favoriteIDs = Set(userDefaults.stringArray(forKey: Self.favoritesKey) ?? [])
        }
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

    static let coverageKey = "selectedInsurancePlan"
    static let favoritesKey = "favoriteProviderIDs"
}
