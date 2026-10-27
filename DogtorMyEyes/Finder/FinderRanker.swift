import Foundation

struct FinderMatch: Identifiable, Equatable {
    let provider: Provider
    /// Shown only when the catalog backs it: a supported insurance plan was chosen.
    let networkStatus: NetworkStatus?
    /// First upcoming opening that satisfies the urgency preference, if any.
    let matchingSlot: Date?
    /// Deterministic one-liner built from which filters matched. Never model text.
    let reason: String

    var id: String { provider.id }
}

/// Filters and ranks real catalog providers against understood filters. The only source of providers,
/// coverage, and openings is the `providers` array passed in.
enum FinderRanker {
    static func rank(
        _ providers: [Provider],
        filters: FinderFilters,
        plan: PlanUnderstanding?,
        now: Date,
        keywordHits: [String: String] = [:],
        locale: Locale = .autoupdatingCurrent
    ) -> [FinderMatch] {
        let candidates = providers.filter { passesHardFilters($0, filters: filters, plan: plan) }

        let scored = candidates.map { provider -> (FinderMatch, Int) in
            let slot = firstSlot(for: provider, matching: filters.urgency, now: now)
            let status = plan.flatMap { understanding -> NetworkStatus? in
                guard case .coverage(let coverage) = understanding else { return nil }
                return provider.networkStatus(for: coverage)
            }
            let match = FinderMatch(
                provider: provider,
                networkStatus: status,
                matchingSlot: slot,
                reason: reason(
                    for: provider,
                    filters: filters,
                    plan: plan,
                    status: status,
                    slot: slot,
                    keyword: keywordHits[provider.id],
                    now: now,
                    locale: locale
                )
            )
            // 0: opening matches the urgency, 1: has other openings, 2: nothing bookable.
            let tier = slot != nil ? 0 : (provider.upcomingSlots(after: now).isEmpty ? 2 : 1)
            return (match, tier)
        }

        let timeSensitive = filters.urgency != .anyTime
        return scored.sorted { lhs, rhs in
            let (a, aTier) = lhs
            let (b, bTier) = rhs
            if aTier != bTier { return aTier < bTier }
            if timeSensitive, let aSlot = a.matchingSlot, let bSlot = b.matchingSlot, aSlot != bSlot { return aSlot < bSlot }
            if a.provider.distanceMiles != b.provider.distanceMiles {
                return a.provider.distanceMiles < b.provider.distanceMiles
            }
            if a.provider.rating != b.provider.rating { return a.provider.rating > b.provider.rating }
            return a.provider.id < b.provider.id
        }
        .map(\.0)
    }

    static func passesHardFilters(_ provider: Provider, filters: FinderFilters, plan: PlanUnderstanding?) -> Bool {
        if let specialty = filters.specialty, provider.specialty != specialty { return false }
        if let area = filters.area, provider.area.caseInsensitiveCompare(area) != .orderedSame { return false }
        if let maxMiles = filters.maxDistanceMiles, provider.distanceMiles > maxMiles { return false }
        switch plan {
        case .coverage(.insurance(let insurance)):
            if filters.inNetworkOnly && !provider.isInNetwork(for: insurance) { return false }
        case .coverage(.selfPay):
            if !provider.acceptsSelfPay { return false }
        case .unsupported, nil:
            break
        }
        return true
    }

    static func firstSlot(for provider: Provider, matching urgency: FinderUrgency, now: Date) -> Date? {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = provider.timeZone
        let upcoming = provider.upcomingSlots(after: now)

        switch urgency {
        case .anyTime, .asap:
            return upcoming.first
        case .today:
            return upcoming.first { calendar.isDate($0, inSameDayAs: now) }
        case .tomorrow:
            guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: now) else { return nil }
            return upcoming.first { calendar.isDate($0, inSameDayAs: tomorrow) }
        case .weekend:
            return upcoming.first { calendar.isDateInWeekend($0) }
        case .weekday(let weekday):
            return upcoming.first { calendar.component(.weekday, from: $0) == weekday }
        }
    }

    static func reason(
        for provider: Provider,
        filters: FinderFilters,
        plan: PlanUnderstanding?,
        status: NetworkStatus?,
        slot: Date?,
        keyword: String? = nil,
        now: Date,
        locale: Locale
    ) -> String {
        var parts: [String] = []

        if let keyword {
            parts.append("Matches “\(keyword)”")
        }

        if filters.specialty != nil {
            parts.append(provider.specialty.displayName)
        }

        switch (plan, status) {
        case (.coverage(.insurance(let insurance)), .inNetwork?):
            parts.append("In-network for \(insurance.displayName)")
        case (.coverage(.insurance(let insurance)), _):
            parts.append("Out-of-network for \(insurance.displayName)")
        case (.coverage(.selfPay), _):
            parts.append("Accepts self-pay")
        case (.unsupported(let name), _):
            parts.append("\(name) not in directory")
        case (nil, _):
            break
        }

        if let area = filters.area {
            parts.append(area)
        }
        if filters.maxDistanceMiles != nil || filters.prefersNearby {
            parts.append("\(FinderFilters.milesText(provider.distanceMiles)) mi away")
        }

        if let slot {
            var style = Date.FormatStyle().weekday(.abbreviated).hour().minute()
            style.timeZone = provider.timeZone
            style.locale = locale
            parts.append("Opens \(slot.formatted(style))")
        } else if provider.upcomingSlots(after: now).isEmpty {
            parts.append("No upcoming openings")
        } else {
            parts.append(filters.urgency.noOpeningsText)
        }

        return parts.joined(separator: " · ")
    }
}

