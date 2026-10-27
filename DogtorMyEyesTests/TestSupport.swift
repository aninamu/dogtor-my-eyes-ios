import Foundation
import XCTest
@testable import DogtorMyEyes

enum Fixtures {
    /// Tuesday, Oct 27, 2026 at 13:14 UTC (09:14 in New York).
    static let now = Date(timeIntervalSince1970: 1_793_106_840)

    static let newYork = TimeZone(identifier: "America/New_York") ?? .current

    static func provider(
        id: String,
        name: String? = nil,
        breed: String = "Beagle",
        specialty: Specialty = .optometry,
        plans: [InsurancePlan] = [.vsp],
        acceptsSelfPay: Bool = true,
        rating: Double = 4.5,
        reviewCount: Int = 10,
        distance: Double = 1.0,
        area: String = "Brooklyn",
        slots: [Date]? = nil
    ) -> Provider {
        Provider(
            id: id,
            name: name ?? "Dr. \(id)",
            breed: breed,
            specialty: specialty,
            acceptedPlans: plans,
            acceptsSelfPay: acceptsSelfPay,
            rating: rating,
            reviewCount: reviewCount,
            distanceMiles: distance,
            area: area,
            bio: "Fictional test dogtor",
            services: ["Exam"],
            timeZone: newYork,
            availableSlots: slots ?? [now.addingTimeInterval(3_600), now.addingTimeInterval(86_400)],
            avatarColor: "C4A35A"
        )
    }

    static func isolatedDefaults(file: StaticString = #filePath, line: UInt = #line) throws -> UserDefaults {
        let name = "DogtorMyEyesTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name), file: file, line: line)
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    static func bundledProvidersJSON() throws -> Data {
        let candidates = [
            Bundle(for: BundleToken.self).url(forResource: "providers", withExtension: "json"),
            Bundle.main.url(forResource: "providers", withExtension: "json"),
            URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .appendingPathComponent("DogtorMyEyes/Data/providers.json"),
        ]
        let url = try XCTUnwrap(candidates.compactMap { $0 }.first { FileManager.default.fileExists(atPath: $0.path) })
        return try Data(contentsOf: url)
    }

    private final class BundleToken {}
}
