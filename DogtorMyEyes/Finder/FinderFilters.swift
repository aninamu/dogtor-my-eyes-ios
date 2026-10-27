import Foundation

/// The "Urgency" chip: how soon, or on which day, the user wants to be seen.
enum FinderUrgency: Hashable, Sendable {
    case anyTime
    case asap
    case today
    case tomorrow
    case weekend
    /// `Calendar` weekday number: 1 = Sunday … 7 = Saturday.
    case weekday(Int)

    static let weekdayNames = ["sunday", "monday", "tuesday", "wednesday", "thursday", "friday", "saturday"]

    static var allCases: [FinderUrgency] {
        [.anyTime, .asap, .today, .tomorrow, .weekend] + (1...7).map(FinderUrgency.weekday)
    }

    /// Stable string form used by the eval fixture and the model schema.
    init?(token: String) {
        switch token {
        case "any": self = .anyTime
        case "asap": self = .asap
        case "today": self = .today
        case "tomorrow": self = .tomorrow
        case "weekend": self = .weekend
        default:
            guard let index = Self.weekdayNames.firstIndex(of: token) else { return nil }
            self = .weekday(index + 1)
        }
    }

    var token: String {
        switch self {
        case .anyTime: return "any"
        case .asap: return "asap"
        case .today: return "today"
        case .tomorrow: return "tomorrow"
        case .weekend: return "weekend"
        case .weekday(let day): return Self.weekdayNames[((day - 1) % 7 + 7) % 7]
        }
    }

    var displayName: String {
        switch self {
        case .anyTime: return "Any time"
        case .asap: return "Soonest"
        case .today: return "Today"
        case .tomorrow: return "Tomorrow"
        case .weekend: return "This weekend"
        case .weekday: return token.capitalized
        }
    }

    var noOpeningsText: String {
        switch self {
        case .anyTime, .asap: return "No upcoming openings"
        case .today: return "No openings today"
        case .tomorrow: return "No openings tomorrow"
        case .weekend: return "No weekend openings"
        case .weekday: return "No \(displayName) openings"
        }
    }
}

enum Triage: String, Hashable, Sendable, Comparable {
    static func < (lhs: Triage, rhs: Triage) -> Bool {
        lhs.severity < rhs.severity
    }

    private var severity: Int {
        switch self {
        case .none: return 0
        case .symptom: return 1
        case .urgent: return 2
        }
    }

    case none
    /// An eye symptom was described: show the persistent "not a diagnosis" note.
    case symptom
    /// Red-flag wording (sudden blindness, injury, bleeding, severe pain): show urgent-care guidance first.
    case urgent
}

/// The "Plan" chip. Unsupported insurers are kept so the user sees we understood them but have no network data.
enum PlanUnderstanding: Hashable, Sendable {
    case coverage(Coverage)
    case unsupported(String)

    var displayName: String {
        switch self {
        case .coverage(let coverage): return coverage.displayName
        case .unsupported(let name): return name
        }
    }

    var token: String {
        switch self {
        case .coverage(let coverage): return coverage.rawValue
        case .unsupported: return "unsupported"
        }
    }
}

enum FinderConfidence: String, Hashable, Sendable {
    case confident
    case notSure
}

/// Structured filter values understood from a query. This is the only thing a parser may produce:
/// providers, coverage, and openings always come from the catalog.
struct FinderFilters: Hashable, Sendable {
    var specialty: Specialty?
    var plan: PlanUnderstanding?
    var inNetworkOnly: Bool = true
    var area: String?
    var maxDistanceMiles: Double?
    var prefersNearby: Bool = false
    var urgency: FinderUrgency = .anyTime
    var triage: Triage = .none

    var hasNearPreference: Bool {
        area != nil || maxDistanceMiles != nil || prefersNearby
    }

    var confidence: FinderConfidence {
        let understoodSomething = specialty != nil || plan != nil || hasNearPreference
            || urgency != .anyTime || triage != .none
        return understoodSomething ? .confident : .notSure
    }

    var nearDisplayName: String {
        var parts: [String] = []
        if let area { parts.append(area) }
        if let maxDistanceMiles { parts.append("≤ \(Self.milesText(maxDistanceMiles)) mi") }
        if parts.isEmpty && prefersNearby { parts.append("Nearby") }
        return parts.isEmpty ? "Anywhere" : parts.joined(separator: " · ")
    }

    static func milesText(_ miles: Double) -> String {
        miles.rounded() == miles ? String(Int(miles)) : String(format: "%.1f", miles)
    }
}

enum FinderParserSource: String, Sendable {
    case onDeviceModel
    case rules
}

enum FinderFallbackReason: String, Sendable {
    case disabled
    case modelUnavailable
    case timedOut
    case failed
}

struct FinderParseResult: Equatable, Sendable {
    var filters: FinderFilters
    var source: FinderParserSource
    var fallbackReason: FinderFallbackReason?
}

struct FinderParseContext: Sendable {
    /// Areas present in the catalog. A parser may only return one of these.
    var knownAreas: [String]
    var now: Date
}

enum FinderParserError: Error, Equatable {
    case emptyQuery
    case queryTooLong
    case modelUnavailable
    case timedOut
}
