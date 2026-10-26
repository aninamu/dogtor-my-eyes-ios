import XCTest
@testable import DogtorMyEyes

final class ProviderStoreTests: XCTestCase {
    private var sampleProviders: [Provider] {
        [
            Provider(
                id: "in-vsp",
                name: "Dr. In Network VSP",
                breed: "Beagle",
                specialty: .optometry,
                acceptedPlans: [.vsp, .outOfPocket],
                rating: 4.5,
                reviewCount: 10,
                distanceMiles: 2.0,
                bio: "VSP dogtor",
                services: ["Exam"],
                nextAvailable: [Date()],
                avatarColor: "C4A35A"
            ),
            Provider(
                id: "in-eyemed",
                name: "Dr. EyeMed Only",
                breed: "Poodle",
                specialty: .ophthalmology,
                acceptedPlans: [.eyeMed, .outOfPocket],
                rating: 4.9,
                reviewCount: 40,
                distanceMiles: 5.0,
                bio: "EyeMed dogtor",
                services: ["Surgery"],
                nextAvailable: [Date()],
                avatarColor: "4A6FA5"
            ),
            Provider(
                id: "pediatric-both",
                name: "Dr. Pip Pediatric",
                breed: "Beagle",
                specialty: .pediatric,
                acceptedPlans: [.vsp, .eyeMed, .outOfPocket],
                rating: 5.0,
                reviewCount: 90,
                distanceMiles: 1.0,
                bio: "Kids",
                services: ["Pediatric exam"],
                nextAvailable: [Date()],
                avatarColor: "D97757"
            )
        ]
    }

    func testInNetworkDetection() {
        let provider = sampleProviders[0]
        XCTAssertTrue(provider.isInNetwork(for: .vsp))
        XCTAssertFalse(provider.isInNetwork(for: .eyeMed))
        XCTAssertTrue(provider.isInNetwork(for: .outOfPocket))
    }

    func testInNetworkOnlyFilter() {
        let store = ProviderStore(providers: sampleProviders, selectedPlan: .vsp)
        store.inNetworkOnly = true

        let ids = store.filteredProviders.map(\.id)
        XCTAssertEqual(Set(ids), Set(["in-vsp", "pediatric-both"]))
    }

    func testSpecialtyFilter() {
        let store = ProviderStore(providers: sampleProviders, selectedPlan: .vsp)
        store.inNetworkOnly = false
        store.selectedSpecialty = .ophthalmology

        XCTAssertEqual(store.filteredProviders.map(\.id), ["in-eyemed"])
    }

    func testSearchByBreedAndSpecialty() {
        let store = ProviderStore(providers: sampleProviders, selectedPlan: .vsp)
        store.inNetworkOnly = false

        store.searchText = "beagle"
        XCTAssertEqual(Set(store.filteredProviders.map(\.id)), Set(["in-vsp", "pediatric-both"]))

        store.searchText = "pediatric"
        XCTAssertEqual(store.filteredProviders.map(\.id), ["pediatric-both"])
    }

    func testSortByDistanceAndRating() {
        let store = ProviderStore(providers: sampleProviders, selectedPlan: .vsp)
        store.inNetworkOnly = false

        store.sort = .distance
        XCTAssertEqual(store.filteredProviders.map(\.id), ["pediatric-both", "in-vsp", "in-eyemed"])

        store.sort = .rating
        XCTAssertEqual(store.filteredProviders.map(\.id), ["pediatric-both", "in-eyemed", "in-vsp"])
    }

    func testFavoritesToggle() {
        let store = ProviderStore(providers: sampleProviders, selectedPlan: .vsp)
        let provider = sampleProviders[0]

        XCTAssertFalse(store.isFavorite(provider))
        store.toggleFavorite(provider)
        XCTAssertTrue(store.isFavorite(provider))
        XCTAssertEqual(store.favoriteProviders.map(\.id), ["in-vsp"])

        store.toggleFavorite(provider)
        XCTAssertFalse(store.isFavorite(provider))
        XCTAssertTrue(store.favoriteProviders.isEmpty)
    }

    func testBundledProvidersJSONDecodes() throws {
        let bundle = Bundle(for: ProviderStoreTests.self)
        let url = bundle.url(forResource: "providers", withExtension: "json")
            ?? Bundle.main.url(forResource: "providers", withExtension: "json")

        // Prefer decoding the app-target fixture from disk next to the sources when running outside the host app bundle.
        let data: Data
        if let url {
            data = try Data(contentsOf: url)
        } else {
            let path = URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .appendingPathComponent("DogtorMyEyes/Data/providers.json")
            data = try Data(contentsOf: path)
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let providers = try decoder.decode([Provider].self, from: data)

        XCTAssertEqual(providers.count, 12)
        XCTAssertTrue(providers.allSatisfy { !$0.name.isEmpty })
        XCTAssertTrue(providers.contains { $0.specialty == .lasikConsult })
        XCTAssertTrue(providers.contains { $0.acceptedPlans.contains(.vsp) })
    }
}
