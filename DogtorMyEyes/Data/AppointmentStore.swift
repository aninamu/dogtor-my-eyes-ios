import Foundation
import Observation

enum AppointmentStatus: String, Codable, Hashable {
    case requested

    var displayName: String {
        switch self {
        case .requested: return "Requested"
        }
    }
}

/// A local-only appointment request. Provider details are snapshotted so the row still renders if the directory changes.
struct AppointmentRequest: Identifiable, Codable, Hashable {
    let id: UUID
    let providerID: String
    let providerName: String
    let specialty: Specialty
    let avatarColor: String
    let slot: Date
    let timeZoneIdentifier: String
    let coverage: Coverage
    let status: AppointmentStatus
    let requestedAt: Date

    var timeZone: TimeZone {
        TimeZone(identifier: timeZoneIdentifier) ?? Provider.defaultClinicTimeZone
    }

    func accessibilityLabel(locale: Locale = .autoupdatingCurrent) -> String {
        let when = SlotFormatter.string(for: slot, in: timeZone, date: .complete, locale: locale)
        return "\(providerName), \(specialty.displayName). \(when). \(coverage.displayName). Status: \(status.displayName)."
    }
}

struct AppointmentSections: Equatable {
    /// Soonest first.
    var upcoming: [AppointmentRequest]
    /// Most recent first.
    var past: [AppointmentRequest]

    var isEmpty: Bool { upcoming.isEmpty && past.isEmpty }
}

enum BookingError: Error, Equatable {
    case slotInPast
    case slotUnavailable
}

@Observable
final class AppointmentStore {
    private(set) var requests: [AppointmentRequest] = []

    @ObservationIgnored private let defaults: UserDefaults?

    /// Pass `nil` for an in-memory store with no persistence.
    init(userDefaults: UserDefaults? = .standard) {
        defaults = userDefaults
        requests = Self.load(from: userDefaults)
    }

    /// The only way a request is created; callers must have an explicit user confirmation before calling it.
    @discardableResult
    func requestAppointment(
        with provider: Provider,
        slot: Date,
        coverage: Coverage,
        now: Date = .now
    ) throws -> AppointmentRequest {
        guard slot > now else { throw BookingError.slotInPast }
        guard provider.availableSlots.contains(slot) else { throw BookingError.slotUnavailable }

        if let existing = requests.first(where: { $0.providerID == provider.id && $0.slot == slot }) {
            return existing
        }

        let request = AppointmentRequest(
            id: UUID(),
            providerID: provider.id,
            providerName: provider.name,
            specialty: provider.specialty,
            avatarColor: provider.avatarColor,
            slot: slot,
            timeZoneIdentifier: provider.timeZone.identifier,
            coverage: coverage,
            status: .requested,
            requestedAt: now
        )
        requests.append(request)
        persist()
        return request
    }

    func sections(now: Date) -> AppointmentSections {
        AppointmentSections(
            upcoming: requests.filter { $0.slot > now }.sorted { $0.slot < $1.slot },
            past: requests.filter { $0.slot <= now }.sorted { $0.slot > $1.slot }
        )
    }

    private func persist() {
        guard let defaults else { return }
        do {
            defaults.set(try Self.encoder.encode(requests), forKey: Self.storageKey)
        } catch {
            AppLog.data.error("Could not save appointment requests: \(type(of: error))")
        }
    }

    private static func load(from defaults: UserDefaults?) -> [AppointmentRequest] {
        guard let data = defaults?.data(forKey: storageKey) else { return [] }
        do {
            let decoded = try decoder.decode(LossyArray<AppointmentRequest>.self, from: data)
            if !decoded.failures.isEmpty {
                AppLog.data.error("Dropped \(decoded.failures.count) unreadable appointment requests")
            }
            return decoded.elements
        } catch {
            AppLog.data.error("Saved appointment requests are unreadable")
            return []
        }
    }

    static let storageKey = "appointmentRequests.v1"

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}
