import XCTest
@testable import DogtorMyEyes

final class FinderRankerTests: XCTestCase {
    private let locale = Locale(identifier: "en_US_POSIX")
    private let day: TimeInterval = 86_400

    /// Fixtures.now is a Tuesday; +4 days lands on Saturday in New York.
    private var saturdayNoon: Date { Fixtures.now.addingTimeInterval(4 * day + 3 * 3_600) }

    private var providers: [Provider] {
        [
            Fixtures.provider(id: "near-vsp-ophth", specialty: .ophthalmology, plans: [.vsp], distance: 1, area: "Brooklyn",
                              slots: [Fixtures.now.addingTimeInterval(day)]),
            Fixtures.provider(id: "far-vsp-ophth-saturday", specialty: .ophthalmology, plans: [.vsp], distance: 6, area: "Brooklyn",
                              slots: [saturdayNoon]),
            Fixtures.provider(id: "eyemed-ophth", specialty: .ophthalmology, plans: [.eyeMed], acceptsSelfPay: false,
                              distance: 2, area: "Brooklyn"),
            Fixtures.provider(id: "manhattan-ophth", specialty: .ophthalmology, plans: [.vsp], distance: 3, area: "Manhattan"),
            Fixtures.provider(id: "brooklyn-optom", specialty: .optometry, plans: [.vsp], distance: 0.5, area: "Brooklyn"),
            Fixtures.provider(id: "no-openings", specialty: .ophthalmology, plans: [.vsp], distance: 0.2, area: "Brooklyn", slots: []),
        ]
    }

    private var headline: FinderFilters {
        var filters = FinderFilters()
        filters.specialty = .ophthalmology
        filters.plan = .coverage(.insurance(.vsp))
        filters.area = "Brooklyn"
        filters.urgency = .weekday(7)
        filters.triage = .symptom
        return filters
    }

    func testResultsAreOnlyCatalogProvidersMatchingHardFilters() {
        let results = FinderRanker.rank(providers, filters: headline, plan: headline.plan, now: Fixtures.now, locale: locale)
        let catalogIDs = Set(providers.map(\.id))

        XCTAssertTrue(results.allSatisfy { catalogIDs.contains($0.provider.id) })
        XCTAssertEqual(Set(results.map(\.provider.id)), ["near-vsp-ophth", "far-vsp-ophth-saturday", "no-openings"])
    }

    func testMatchingDayRanksFirstAndNoOpeningsRankLast() {
        let results = FinderRanker.rank(providers, filters: headline, plan: headline.plan, now: Fixtures.now, locale: locale)

        XCTAssertEqual(results.map(\.provider.id), ["far-vsp-ophth-saturday", "near-vsp-ophth", "no-openings"])
        XCTAssertEqual(results[0].matchingSlot, saturdayNoon)
        XCTAssertNil(results[1].matchingSlot)
    }

    func testReasonsAreBuiltFromMatchedFilters() {
        let results = FinderRanker.rank(providers, filters: headline, plan: headline.plan, now: Fixtures.now, locale: locale)
        // Date formatting may use a narrow no-break space before AM/PM.
        let byID = Dictionary(uniqueKeysWithValues: results.map {
            ($0.provider.id, $0.reason.replacingOccurrences(of: "\u{202F}", with: " "))
        })

        XCTAssertEqual(byID["far-vsp-ophth-saturday"], "Ophthalmology · In-network for VSP · Brooklyn · Opens Sat 12:14 PM")
        XCTAssertEqual(byID["near-vsp-ophth"], "Ophthalmology · In-network for VSP · Brooklyn · No Saturday openings")
        XCTAssertEqual(byID["no-openings"], "Ophthalmology · In-network for VSP · Brooklyn · No upcoming openings")
    }

    func testBadgeOnlyWhenTheCatalogBacksIt() {
        var filters = headline
        filters.inNetworkOnly = false

        let vsp = FinderRanker.rank(providers, filters: filters, plan: .coverage(.insurance(.vsp)), now: Fixtures.now)
        XCTAssertEqual(vsp.first { $0.provider.id == "eyemed-ophth" }?.networkStatus, .outOfNetwork)
        XCTAssertEqual(vsp.first { $0.provider.id == "near-vsp-ophth" }?.networkStatus, .inNetwork)

        let aetna = FinderRanker.rank(providers, filters: filters, plan: .unsupported("Aetna"), now: Fixtures.now)
        XCTAssertTrue(aetna.allSatisfy { $0.networkStatus == nil })
        XCTAssertTrue(aetna.allSatisfy { $0.reason.contains("Aetna not in directory") })

        let selfPay = FinderRanker.rank(providers, filters: filters, plan: .coverage(.selfPay), now: Fixtures.now)
        XCTAssertTrue(selfPay.allSatisfy { $0.networkStatus == nil })
        XCTAssertFalse(selfPay.contains { $0.provider.id == "eyemed-ophth" })
    }

    func testDistanceFilterAndNearbyReason() {
        var filters = FinderFilters()
        filters.maxDistanceMiles = 2
        let results = FinderRanker.rank(providers, filters: filters, plan: nil, now: Fixtures.now)

        XCTAssertTrue(results.allSatisfy { $0.provider.distanceMiles <= 2 })
        XCTAssertTrue(results.allSatisfy { $0.reason.contains("mi away") })
    }

    func testPastSlotsNeverCountAsMatches() {
        var filters = FinderFilters()
        filters.urgency = .asap
        let stale = Fixtures.provider(id: "stale", slots: [Fixtures.now.addingTimeInterval(-60)])

        let result = FinderRanker.rank([stale], filters: filters, plan: nil, now: Fixtures.now).first

        XCTAssertNil(result?.matchingSlot)
        XCTAssertEqual(result?.reason, "No upcoming openings")
    }
}
