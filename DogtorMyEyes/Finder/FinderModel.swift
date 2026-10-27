import Foundation
import Observation

/// State for the natural-language finder on Browse. It only ever produces filters and a ranked view of the
/// catalog; booking still requires the user to pick a slot and tap Confirm in `BookingSheet`.
@Observable
final class FinderModel {
    enum Phase: Equatable {
        case idle
        case parsing
        case ready
        case failed(String)
    }

    var query = ""
    private(set) var phase: Phase = .idle
    /// What was understood. Chips edit this directly.
    var filters = FinderFilters()
    /// The plan chip's value; falls back to the user's saved coverage when the query didn't name one.
    var plan: PlanUnderstanding?
    private(set) var planFromSettings = false
    private(set) var source: FinderParserSource = .rules
    private(set) var fallbackReason: FinderFallbackReason?

    @ObservationIgnored private let parser: ResilientFinderParser
    @ObservationIgnored private var generation = 0

    init(parser: ResilientFinderParser) {
        self.parser = parser
    }

    var isActive: Bool { phase != .idle }

    /// True when the model was skipped or failed and the keyword rules produced the filters.
    var usedBasicMatching: Bool { phase == .ready && source == .rules }

    @MainActor
    func submit(knownAreas: [String], savedCoverage: Coverage, now: Date = .now) async {
        let text = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            clear()
            return
        }

        generation += 1
        let current = generation
        phase = .parsing

        do {
            let result = try await parser.parse(text, context: FinderParseContext(knownAreas: knownAreas, now: now))
            guard current == generation else { return }
            filters = result.filters
            if let understood = result.filters.plan {
                plan = understood
                planFromSettings = false
            } else {
                plan = .coverage(savedCoverage)
                planFromSettings = true
            }
            source = result.source
            fallbackReason = result.fallbackReason
            phase = .ready
        } catch FinderParserError.queryTooLong {
            guard current == generation else { return }
            phase = .failed("That’s a lot to read. Try a shorter description, like “cloudy eye, VSP, Brooklyn, Saturday.”")
        } catch {
            guard current == generation else { return }
            phase = .failed("Something went wrong reading that. Try rephrasing, or use the filters below.")
        }
    }

    func clear() {
        generation += 1
        query = ""
        filters = FinderFilters()
        plan = nil
        planFromSettings = false
        fallbackReason = nil
        phase = .idle
    }

    func setPlan(_ newPlan: PlanUnderstanding?) {
        plan = newPlan
        planFromSettings = false
    }

    func results(from providers: [Provider], now: Date = .now) -> [FinderMatch] {
        guard phase == .ready else { return [] }
        return FinderRanker.rank(providers, filters: filters, plan: plan, now: now)
    }
}
