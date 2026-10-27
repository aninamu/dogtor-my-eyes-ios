import Foundation

/// Turns free text into `FinderFilters`. Implementations may be on-device rules, an on-device model, or a future
/// server; the UI only talks to this protocol through `ResilientFinderParser`.
protocol FinderQueryParser: Sendable {
    func parse(_ query: String, context: FinderParseContext) async throws -> FinderFilters
}

/// Runs an optional primary parser with a timeout and always falls back to the deterministic rules.
/// Triage is always taken from the rules so safety messaging never depends on model output.
struct ResilientFinderParser: Sendable {
    static let maxQueryLength = 500

    var primary: (any FinderQueryParser)?
    var rules: RuleBasedQueryParser
    var timeout: TimeInterval
    /// Why `primary` is nil, if it is, so the UI can explain that basic matching is in use.
    var primaryUnavailableReason: FinderFallbackReason?

    init(
        primary: (any FinderQueryParser)?,
        rules: RuleBasedQueryParser = RuleBasedQueryParser(),
        timeout: TimeInterval = 4,
        primaryUnavailableReason: FinderFallbackReason? = nil
    ) {
        self.primary = primary
        self.rules = rules
        self.timeout = timeout
        self.primaryUnavailableReason = primary == nil ? (primaryUnavailableReason ?? .disabled) : nil
    }

    func parse(_ query: String, context: FinderParseContext) async throws -> FinderParseResult {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw FinderParserError.emptyQuery }
        guard trimmed.count <= Self.maxQueryLength else { throw FinderParserError.queryTooLong }

        let ruleFilters = try await rules.parse(trimmed, context: context)
        guard let primary else {
            return FinderParseResult(filters: ruleFilters, source: .rules, fallbackReason: primaryUnavailableReason)
        }

        do {
            let timeout = self.timeout
            let modelFilters = try await withTimeout(seconds: timeout) {
                try await primary.parse(trimmed, context: context)
            }
            let merged = Self.merge(model: modelFilters, rules: ruleFilters, context: context)
            return FinderParseResult(filters: merged, source: .onDeviceModel, fallbackReason: nil)
        } catch FinderParserError.modelUnavailable {
            return FinderParseResult(filters: ruleFilters, source: .rules, fallbackReason: .modelUnavailable)
        } catch FinderParserError.timedOut {
            AppLog.finder.info("On-device model timed out; using rules")
            return FinderParseResult(filters: ruleFilters, source: .rules, fallbackReason: .timedOut)
        } catch {
            AppLog.finder.error("On-device model failed (\(type(of: error))); using rules")
            return FinderParseResult(filters: ruleFilters, source: .rules, fallbackReason: .failed)
        }
    }

    /// Keeps only model values that map onto the catalog's vocabulary, fills gaps from the rules,
    /// and never lets the model downgrade triage.
    static func merge(model: FinderFilters, rules: FinderFilters, context: FinderParseContext) -> FinderFilters {
        var merged = model
        merged.specialty = model.specialty ?? rules.specialty
        merged.plan = model.plan ?? rules.plan
        merged.area = model.area.flatMap { area in
            context.knownAreas.first { $0.caseInsensitiveCompare(area) == .orderedSame }
        } ?? rules.area
        if let miles = model.maxDistanceMiles, miles > 0, miles <= 100 {
            merged.maxDistanceMiles = miles
        } else {
            merged.maxDistanceMiles = rules.maxDistanceMiles
        }
        merged.prefersNearby = model.prefersNearby || rules.prefersNearby
        if model.urgency == .anyTime {
            merged.urgency = rules.urgency
        }
        merged.inNetworkOnly = model.inNetworkOnly && rules.inNetworkOnly
        merged.triage = max(model.triage, rules.triage)
        if merged.triage == .urgent {
            merged.urgency = .asap
        }

        // A value is confirmed only when the deterministic rules found it outright; anything the model
        // supplied on its own is shown as a guess.
        func status(_ slot: FinderSlot, agreesWithRules: Bool, isSet: Bool) -> Bool {
            guard isSet else { return false }
            return agreesWithRules ? rules.guessed.contains(slot) : true
        }
        let nearMatchesRules = merged.area == rules.area && merged.maxDistanceMiles == rules.maxDistanceMiles
        let urgencyIsSafetyDriven = merged.triage == .urgent
        let flags: [(FinderSlot, Bool)] = [
            (.specialty, status(.specialty, agreesWithRules: merged.specialty == rules.specialty, isSet: merged.specialty != nil)),
            (.plan, status(.plan, agreesWithRules: merged.plan == rules.plan, isSet: merged.plan != nil)),
            (.near, status(.near, agreesWithRules: nearMatchesRules, isSet: merged.area != nil || merged.maxDistanceMiles != nil)),
            (.urgency, !urgencyIsSafetyDriven
                && status(.urgency, agreesWithRules: merged.urgency == rules.urgency, isSet: merged.urgency != .anyTime)),
        ]
        merged.guessed = Set(flags.filter(\.1).map(\.0))
        return merged
    }
}

func withTimeout<T: Sendable>(
    seconds: TimeInterval,
    operation: @escaping @Sendable () async throws -> T
) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask { try await operation() }
        group.addTask {
            try await Task.sleep(nanoseconds: UInt64(max(seconds, 0) * 1_000_000_000))
            throw FinderParserError.timedOut
        }
        defer { group.cancelAll() }
        guard let first = try await group.next() else { throw FinderParserError.timedOut }
        return first
    }
}
