import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

enum FinderParserFactory {
    /// The on-device model is used only when the flag allows it, the SDK has Foundation Models, the OS is
    /// iOS 26+, and Apple Intelligence is ready on this device. Otherwise the rules handle every query.
    static func make(flags: FeatureFlags) -> ResilientFinderParser {
        guard flags.isEnabled(.finderOnDeviceModel) else {
            return ResilientFinderParser(primary: nil, primaryUnavailableReason: .disabled)
        }
        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, *) {
            if FoundationModelsQueryParser.isAvailable {
                return ResilientFinderParser(primary: FoundationModelsQueryParser())
            }
        }
        #endif
        return ResilientFinderParser(primary: nil, primaryUnavailableReason: .modelUnavailable)
    }
}

#if canImport(FoundationModels)
@available(iOS 26.0, macOS 26.0, *)
@Generable
struct GeneratedFinderFilters {
    @Guide(description: "Eye-care specialty: optometry, ophthalmology, pediatric, contactsAndFrames, lasikConsult, or none. Map symptoms such as cloudy, red, swollen, or squinting eyes to ophthalmology; puppies to pediatric; glasses or goggles to contactsAndFrames.")
    var specialty: String

    @Guide(description: "Vision plan the user says they have: vsp, eyeMed, davis, spectera, selfPay (no insurance or paying cash), other (any other insurer), or none if not mentioned.")
    var plan: String

    @Guide(description: "If plan is other, the insurer name as written by the user; otherwise empty.")
    var otherPlanName: String

    @Guide(description: "Borough or area the user wants to be near, copied from the allowed list, or empty.")
    var area: String

    @Guide(description: "Maximum distance in miles if the user gave one, otherwise 0.")
    var maxDistanceMiles: Double

    @Guide(description: "True if the user asked for something near them or the closest option.")
    var prefersNearby: Bool

    @Guide(description: "When they want to be seen: any, asap, today, tomorrow, weekend, sunday, monday, tuesday, wednesday, thursday, friday, or saturday.")
    var timing: String

    @Guide(description: "False only if the user said out-of-network providers are fine.")
    var inNetworkOnly: Bool

    @Guide(description: "True if the user describes any eye symptom.")
    var symptomMentioned: Bool

    @Guide(description: "True if the user mentions sudden blindness, injury, bleeding, severe pain, or an emergency.")
    var soundsUrgent: Bool
}

@available(iOS 26.0, macOS 26.0, *)
struct FoundationModelsQueryParser: FinderQueryParser {
    static var isAvailable: Bool {
        if case .available = SystemLanguageModel.default.availability {
            return true
        }
        return false
    }

    func parse(_ query: String, context: FinderParseContext) async throws -> FinderFilters {
        guard Self.isAvailable else { throw FinderParserError.modelUnavailable }

        let session = LanguageModelSession(instructions: Self.instructions(knownAreas: context.knownAreas))
        let response = try await session.respond(to: query, generating: GeneratedFinderFilters.self)
        return Self.filters(from: response.content, knownAreas: context.knownAreas)
    }

    private static func instructions(knownAreas: [String]) -> String {
        """
        You convert a pet owner's request about their dog's eyes into search filter values for a directory of \
        eye-care providers. Only fill in the fields. Never name providers, never state coverage or availability, \
        and never give medical advice. The request may be in any language or misspelled. \
        Allowed areas: \(knownAreas.joined(separator: ", ")).
        """
    }

    /// Anything outside the app's vocabulary is discarded rather than trusted.
    static func filters(from generated: GeneratedFinderFilters, knownAreas: [String]) -> FinderFilters {
        var filters = FinderFilters()
        filters.specialty = Specialty(rawValue: generated.specialty)

        switch generated.plan {
        case "other":
            let name = generated.otherPlanName.trimmingCharacters(in: .whitespacesAndNewlines)
            filters.plan = name.isEmpty ? nil : .unsupported(String(name.prefix(40)))
        default:
            filters.plan = Coverage(rawValue: generated.plan).map(PlanUnderstanding.coverage)
        }

        filters.area = knownAreas.first { $0.caseInsensitiveCompare(generated.area) == .orderedSame }
        filters.maxDistanceMiles = generated.maxDistanceMiles > 0 ? generated.maxDistanceMiles : nil
        filters.prefersNearby = generated.prefersNearby
        filters.urgency = FinderUrgency(token: generated.timing.lowercased()) ?? .anyTime
        filters.inNetworkOnly = generated.inNetworkOnly
        filters.triage = generated.soundsUrgent ? .urgent : (generated.symptomMentioned ? .symptom : .none)
        return filters
    }
}
#endif
