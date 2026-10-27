import XCTest
@testable import DogtorMyEyes

/// Runs the rule-based parser against `Fixtures/finder_eval.json` and reports every mismatch per case.
final class FinderEvalTests: XCTestCase {
    private struct EvalFile: Decodable {
        let version: Int
        let cases: [EvalCase]
    }

    private struct EvalCase: Decodable {
        let id: String
        let tags: [String]
        let query: String
        let expect: [String: JSONValue]
        let expectTopResult: TopResult?
    }

    private struct TopResult: Decodable {
        let providerID: String
        let reasonContains: String
    }

    private enum JSONValue: Decodable, Equatable {
        case string(String)
        case number(Double)
        case bool(Bool)
        case null

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            if container.decodeNil() { self = .null }
            else if let bool = try? container.decode(Bool.self) { self = .bool(bool) }
            else if let number = try? container.decode(Double.self) { self = .number(number) }
            else { self = .string(try container.decode(String.self)) }
        }
    }

    private static let knownKeys: Set<String> = [
        "specialty", "plan", "planName", "inNetworkOnly", "area", "maxDistanceMiles", "prefersNearby", "urgency", "triage",
        "confidence",
    ]

    private func loadFixture() throws -> EvalFile {
        let url = Bundle(for: FinderEvalTests.self).url(forResource: "finder_eval", withExtension: "json")
            ?? URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("Fixtures/finder_eval.json")
        return try JSONDecoder().decode(EvalFile.self, from: Data(contentsOf: url))
    }

    private func actualValue(_ key: String, _ filters: FinderFilters) -> JSONValue {
        switch key {
        case "specialty": return filters.specialty.map { .string($0.rawValue) } ?? .null
        case "plan": return filters.plan.map { .string($0.token) } ?? .null
        case "planName": return filters.plan.map { .string($0.displayName) } ?? .null
        case "inNetworkOnly": return .bool(filters.inNetworkOnly)
        case "area": return filters.area.map(JSONValue.string) ?? .null
        case "maxDistanceMiles": return filters.maxDistanceMiles.map(JSONValue.number) ?? .null
        case "prefersNearby": return .bool(filters.prefersNearby)
        case "urgency": return .string(filters.urgency.token)
        case "triage": return .string(filters.triage.rawValue)
        case "confidence": return .string(filters.confidence.rawValue)
        default: return .null
        }
    }

    func testFixtureIsWellFormed() throws {
        let fixture = try loadFixture()

        XCTAssertGreaterThanOrEqual(fixture.cases.count, 30)
        XCTAssertEqual(Set(fixture.cases.map(\.id)).count, fixture.cases.count, "Case IDs must be unique")
        for tag in ["out-of-network-plan", "no-slots", "vague", "urgent", "non-english", "misspelled"] {
            XCTAssertTrue(fixture.cases.contains { $0.tags.contains(tag) }, "No case covers \(tag)")
        }
        for evalCase in fixture.cases {
            XCTAssertNotNil(evalCase.expect["triage"], "\(evalCase.id) must assert triage")
            XCTAssertTrue(Set(evalCase.expect.keys).isSubset(of: Self.knownKeys), "\(evalCase.id) has unknown keys")
        }
    }

    func testRuleParserMatchesEveryFixtureCase() throws {
        let fixture = try loadFixture()
        let catalog = ProviderCatalog.decode(try Fixtures.bundledProvidersJSON(), now: Fixtures.now)
        let areas = Array(Set(catalog.providers.map(\.area))).sorted()
        let parser = RuleBasedQueryParser()
        var failures: [String] = []

        for evalCase in fixture.cases {
            let filters = parser.filters(for: evalCase.query, knownAreas: areas)
            for (key, expected) in evalCase.expect.sorted(by: { $0.key < $1.key }) {
                let actual = actualValue(key, filters)
                if case .number(let want) = expected, case .number(let got) = actual {
                    if abs(want - got) > 0.05 { failures.append("\(evalCase.id).\(key): expected \(want), got \(got)") }
                } else if actual != expected {
                    failures.append("\(evalCase.id).\(key): expected \(expected), got \(actual)")
                }
            }

            if let top = evalCase.expectTopResult {
                let results = FinderRanker.rank(catalog.providers, filters: filters, plan: filters.plan, now: Fixtures.now)
                if results.first?.provider.id != top.providerID {
                    failures.append("\(evalCase.id): top result \(results.first?.provider.id ?? "none"), expected \(top.providerID)")
                } else if results.first?.reason.contains(top.reasonContains) != true {
                    failures.append("\(evalCase.id): reason \"\(results.first?.reason ?? "")\" lacks \"\(top.reasonContains)\"")
                }
            }
        }

        XCTAssertTrue(failures.isEmpty, "\(failures.count) eval mismatches:\n" + failures.joined(separator: "\n"))
    }
}
