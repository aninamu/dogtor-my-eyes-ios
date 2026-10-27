import XCTest
@testable import DogtorMyEyes

final class RuleBasedQueryParserTests: XCTestCase {
    private let parser = RuleBasedQueryParser()
    private let areas = ["Brooklyn", "Manhattan", "Queens", "Bronx", "Staten Island"]

    private func parse(_ query: String) -> FinderFilters {
        parser.filters(for: query, knownAreas: areas)
    }

    func testHeadlineQueryMapsToEveryFilter() {
        let filters = parse("my pup's eye is cloudy, I have VSP, near Brooklyn, Saturday")

        XCTAssertEqual(filters.specialty, .ophthalmology)
        XCTAssertEqual(filters.plan, .coverage(.insurance(.vsp)))
        XCTAssertTrue(filters.inNetworkOnly)
        XCTAssertEqual(filters.area, "Brooklyn")
        XCTAssertEqual(filters.urgency, .weekday(7))
        XCTAssertEqual(filters.triage, .symptom)
        XCTAssertEqual(filters.confidence, .confident)
    }

    func testPupDoesNotImplyPediatricButPuppyDoes() {
        XCTAssertNotEqual(parse("my pup needs an eye exam").specialty, .pediatric)
        XCTAssertEqual(parse("my puppy needs an eye exam").specialty, .pediatric)
    }

    func testUrgentInputsAlwaysForceSoonest() {
        for query in ["sudden blindness", "she can't see anything", "eye injury", "bleeding from the eye", "severe pain", "it's an emergency, Saturday"] {
            let filters = parse(query)
            XCTAssertEqual(filters.triage, .urgent, query)
            XCTAssertEqual(filters.urgency, .asap, query)
        }
    }

    func testBloodshotIsASymptomNotAnEmergency() {
        XCTAssertEqual(parse("bloodshot eyes").triage, .symptom)
    }

    func testUnsupportedPlanIsKeptByName() {
        XCTAssertEqual(parse("I have Cigna").plan, .unsupported("Cigna"))
    }

    func testSupportedPlanWinsOverSelfPayMention() {
        XCTAssertEqual(parse("VSP or cash").plan, .coverage(.insurance(.vsp)))
    }

    func testUnknownAreaIsIgnored() {
        XCTAssertNil(parse("near Hoboken").area)
    }

    func testAreaAliasRequiresTheBoroughToBeInTheCatalog() {
        XCTAssertEqual(parser.filters(for: "park slope", knownAreas: areas).area, "Brooklyn")
        XCTAssertNil(parser.filters(for: "park slope", knownAreas: ["Queens"]).area)
    }

    func testTokenizerFoldsAccentsAndKeepsDecimals() {
        XCTAssertEqual(RuleBasedQueryParser.tokenize("Sábado, 2.5 mi. ¡Ojo!"), ["sabado", "2.5", "mi", "ojo"])
    }

    func testEditDistanceCountsTranspositionsAsOne() {
        XCTAssertEqual(TokenText.editDistance("satruday", "saturday"), 1)
        XCTAssertEqual(TokenText.editDistance("brooklin", "brooklyn"), 1)
        XCTAssertEqual(TokenText.editDistance("", "abc"), 3)
    }

    func testShortWordsAreNotFuzzyMatched() {
        XCTAssertNil(parse("davos").plan)
        XCTAssertEqual(parse("davis").plan, .coverage(.insurance(.davis)))
    }

    func testEmptyQueryThrows() async {
        do {
            _ = try await parser.parse("   ", context: FinderParseContext(knownAreas: areas, now: Fixtures.now))
            XCTFail("Expected emptyQuery")
        } catch {
            XCTAssertEqual(error as? FinderParserError, .emptyQuery)
        }
    }

    func testUrgencyTokensRoundTrip() {
        for urgency in FinderUrgency.allCases {
            XCTAssertEqual(FinderUrgency(token: urgency.token), urgency)
        }
    }
}
