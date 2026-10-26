import Foundation
import SwiftUI

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
    case outOfPocket

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .vsp: return "VSP"
        case .eyeMed: return "EyeMed"
        case .davis: return "Davis Vision"
        case .spectera: return "Spectera"
        case .outOfPocket: return "Out of Pocket"
        }
    }
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

struct Provider: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let breed: String
    let specialty: Specialty
    let acceptedPlans: [InsurancePlan]
    let rating: Double
    let reviewCount: Int
    let distanceMiles: Double
    let bio: String
    let services: [String]
    let nextAvailable: [Date]
    let avatarColor: String

    func isInNetwork(for plan: InsurancePlan) -> Bool {
        if plan == .outOfPocket { return true }
        return acceptedPlans.contains(plan)
    }

    var color: Color {
        Color(hex: avatarColor) ?? Theme.teal
    }
}

extension Color {
    init?(hex: String) {
        var cleaned = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.hasPrefix("#") {
            cleaned.removeFirst()
        }
        guard cleaned.count == 6, let value = UInt64(cleaned, radix: 16) else {
            return nil
        }
        let r = Double((value >> 16) & 0xFF) / 255
        let g = Double((value >> 8) & 0xFF) / 255
        let b = Double(value & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}
