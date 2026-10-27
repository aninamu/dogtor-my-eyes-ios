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
        locale: Locale = .autoupdatingCurrent
    ) -> [FinderMatch] {
        let candidates = providers.filter { provider in
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
                reason: reason(for: provider, filters: filters, plan: plan, status: status, slot: slot, now: now, locale: locale)
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
        now: Date,
        locale: Locale
    ) -> String {
        var parts: [String] = []

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
