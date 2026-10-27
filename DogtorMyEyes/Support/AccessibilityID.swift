import Foundation

/// Stable identifiers for UI automation. Changing one breaks QA scripts, so treat these as API.
enum AccessibilityID {
    enum Browse {
        static let planPicker = "browse.planPicker"
        static let inNetworkToggle = "browse.inNetworkToggle"
        static let sortPicker = "browse.sortPicker"
        static let allSpecialtiesChip = "browse.specialty.all"
        static func specialtyChip(_ specialty: Specialty) -> String { "browse.specialty.\(specialty.rawValue)" }
        static let resultsHeader = "browse.resultsHeader"
    }

    enum ProviderRow {
        static func row(_ providerID: String) -> String { "providerRow.\(providerID)" }
        static func favorite(_ providerID: String) -> String { "providerRow.favorite.\(providerID)" }
    }

    enum Detail {
        static let favorite = "detail.favorite"
        static let requestAppointment = "detail.requestAppointment"
        static let noOpenings = "detail.noOpenings"
    }

    enum Booking {
        static func slot(_ index: Int) -> String { "booking.slot.\(index)" }
        static let confirm = "booking.confirm"
        static let cancel = "booking.cancel"
        static let noOpenings = "booking.noOpenings"
        static let error = "booking.error"
    }

    enum Finder {
        static let searchField = "finder.searchField"
        static let clear = "finder.clear"
        static let retry = "finder.retry"
        static let status = "finder.status"
        static let triageNotice = "finder.triageNotice"
        static let resultsHeader = "finder.resultsHeader"
        static func chip(_ name: String) -> String { "finder.chip.\(name)" }
        static func matchReason(_ providerID: String) -> String { "finder.reason.\(providerID)" }
    }

    enum Appointments {
        static let list = "appointments.list"
        static let emptyBrowse = "appointments.empty.browse"
        static func row(_ id: UUID) -> String { "appointments.row.\(id.uuidString)" }
    }
}
