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
    /// What was understood. Edit through the `set…` methods so a chip the user touched stops looking guessed.
    private(set) var filters = FinderFilters()
    /// The plan chip's value; falls back to the user's saved coverage when the query didn't name one.
    private(set) var plan: PlanUnderstanding?
    private(set) var planFromSettings = false
    private(set) var source: FinderParserSource = .rules
    private(set) var fallbackReason: FinderFallbackReason?
    /// Increments each time a query is parsed, so observers can tell a new answer from a chip edit.
    private(set) var parseCount = 0
    /// The clarify prompt is asked at most once per query.
    private(set) var clarifyResolved = false

    @ObservationIgnored private let parser: ResilientFinderParser
    @ObservationIgnored private var generation = 0
    @ObservationIgnored private var submittedQuery = ""

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
                filters.guessed.insert(.plan)
            }
            source = result.source
            fallbackReason = result.fallbackReason
            submittedQuery = text
            clarifyResolved = false
            parseCount += 1
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
        submittedQuery = ""
        filters = FinderFilters()
        plan = nil
        planFromSettings = false
        fallbackReason = nil
        clarifyResolved = false
        phase = .idle
    }

    // MARK: - Chip edits (each one confirms its chip)

    func setSpecialty(_ specialty: Specialty?) {
        filters.specialty = specialty
        filters.guessed.remove(.specialty)
    }

    func setPlan(_ newPlan: PlanUnderstanding?) {
        plan = newPlan
        planFromSettings = false
        filters.guessed.remove(.plan)
    }

    func setInNetworkOnly(_ inNetworkOnly: Bool) {
        filters.inNetworkOnly = inNetworkOnly
        filters.guessed.remove(.plan)
    }

    func setNear(area: String?, maxDistanceMiles: Double?, prefersNearby: Bool = false) {
        filters.area = area
        filters.maxDistanceMiles = maxDistanceMiles
        filters.prefersNearby = prefersNearby
        filters.guessed.remove(.near)
    }

    func setUrgency(_ urgency: FinderUrgency) {
        filters.urgency = urgency
        filters.guessed.remove(.urgency)
    }

    // MARK: - Clarify prompt

    var clarifyQuestion: ClarifyQuestion? {
        guard phase == .ready, !clarifyResolved else { return nil }
        return ClarifyQuestion.make(filters: filters, plan: plan, planFromSettings: planFromSettings)
    }

    func answer(_ answer: ClarifyAnswer) {
        switch answer.action {
        case .specialty(let specialty): setSpecialty(specialty)
        case .plan(let plan): setPlan(plan)
        case .near(let area): setNear(area: area, maxDistanceMiles: area == nil ? nil : filters.maxDistanceMiles)
        case .urgency(let urgency): setUrgency(urgency)
        }
        clarifyResolved = true
    }

    func dismissClarify() {
        clarifyResolved = true
    }

    // MARK: - Results

    func results(from providers: [Provider], now: Date = .now) -> [FinderMatch] {
        guard phase == .ready else { return [] }
        var pool = providers
        var hits: [String: String] = [:]
        if filters.confidence == .notSure {
            hits = FinderRanker.keywordHits(in: providers, query: submittedQuery)
            if !hits.isEmpty {
                pool = providers.filter { hits[$0.id] != nil }
            }
        }
        return FinderRanker.rank(pool, filters: filters, plan: plan, now: now, keywordHits: hits)
    }

    func relaxation(for providers: [Provider]) -> FinderRelaxation? {
        guard phase == .ready else { return nil }
        return FinderRanker.relaxation(for: providers, filters: filters, plan: plan)
    }

    func relax(_ relaxation: FinderRelaxation) {
        switch relaxation.change {
        case .clearNear: setNear(area: nil, maxDistanceMiles: nil, prefersNearby: filters.prefersNearby)
        case .clearSpecialty: setSpecialty(nil)
        case .includeOutOfNetwork: setInNetworkOnly(false)
        case .anyPlan: setPlan(nil)
        }
    }

    /// What VoiceOver should say after results change. The fallback note is only added for a fresh parse.
    func announcement(matchCount: Int, isNewParse: Bool) -> String? {
        guard phase == .ready else { return nil }
        let count: String
        switch matchCount {
        case 0: count = "No matches"
        case 1: count = "1 match"
        default: count = "\(matchCount) matches"
        }
        guard isNewParse, usedBasicMatching else { return count }
        switch fallbackReason {
        case .modelUnavailable?: return "\(count). Smart matching isn’t available, so keyword matching is on."
        case .timedOut?: return "\(count). Smart matching took too long, so keyword matching is on."
        case .failed?: return "\(count). Smart matching hit a problem, so keyword matching is on."
        case .disabled?, nil: return count
        }
    }
}

