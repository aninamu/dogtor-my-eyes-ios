import XCTest
@testable import DogtorMyEyes

final class ProviderCatalogTests: XCTestCase {
    private func record(id: String, specialty: String = "optometry", plans: String = #"["vsp"]"#, extra: String = "") -> String {
        """
        {"id": "\(id)", "name": "Dr. \(id)", "breed": "Corgi", "specialty": "\(specialty)",
         "acceptedPlans": \(plans), "rating": 4.2, "reviewCount": 3, "distanceMiles": 1.5,
         "bio": "Fictional", "services": ["Exam"], "timeZone": "America/New_York",
         "slotTemplates": [{"dayOffset": 1, "hour": 10, "minute": 0}], "avatarColor": "C4A35A"\(extra)}
        """
    }

    func testBundledProvidersJSONDecodesWithoutSkipping() throws {
        let catalog = ProviderCatalog.decode(try Fixtures.bundledProvidersJSON(), now: Fixtures.now)

        XCTAssertNil(catalog.errorMessage)
        XCTAssertEqual(catalog.skippedRecordCount, 0)
        XCTAssertFalse(catalog.providers.isEmpty)
        XCTAssertTrue(catalog.providers.allSatisfy { !$0.name.isEmpty })
        XCTAssertTrue(catalog.providers.contains { $0.specialty == .lasikConsult })
        XCTAssertTrue(catalog.providers.contains { $0.acceptedPlans.contains(.vsp) })
        XCTAssertEqual(Set(catalog.providers.map(\.id)).count, catalog.providers.count, "IDs must be unique")
    }

    func testMalformedRecordIsSkippedAndOthersSurvive() {
        let json = "[\(record(id: "good-1")), \(record(id: "bad", specialty: "astrology")), {\"id\": 7}, \(record(id: "good-2"))]"

        let catalog = ProviderCatalog.decode(Data(json.utf8), now: Fixtures.now)

        XCTAssertEqual(catalog.providers.map(\.id), ["good-1", "good-2"])
        XCTAssertEqual(catalog.skippedRecordCount, 2)
        XCTAssertNil(catalog.errorMessage)
    }

    func testUnknownPlanValuesAreDroppedNotFatal() {
        let json = "[\(record(id: "p", plans: #"["vsp", "aetna", "outOfPocket", "eyeMed"]"#))]"

        let catalog = ProviderCatalog.decode(Data(json.utf8), now: Fixtures.now)

        XCTAssertEqual(catalog.providers.first?.acceptedPlans, [.vsp, .eyeMed])
    }

    func testOptionalFieldsDefault() {
        let json = """
        [{"id": "min", "name": "Dr. Min", "breed": "Pug", "specialty": "pediatric",
          "rating": 4.0, "reviewCount": 1, "distanceMiles": 2.0}]
        """

        let provider = ProviderCatalog.decode(Data(json.utf8), now: Fixtures.now).providers.first

        XCTAssertEqual(provider?.acceptedPlans, [])
        XCTAssertEqual(provider?.acceptsSelfPay, true)
        XCTAssertEqual(provider?.timeZone, Provider.defaultClinicTimeZone)
        XCTAssertEqual(provider?.availableSlots, [])
    }

    func testUnreadableFileProducesFriendlyError() {
        let catalog = ProviderCatalog.decode(Data("not json".utf8), now: Fixtures.now)

        XCTAssertTrue(catalog.providers.isEmpty)
        XCTAssertNotNil(catalog.errorMessage)
        XCTAssertFalse(catalog.errorMessage?.contains("DecodingError") ?? true)
    }

    func testEmptyDirectoryIsReportedAsAnError() {
        let catalog = ProviderCatalog.decode(Data("[]".utf8), now: Fixtures.now)

        XCTAssertTrue(catalog.providers.isEmpty)
        XCTAssertNotNil(catalog.errorMessage)
    }
}
