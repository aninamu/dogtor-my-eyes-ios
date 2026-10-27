import XCTest
@testable import DogtorMyEyes

final class ProviderStoreTests: XCTestCase {
    private var sampleProviders: [Provider] {
        [
            Fixtures.provider(id: "in-vsp", breed: "Beagle", specialty: .optometry, plans: [.vsp], rating: 4.5, reviewCount: 10, distance: 2.0),
            Fixtures.provider(id: "in-eyemed", breed: "Poodle", specialty: .ophthalmology, plans: [.eyeMed], rating: 4.9, reviewCount: 40, distance: 5.0),
            Fixtures.provider(
                id: "pediatric-both",
                name: "Dr. Pip Pediatric",
                breed: "Beagle",
                specialty: .pediatric,
                plans: [.vsp, .eyeMed],
                acceptsSelfPay: false,
                rating: 5.0,
                reviewCount: 90,
                distance: 1.0
            ),
        ]
    }

    func testInNetworkDetection() {
        let provider = sampleProviders[0]
        XCTAssertTrue(provider.isInNetwork(for: .vsp))
        XCTAssertFalse(provider.isInNetwork(for: .eyeMed))
        XCTAssertEqual(provider.networkStatus(for: .insurance(.vsp)), .inNetwork)
        XCTAssertEqual(provider.networkStatus(for: .insurance(.eyeMed)), .outOfNetwork)
    }

    func testInNetworkOnlyFilter() {
        let store = ProviderStore(providers: sampleProviders)
        store.coverage = .insurance(.vsp)
        store.inNetworkOnly = true

        XCTAssertEqual(Set(store.filteredProviders.map(\.id)), Set(["in-vsp", "pediatric-both"]))
    }

    func testSpecialtyFilter() {
        let store = ProviderStore(providers: sampleProviders)
        store.inNetworkOnly = false
        store.selectedSpecialty = .ophthalmology

        XCTAssertEqual(store.filteredProviders.map(\.id), ["in-eyemed"])
    }

    func testSearchByBreedAndSpecialty() {
        let store = ProviderStore(providers: sampleProviders)
        store.inNetworkOnly = false

        store.searchText = "beagle"
        XCTAssertEqual(Set(store.filteredProviders.map(\.id)), Set(["in-vsp", "pediatric-both"]))

        store.searchText = "pediatric"
        XCTAssertEqual(store.filteredProviders.map(\.id), ["pediatric-both"])
    }

    func testSortByDistanceAndRating() {
        let store = ProviderStore(providers: sampleProviders)
        store.inNetworkOnly = false

        store.sort = .distance
        XCTAssertEqual(store.filteredProviders.map(\.id), ["pediatric-both", "in-vsp", "in-eyemed"])

        store.sort = .rating
        XCTAssertEqual(store.filteredProviders.map(\.id), ["pediatric-both", "in-eyemed", "in-vsp"])
    }

    func testFavoritesToggle() {
        let store = ProviderStore(providers: sampleProviders)
        let provider = sampleProviders[0]

        XCTAssertFalse(store.isFavorite(provider))
        store.toggleFavorite(provider)
        XCTAssertTrue(store.isFavorite(provider))
        XCTAssertEqual(store.favoriteProviders.map(\.id), ["in-vsp"])

        store.toggleFavorite(provider)
        XCTAssertFalse(store.isFavorite(provider))
        XCTAssertTrue(store.favoriteProviders.isEmpty)
    }

    // MARK: M4 — self-pay is not an insurance network

    func testSelfPayNeverReportsNetworkStatus() {
        for provider in sampleProviders {
            XCTAssertNil(provider.networkStatus(for: .selfPay))
        }
    }

    func testSelfPayFiltersBySelfPayAcceptanceRegardlessOfToggle() {
        let store = ProviderStore(providers: sampleProviders)
        store.coverage = .selfPay

        store.inNetworkOnly = true
        XCTAssertEqual(Set(store.filteredProviders.map(\.id)), Set(["in-vsp", "in-eyemed"]))
        store.inNetworkOnly = false
        XCTAssertEqual(Set(store.filteredProviders.map(\.id)), Set(["in-vsp", "in-eyemed"]))
    }

    func testCoverageRawValuesRoundTripAndMigrateLegacyOutOfPocket() {
        for coverage in Coverage.allCases {
            XCTAssertEqual(Coverage(rawValue: coverage.rawValue), coverage)
        }
        XCTAssertEqual(Coverage(rawValue: "outOfPocket"), .selfPay)
        XCTAssertNil(Coverage(rawValue: "aetna"))
        XCTAssertFalse(InsurancePlan.allCases.map(\.rawValue).contains("outOfPocket"))
    }

    // MARK: M3 — injected UserDefaults is used for reads and writes

    func testInjectedDefaultsReceiveWrites() throws {
        let defaults = try Fixtures.isolatedDefaults()
        let store = ProviderStore(providers: sampleProviders, userDefaults: defaults)

        store.coverage = .insurance(.eyeMed)
        store.toggleFavorite(sampleProviders[1])

        XCTAssertEqual(defaults.string(forKey: ProviderStore.coverageKey), "eyeMed")
        XCTAssertEqual(defaults.stringArray(forKey: ProviderStore.favoritesKey), ["in-eyemed"])
    }

    func testPersistedStateIsReadBackByANewStore() throws {
        let defaults = try Fixtures.isolatedDefaults()
        let first = ProviderStore(providers: sampleProviders, userDefaults: defaults)
        first.coverage = .selfPay
        first.toggleFavorite(sampleProviders[0])
        first.toggleFavorite(sampleProviders[2])

        let second = ProviderStore(providers: sampleProviders, userDefaults: defaults)
        XCTAssertEqual(second.coverage, .selfPay)
        XCTAssertEqual(second.favoriteIDs, ["in-vsp", "pediatric-both"])
    }

    func testLegacyStoredOutOfPocketLoadsAsSelfPay() throws {
        let defaults = try Fixtures.isolatedDefaults()
        defaults.set("outOfPocket", forKey: ProviderStore.coverageKey)

        XCTAssertEqual(ProviderStore(providers: [], userDefaults: defaults).coverage, .selfPay)
    }

    func testInMemoryStoreDoesNotTouchStandardDefaults() {
        let key = ProviderStore.favoritesKey
        let before = UserDefaults.standard.object(forKey: key) as? [String]

        let store = ProviderStore(providers: sampleProviders)
        store.toggleFavorite(sampleProviders[0])

        XCTAssertEqual(UserDefaults.standard.object(forKey: key) as? [String], before)
    }
}
