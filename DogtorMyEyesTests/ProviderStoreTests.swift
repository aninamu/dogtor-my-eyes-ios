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

    func testRequestAppointmentAppends() {
        let store = ProviderStore(providers: sampleProviders, selectedPlan: .vsp)
        let first = sampleProviders[0]
        let second = sampleProviders[1]
        let slotA = Date(timeIntervalSince1970: 1_800_000_000)
        let slotB = Date(timeIntervalSince1970: 1_800_086_400)
        let slotC = Date(timeIntervalSince1970: 1_800_172_800)

        store.requestAppointment(with: first, slot: slotA, plan: .vsp)
        store.requestAppointment(with: first, slot: slotB, plan: .eyeMed)
        store.requestAppointment(with: second, slot: slotC, plan: .davis)

        XCTAssertEqual(store.appointments.count, 3)
        XCTAssertEqual(store.appointments.map(\.providerID), [first.id, first.id, second.id])
        XCTAssertEqual(store.appointments.map(\.slot), [slotA, slotB, slotC])
        XCTAssertEqual(store.appointments.map(\.plan), [.vsp, .eyeMed, .davis])
        XCTAssertTrue(store.appointments.allSatisfy { $0.status == .requested })
    }

    func testUpcomingAndPastSorting() {
        let store = ProviderStore(providers: sampleProviders, selectedPlan: .vsp)
        let provider = sampleProviders[0]
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let pastEarly = now.addingTimeInterval(-86_400 * 2)
        let pastLate = now.addingTimeInterval(-86_400)
        let upcomingSoon = now.addingTimeInterval(86_400)
        let upcomingLater = now.addingTimeInterval(86_400 * 3)

        store.requestAppointment(with: provider, slot: upcomingLater, plan: .vsp)
        store.requestAppointment(with: provider, slot: pastLate, plan: .vsp)
        store.requestAppointment(with: provider, slot: upcomingSoon, plan: .vsp)
        store.requestAppointment(with: provider, slot: pastEarly, plan: .vsp)
        store.requestAppointment(with: provider, slot: now, plan: .vsp)

        let upcoming = store.upcomingAppointments(now: now)
        let past = store.pastAppointments(now: now)

        XCTAssertEqual(upcoming.map(\.slot), [now, upcomingSoon, upcomingLater])
        XCTAssertEqual(past.map(\.slot), [pastLate, pastEarly])

        let upcomingIDs = Set(upcoming.map(\.id))
        let pastIDs = Set(past.map(\.id))
        XCTAssertTrue(upcomingIDs.isDisjoint(with: pastIDs))
        XCTAssertEqual(upcomingIDs.union(pastIDs).count, store.appointments.count)
    }

    func testAppointmentsPersistAndReload() throws {
        let suiteName = "DogtorMyEyesTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            XCTFail("Could not create UserDefaults suite")
            return
        }
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let provider = sampleProviders[0]
        let slot = Date(timeIntervalSince1970: 1_800_000_000)
        let first = ProviderStore(userDefaults: defaults, bundle: Bundle(for: ProviderStoreTests.self))
        first.requestAppointment(with: provider, slot: slot, plan: .eyeMed)

        let saved = try XCTUnwrap(first.appointments.first)
        let second = ProviderStore(userDefaults: defaults, bundle: Bundle(for: ProviderStoreTests.self))
        let loaded = try XCTUnwrap(second.appointments.first)

        XCTAssertEqual(second.appointments.count, 1)
        XCTAssertEqual(loaded.id, saved.id)
        XCTAssertEqual(loaded.providerID, provider.id)
        XCTAssertEqual(loaded.slot.timeIntervalSince1970, slot.timeIntervalSince1970, accuracy: 1)
        XCTAssertEqual(loaded.plan, .eyeMed)
        XCTAssertEqual(loaded.status, .requested)
        XCTAssertEqual(
            loaded.requestedAt.timeIntervalSince1970,
            saved.requestedAt.timeIntervalSince1970,
            accuracy: 1
        )
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
