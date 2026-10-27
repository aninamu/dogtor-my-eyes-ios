import Foundation

enum Specialty: String, Codable, CaseIterable, Identifiable, Hashable {
    case optometry
    case ophthalmology
    case pediatric
    case contactsAndFrames = "contactsAndFrames"
    case lasikConsult = "lasikConsult"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .optometry: return "Optometry"
        case .ophthalmology: return "Ophthalmology"
        case .pediatric: return "Pediatric"
        case .contactsAndFrames: return "Contacts & Frames"
        case .lasikConsult: return "LASIK Consult"
        }
    }

    var systemImage: String {
        switch self {
        case .optometry: return "eyeglasses"
        case .ophthalmology: return "eye.fill"
        case .pediatric: return "figure.and.child.holdinghands"
        case .contactsAndFrames: return "sunglasses"
        case .lasikConsult: return "bolt.circle"
        }
    }
}

enum InsurancePlan: String, Codable, CaseIterable, Identifiable, Hashable {
    case vsp
    case eyeMed
    case davis
    case spectera

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .vsp: return "VSP"
        case .eyeMed: return "EyeMed"
        case .davis: return "Davis Vision"
        case .spectera: return "Spectera"
        }
    }
}

/// How the user pays. Self-pay is not an insurance network, so it never implies in-network status.
enum Coverage: Hashable, Identifiable {
    case insurance(InsurancePlan)
    case selfPay

    static var allCases: [Coverage] {
        InsurancePlan.allCases.map(Coverage.insurance) + [.selfPay]
    }

    init?(rawValue: String) {
        if let plan = InsurancePlan(rawValue: rawValue) {
            self = .insurance(plan)
            return
        }
        switch rawValue {
        // "outOfPocket" is the value stored by builds that modeled self-pay as a plan.
        case "selfPay", "outOfPocket":
            self = .selfPay
        default:
            return nil
        }
    }

    var rawValue: String {
        switch self {
        case .insurance(let plan): return plan.rawValue
        case .selfPay: return "selfPay"
        }
    }

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .insurance(let plan): return plan.displayName
        case .selfPay: return "Self-pay"
        }
    }

    var plan: InsurancePlan? {
        if case .insurance(let plan) = self { return plan }
        return nil
    }
}

extension Coverage: Codable {
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        guard let coverage = Coverage(rawValue: raw) else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unknown coverage \(raw)")
        }
        self = coverage
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

enum NetworkStatus: Equatable {
    case inNetwork
    case outOfNetwork
}

enum ProviderSort: String, CaseIterable, Identifiable {
    case distance
    case rating

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .distance: return "Distance"
        case .rating: return "Rating"
        }
    }
}

struct Provider: Identifiable, Hashable {
    static let defaultClinicTimeZone = TimeZone(identifier: "America/New_York") ?? .current

    let id: String
    let name: String
    let breed: String
    let specialty: Specialty
    let acceptedPlans: [InsurancePlan]
    let acceptsSelfPay: Bool
    let rating: Double
    let reviewCount: Int
    let distanceMiles: Double
    let bio: String
    let services: [String]
    let timeZone: TimeZone
    /// Every generated opening, including ones that may have passed since launch. Use `upcomingSlots(after:)` for display.
    let availableSlots: [Date]
    let avatarColor: String

    init(
        id: String,
        name: String,
        breed: String,
        specialty: Specialty,
        acceptedPlans: [InsurancePlan],
        acceptsSelfPay: Bool = true,
        rating: Double,
        reviewCount: Int,
        distanceMiles: Double,
        bio: String,
        services: [String],
        timeZone: TimeZone = Provider.defaultClinicTimeZone,
        availableSlots: [Date],
        avatarColor: String
    ) {
        self.id = id
        self.name = name
        self.breed = breed
        self.specialty = specialty
        self.acceptedPlans = acceptedPlans
        self.acceptsSelfPay = acceptsSelfPay
        self.rating = rating
        self.reviewCount = reviewCount
        self.distanceMiles = distanceMiles
        self.bio = bio
        self.services = services
        self.timeZone = timeZone
        self.availableSlots = availableSlots
        self.avatarColor = avatarColor
    }

    func isInNetwork(for plan: InsurancePlan) -> Bool {
        acceptedPlans.contains(plan)
    }

    /// `nil` for self-pay: there is no network to be in or out of.
    func networkStatus(for coverage: Coverage) -> NetworkStatus? {
        guard let plan = coverage.plan else { return nil }
        return isInNetwork(for: plan) ? .inNetwork : .outOfNetwork
    }

    func accepts(_ coverage: Coverage) -> Bool {
        switch coverage {
        case .insurance(let plan): return isInNetwork(for: plan)
        case .selfPay: return acceptsSelfPay
        }
    }

    func upcomingSlots(after now: Date) -> [Date] {
        availableSlots.filter { $0 > now }.sorted()
    }

    func isBookable(_ slot: Date, now: Date) -> Bool {
        slot > now && availableSlots.contains(slot)
    }
}
