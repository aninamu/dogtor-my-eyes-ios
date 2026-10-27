import XCTest
@testable import DogtorMyEyes

private struct StubParser: FinderQueryParser {
    var result: Result<FinderFilters, FinderParserError>
    var delayNanoseconds: UInt64 = 0

    func parse(_ query: String, context: FinderParseContext) async throws -> FinderFilters {
        if delayNanoseconds > 0 { try await Task.sleep(nanoseconds: delayNanoseconds) }
        return try result.get()
    }
}

final class ResilientFinderParserTests: XCTestCase {
    private let context = FinderParseContext(knownAreas: ["Brooklyn", "Queens"], now: Fixtures.now)

    func testNoPrimaryUsesRulesAndReportsWhy() async throws {
        let parser = ResilientFinderParser(primary: nil, primaryUnavailableReason: .modelUnavailable)

        let result = try await parser.parse("cloudy eye, VSP", context: context)

        XCTAssertEqual(result.source, .rules)
        XCTAssertEqual(result.fallbackReason, .modelUnavailable)
        XCTAssertEqual(result.filters.specialty, .ophthalmology)
    }

    func testModelErrorFallsBackToRules() async throws {
        let parser = ResilientFinderParser(primary: StubParser(result: .failure(.modelUnavailable)))

        let result = try await parser.parse("VSP Saturday", context: context)

        XCTAssertEqual(result.source, .rules)
        XCTAssertEqual(result.fallbackReason, .modelUnavailable)
        XCTAssertEqual(result.filters.plan, .coverage(.insurance(.vsp)))
    }

    func testSlowModelTimesOutAndFallsBackToRules() async throws {
        let slow = StubParser(result: .success(FinderFilters()), delayNanoseconds: 2_000_000_000)
        let parser = ResilientFinderParser(primary: slow, timeout: 0.05)

        let result = try await parser.parse("eyemed", context: context)

        XCTAssertEqual(result.source, .rules)
        XCTAssertEqual(result.fallbackReason, .timedOut)
        XCTAssertEqual(result.filters.plan, .coverage(.insurance(.eyeMed)))
    }

    func testModelValuesOutsideTheCatalogAreDiscarded() async throws {
        var invented = FinderFilters()
        invented.area = "Atlantis"
        invented.maxDistanceMiles = 5_000
        let parser = ResilientFinderParser(primary: StubParser(result: .success(invented)))

        let result = try await parser.parse("near Queens within 2 miles", context: context)

        XCTAssertEqual(result.source, .onDeviceModel)
        XCTAssertEqual(result.filters.area, "Queens")
        XCTAssertEqual(result.filters.maxDistanceMiles, 2)
    }

    func testModelCannotDowngradeTriage() async throws {
        var calm = FinderFilters()
        calm.triage = .none
        calm.urgency = .weekday(7)
        let parser = ResilientFinderParser(primary: StubParser(result: .success(calm)))

        let result = try await parser.parse("my dog's eye is bleeding, Saturday", context: context)

        XCTAssertEqual(result.filters.triage, .urgent)
        XCTAssertEqual(result.filters.urgency, .asap)
    }

    func testOverlongQueryIsRejected() async {
        let parser = ResilientFinderParser(primary: nil)
        do {
            _ = try await parser.parse(String(repeating: "eye ", count: 200), context: context)
            XCTFail("Expected queryTooLong")
        } catch {
            XCTAssertEqual(error as? FinderParserError, .queryTooLong)
        }
    }
}

final class FinderModelTests: XCTestCase {
    private func model() -> FinderModel {
        FinderModel(parser: ResilientFinderParser(primary: nil, primaryUnavailableReason: .modelUnavailable))
    }

    @MainActor
    func testSubmitProducesEditableFiltersAndRankedCatalogResults() async {
        let finder = model()
        finder.query = "cloudy eye near Brooklyn"
        let providers = [
            Fixtures.provider(id: "ophth", specialty: .ophthalmology, plans: [.vsp], area: "Brooklyn"),
            Fixtures.provider(id: "optom", specialty: .optometry, plans: [.vsp], area: "Brooklyn"),
        ]

        await finder.submit(knownAreas: ["Brooklyn"], savedCoverage: .insurance(.vsp), now: Fixtures.now)

        XCTAssertEqual(finder.phase, .ready)
        XCTAssertTrue(finder.usedBasicMatching)
        XCTAssertEqual(finder.filters.specialty, .ophthalmology)
        XCTAssertEqual(finder.plan, .coverage(.insurance(.vsp)))
        XCTAssertTrue(finder.planFromSettings)
        XCTAssertEqual(finder.results(from: providers, now: Fixtures.now).map(\.provider.id), ["ophth"])

        finder.filters.specialty = nil
        XCTAssertEqual(Set(finder.results(from: providers, now: Fixtures.now).map(\.provider.id)), ["ophth", "optom"])
    }

    @MainActor
    func testPlanNamedInQueryOverridesSavedCoverage() async {
        let finder = model()
        finder.query = "I have EyeMed"

        await finder.submit(knownAreas: [], savedCoverage: .insurance(.vsp), now: Fixtures.now)

        XCTAssertEqual(finder.plan, .coverage(.insurance(.eyeMed)))
        XCTAssertFalse(finder.planFromSettings)
    }

    @MainActor
    func testOverlongQueryShowsErrorState() async {
        let finder = model()
        finder.query = String(repeating: "cloudy ", count: 100)

        await finder.submit(knownAreas: [], savedCoverage: .selfPay, now: Fixtures.now)

        guard case .failed = finder.phase else { return XCTFail("Expected failed, got \(finder.phase)") }
    }

    @MainActor
    func testClearReturnsToClassicBrowse() async {
        let finder = model()
        finder.query = "VSP"
        await finder.submit(knownAreas: [], savedCoverage: .selfPay, now: Fixtures.now)

        finder.clear()

        XCTAssertEqual(finder.phase, .idle)
        XCTAssertFalse(finder.isActive)
        XCTAssertTrue(finder.results(from: [Fixtures.provider(id: "a")]).isEmpty)
    }

    /// The finder may suggest providers and openings, but only `BookingSheet`'s Confirm button creates a request.
    @MainActor
    func testFinderNeverBooksAutomatically() async throws {
        let defaults = try Fixtures.isolatedDefaults()
        let appointments = AppointmentStore(userDefaults: defaults)
        let finder = model()
        let providers = [Fixtures.provider(id: "ophth", specialty: .ophthalmology, area: "Brooklyn")]

        finder.query = "book the soonest appointment for my dog's cloudy eye in Brooklyn"
        await finder.submit(knownAreas: ["Brooklyn"], savedCoverage: .insurance(.vsp), now: Fixtures.now)
        let results = finder.results(from: providers, now: Fixtures.now)

        XCTAssertNotNil(results.first?.matchingSlot)
        XCTAssertTrue(appointments.requests.isEmpty)
        XCTAssertNil(defaults.data(forKey: AppointmentStore.storageKey))
    }
}