// MARK: - Clarify

enum ClarifyAction: Equatable {
    case specialty(Specialty?)
    case plan(PlanUnderstanding?)
    case near(String?)
    case urgency(FinderUrgency)
}

struct ClarifyAnswer: Identifiable, Equatable {
    let title: String
    let action: ClarifyAction

    var id: String { title }
}

/// One question about the most important uncertain slot, with tappable answers.
struct ClarifyQuestion: Equatable {
    let slot: FinderSlot
    let prompt: String
    let answers: [ClarifyAnswer]

    /// Priority: what the dog needs, then how they pay, then where, then when.
    /// Urgent requests are never slowed down with a question.
    static func make(filters: FinderFilters, plan: PlanUnderstanding?, planFromSettings: Bool) -> ClarifyQuestion? {
        guard filters.triage != .urgent else { return nil }

        if filters.specialty == nil && filters.confidence == .notSure {
            return ClarifyQuestion(
                slot: .specialty,
                prompt: "What does your dog need?",
                answers: [
                    ClarifyAnswer(title: "Eye problem", action: .specialty(.ophthalmology)),
                    ClarifyAnswer(title: "Routine exam", action: .specialty(.optometry)),
                    ClarifyAnswer(title: "Glasses or goggles", action: .specialty(.contactsAndFrames)),
                    ClarifyAnswer(title: "Puppy eye care", action: .specialty(.pediatric)),
                    ClarifyAnswer(title: "LASIK consult", action: .specialty(.lasikConsult)),
                ]
            )
        }

        if filters.guessed.contains(.specialty), let specialty = filters.specialty {
            var answers = [ClarifyAnswer(title: "Yes, \(specialty.displayName)", action: .specialty(specialty))]
            if specialty != .optometry {
                answers.append(ClarifyAnswer(title: "Routine exam instead", action: .specialty(.optometry)))
            }
            answers.append(ClarifyAnswer(title: "Any specialty", action: .specialty(nil)))
            return ClarifyQuestion(slot: .specialty, prompt: "Sounds like \(specialty.displayName). Is that right?", answers: answers)
        }

        if case .unsupported(let name)? = plan {
            return ClarifyQuestion(
                slot: .plan,
                prompt: "There’s no network data for \(name). Check another plan instead?",
                answers: otherPlanAnswers(excluding: nil) + [ClarifyAnswer(title: "Keep \(name)", action: .plan(plan))]
            )
        }

        if filters.guessed.contains(.plan), case .coverage(let coverage)? = plan {
            let prompt = planFromSettings
                ? "No plan mentioned, so I used \(coverage.displayName) from your settings. Still right?"
                : "Did you mean \(coverage.displayName)?"
            return ClarifyQuestion(
                slot: .plan,
                prompt: prompt,
                answers: [ClarifyAnswer(title: "Yes, \(coverage.displayName)", action: .plan(plan))]
                    + otherPlanAnswers(excluding: coverage)
            )
        }

        if filters.guessed.contains(.near), let area = filters.area {
            return ClarifyQuestion(
                slot: .near,
                prompt: "Did you mean near \(area)?",
                answers: [
                    ClarifyAnswer(title: "Yes, \(area)", action: .near(area)),
                    ClarifyAnswer(title: "Anywhere", action: .near(nil)),
                ]
            )
        }

        if filters.guessed.contains(.urgency), filters.urgency != .anyTime {
            return ClarifyQuestion(
                slot: .urgency,
                prompt: "Did you mean \(urgencyPhrase(filters.urgency))?",
                answers: [
                    ClarifyAnswer(title: "Yes, \(filters.urgency.displayName)", action: .urgency(filters.urgency)),
                    ClarifyAnswer(title: "Any time", action: .urgency(.anyTime)),
                ]
            )
        }

        return nil
    }

    private static func urgencyPhrase(_ urgency: FinderUrgency) -> String {
        if case .weekday = urgency { return urgency.displayName }
        return urgency.displayName.lowercased()
    }

    private static func otherPlanAnswers(excluding current: Coverage?) -> [ClarifyAnswer] {
        Coverage.allCases
            .filter { $0 != current }
            .map { ClarifyAnswer(title: $0.displayName, action: .plan(.coverage($0))) }
    }
}