// MARK: - Keyword fallback

extension FinderRanker {
    private static let keywordStopWords: Set<String> = [
        "the", "and", "for", "with", "my", "our", "his", "her", "dog", "dogs", "pup", "pups", "doggo", "eye", "eyes",
        "need", "needs", "help", "want", "looking", "find", "some", "someone", "doctor", "dogtor", "vet", "near", "please",
        "can", "you", "who", "what", "any", "anything", "something", "wrong", "dr", "od", "md",
    ]

    /// When the parser understood nothing, fall back to plain keyword search over provider names and breeds,
    /// so "Biscuit" or "beagle" still works now that the finder is the only search field.
    /// Returns provider ID → the query word that matched.
    static func keywordHits(in providers: [Provider], query: String) -> [String: String] {
        let words = RuleBasedQueryParser.tokenize(query).filter { $0.count >= 3 && !keywordStopWords.contains($0) }
        guard !words.isEmpty else { return [:] }

        var hits: [String: String] = [:]
        for provider in providers {
            let haystack = Set(RuleBasedQueryParser.tokenize("\(provider.name) \(provider.breed)"))
            if let word = words.first(where: { word in haystack.contains { $0.hasPrefix(word) } }) {
                hits[provider.id] = word
            }
        }
        return hits
    }
}

// MARK: - No-match relaxation

/// The one-tap way out of an empty result: which chip is limiting results and how to loosen it.
struct FinderRelaxation: Equatable {
    enum Change: Equatable {
        case clearNear
        case clearSpecialty
        case includeOutOfNetwork
        case anyPlan
    }

    let slot: FinderSlot
    let change: Change
    let message: String
    let actionTitle: String
    let resultCount: Int
}

extension FinderRanker {
    /// Tries loosening one chip at a time, least important first (Near, then Specialty, then Plan), and
    /// returns the first that yields matches. `nil` means no single change helps.
    static func relaxation(
        for providers: [Provider],
        filters: FinderFilters,
        plan: PlanUnderstanding?
    ) -> FinderRelaxation? {
        var options: [(FinderSlot, FinderRelaxation.Change, FinderFilters, PlanUnderstanding?, String)] = []

        if filters.area != nil || filters.maxDistanceMiles != nil {
            var loosened = filters
            loosened.area = nil
            loosened.maxDistanceMiles = nil
            let title = filters.maxDistanceMiles != nil && filters.area == nil ? "Widen distance" : "Search anywhere"
            options.append((.near, .clearNear, loosened, plan, title))
        }
        if filters.specialty != nil {
            var loosened = filters
            loosened.specialty = nil
            options.append((.specialty, .clearSpecialty, loosened, plan, "Any specialty"))
        }
        switch plan {
        case .coverage(.insurance) where filters.inNetworkOnly:
            var loosened = filters
            loosened.inNetworkOnly = false
            options.append((.plan, .includeOutOfNetwork, loosened, plan, "Include out-of-network"))
        case .coverage(.selfPay):
            options.append((.plan, .anyPlan, filters, nil, "Any payment option"))
        default:
            break
        }

        for (slot, change, loosened, loosenedPlan, title) in options {
            let count = providers.filter { passesHardFilters($0, filters: loosened, plan: loosenedPlan) }.count
            guard count > 0 else { continue }
            let question = "\(slot.displayName) is limiting results. \(title) to see \(count == 1 ? "1 match" : "\(count) matches")?"
            return FinderRelaxation(
                slot: slot,
                change: change,
                message: "\(noMatchSentence(filters: filters, plan: plan)) \(question)",
                actionTitle: title,
                resultCount: count
            )
        }
        return nil
    }

    /// For example "No Ophthalmology providers within 2 mi take VSP."
    static func noMatchSentence(filters: FinderFilters, plan: PlanUnderstanding?) -> String {
        var sentence = "No"
        if let specialty = filters.specialty { sentence += " \(specialty.displayName)" }
        sentence += " providers"
        if let area = filters.area { sentence += " in \(area)" }
        if let miles = filters.maxDistanceMiles { sentence += " within \(FinderFilters.milesText(miles)) mi" }
        switch plan {
        case .coverage(.insurance(let insurance)) where filters.inNetworkOnly:
            sentence += " take \(insurance.displayName)"
        case .coverage(.selfPay):
            sentence += " accept self-pay"
        default:
            break
        }
        return sentence + "."
    }
}
