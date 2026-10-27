import SwiftUI

extension EnvironmentValues {
    @Entry var featureFlags = FeatureFlags()
}

/// Pinned natural-language search bar for the finder.
struct FinderSearchBar: View {
    @Binding var text: String
    var isParsing: Bool
    var onSubmit: () -> Void
    var onClear: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "text.magnifyingglass")
                .foregroundStyle(Theme.teal)
                .accessibilityHidden(true)

            TextField("Describe what your dog needs", text: $text, prompt: Text("e.g. cloudy eye, VSP, Brooklyn, Saturday").foregroundStyle(Theme.muted))
                .font(Theme.bodyFont)
                .foregroundStyle(Theme.ink)
                .submitLabel(.search)
                .onSubmit(onSubmit)
                .accessibilityLabel("Describe what your dog needs")
                .accessibilityHint("For example: cloudy eye, VSP, near Brooklyn, Saturday.")
                .accessibilityIdentifier(AccessibilityID.Finder.searchField)

            if isParsing {
                ProgressView()
                    .tint(Theme.teal)
                    .accessibilityLabel("Reading your request")
            } else if !text.isEmpty {
                Button(action: onClear) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Theme.muted)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Clear and show all providers")
                .accessibilityIdentifier(AccessibilityID.Finder.clear)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Theme.teal.opacity(0.35), lineWidth: 1)
        )
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Theme.sand)
    }
}

/// Thinking, error, low-confidence, offline, and fallback states for the finder.
enum FinderStatusKind: Equatable {
    case thinking
    case notSure
    case error(String)
    case offline
    case basicMatching
}

struct FinderStatusView: View {
    let kind: FinderStatusKind
    var onRetry: (() -> Void)?

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            if kind == .thinking {
                ProgressView()
                    .tint(Theme.teal)
            } else {
                Image(systemName: systemImage)
                    .foregroundStyle(tint)
                    .accessibilityHidden(true)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(Theme.headlineFont)
                    .foregroundStyle(Theme.ink)
                Text(message)
                    .font(Theme.captionFont)
                    .foregroundStyle(Theme.muted)
                if let onRetry, case .error = kind {
                    Button("Try again", action: onRetry)
                        .font(Theme.captionFont.weight(.semibold))
                        .tint(Theme.teal)
                        .buttonStyle(.borderless)
                        .accessibilityIdentifier(AccessibilityID.Finder.retry)
                }
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(AccessibilityID.Finder.status)
    }

    private var title: String {
        switch kind {
        case .thinking: return "Reading your request…"
        case .notSure: return "Not sure what you need"
        case .error: return "Couldn’t read that"
        case .offline: return "You’re offline"
        case .basicMatching: return "Using keyword matching"
        }
    }

    private var message: String {
        switch kind {
        case .thinking: return "Matching it to specialties, plans, and openings on this device."
        case .notSure: return "Try adding a symptom, your plan, an area, or a day — or tap a chip to choose."
        case .error(let message): return message
        case .offline: return "The finder still works. Everything runs on this device."
        case .basicMatching: return "Smart matching isn’t available on this device, so results use built-in keywords."
        }
    }

    private var systemImage: String {
        switch kind {
        case .thinking: return "hourglass"
        case .notSure: return "questionmark.bubble"
        case .error: return "exclamationmark.triangle.fill"
        case .offline: return "wifi.slash"
        case .basicMatching: return "text.badge.checkmark"
        }
    }

    private var tint: Color {
        switch kind {
        case .error: return Theme.warning
        case .thinking, .notSure, .offline, .basicMatching: return Theme.teal
        }
    }
}

/// Safety copy shown whenever a symptom is detected. Urgent wording gets urgent-care guidance first.
struct TriageNotice: View {
    let triage: Triage

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if triage == .urgent {
                Label("This sounds urgent", systemImage: "cross.case.fill")
                    .font(Theme.headlineFont)
                    .foregroundStyle(Theme.warning)
                Text("Contact an emergency vet or animal hospital now. Don’t wait for an eye-care appointment.")
                    .font(Theme.bodyFont)
                    .foregroundStyle(Theme.ink)
            }
            Label("Not a diagnosis. If it’s urgent or getting worse, see a vet.", systemImage: "stethoscope")
                .font(Theme.captionFont.weight(.semibold))
                .foregroundStyle(triage == .urgent ? Theme.ink : Theme.deepTeal)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            (triage == .urgent ? Theme.warning : Theme.teal).opacity(Palette.tintOpacity),
            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
        )
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(triage == .urgent ? .isHeader : [])
        .accessibilityIdentifier(AccessibilityID.Finder.triageNotice)
    }
}

enum FinderChipState: Equatable {
    /// Stated by the user or set by them: filled.
    case confirmed
    /// Inferred, typo-corrected, or taken from settings: dashed outline so it reads as a guess.
    case guessed
    /// Nothing understood for this slot.
    case empty

    var accessibilityValue: String {
        switch self {
        case .confirmed: return ""
        case .guessed: return "Guessed. Double-tap to confirm or change."
        case .empty: return "Not set. Double-tap to choose."
        }
    }
}

/// A tappable "understood" chip; the menu content edits the value.
struct FinderChip<MenuContent: View>: View {
    let title: String
    let value: String
    let state: FinderChipState
    let identifier: String
    @ViewBuilder var menu: () -> MenuContent

    private var label: AttributedString {
        var title = AttributedString("\(self.title): ")
        title.font = Theme.captionFont
        var value = AttributedString(self.value)
        value.font = Theme.captionFont.weight(.semibold)
        return title + value
    }

    var body: some View {
        Menu(content: menu) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(label)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Image(systemName: state == .guessed ? "questionmark.circle" : "chevron.down")
                    .font(Theme.captionFont)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .foregroundStyle(state == .confirmed ? .white : Theme.deepTeal)
            .background(background, in: Capsule())
            .overlay {
                if state == .guessed {
                    Capsule()
                        .strokeBorder(Theme.teal, style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                }
            }
        }
        .accessibilityLabel("\(title), \(value)")
        .accessibilityValue(state.accessibilityValue)
        .accessibilityHint(state == .confirmed ? "Double-tap to change." : "")
        .accessibilityIdentifier(identifier)
    }

    private var background: Color {
        switch state {
        case .confirmed: return Theme.teal
        case .guessed: return Theme.card
        case .empty: return Theme.teal.opacity(0.12)
        }
    }
}

/// "Here's what I understood": Specialty, Plan, Near, and Urgency chips over the finder's filters.
/// Chips wrap onto new rows rather than scrolling, so every chip stays reachable at large text sizes.
struct UnderstoodChipsRow: View {
    let finder: FinderModel
    let areas: [String]

    private static let distanceOptions: [Double] = [2, 5, 10]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Here’s what I understood")
                .font(Theme.captionFont.weight(.semibold))
                .foregroundStyle(Theme.muted)
                .accessibilityAddTraits(.isHeader)

            FlowLayout(spacing: 8) {
                specialtyChip
                planChip
                nearChip
                urgencyChip
            }
            .padding(.vertical, 2)
        }
    }

    private func state(_ slot: FinderSlot, isSet: Bool) -> FinderChipState {
        guard isSet else { return .empty }
        return finder.filters.guessed.contains(slot) ? .guessed : .confirmed
    }

    private var specialtyChip: some View {
        FinderChip(
            title: "Specialty",
            value: finder.filters.specialty?.displayName ?? "Any",
            state: state(.specialty, isSet: finder.filters.specialty != nil),
            identifier: AccessibilityID.Finder.chip("specialty")
        ) {
            Picker("Specialty", selection: Binding(get: { finder.filters.specialty }, set: { finder.setSpecialty($0) })) {
                Text("Any specialty").tag(Specialty?.none)
                ForEach(Specialty.allCases) { specialty in
                    Label(specialty.displayName, systemImage: specialty.systemImage).tag(Specialty?.some(specialty))
                }
            }
        }
    }

    private var planOptions: [PlanUnderstanding] {
        var options = Coverage.allCases.map(PlanUnderstanding.coverage)
        if case .unsupported? = finder.plan, let current = finder.plan {
            options.append(current)
        }
        return options
    }

    private var planChip: some View {
        FinderChip(
            title: "Plan",
            value: planValue,
            state: state(.plan, isSet: finder.plan != nil),
            identifier: AccessibilityID.Finder.chip("plan")
        ) {
            Picker("Plan", selection: Binding(get: { finder.plan }, set: { finder.setPlan($0) })) {
                Text("Any plan").tag(PlanUnderstanding?.none)
                ForEach(planOptions, id: \.self) { option in
                    Text(option.displayName).tag(PlanUnderstanding?.some(option))
                }
            }
            if case .coverage(.insurance)? = finder.plan {
                Toggle(
                    "In-network only",
                    isOn: Binding(get: { finder.filters.inNetworkOnly }, set: { finder.setInNetworkOnly($0) })
                )
            }
        }
    }

    private var planValue: String {
        guard let plan = finder.plan else { return "Any" }
        switch plan {
        case .coverage:
            return finder.planFromSettings ? "\(plan.displayName) (yours)" : plan.displayName
        case .unsupported(let name):
            return "\(name) (no network data)"
        }
    }

    private var nearChip: some View {
        let filters = finder.filters
        return FinderChip(
            title: "Near",
            value: filters.nearDisplayName,
            state: state(.near, isSet: filters.hasNearPreference),
            identifier: AccessibilityID.Finder.chip("near")
        ) {
            nearButton("Anywhere", selected: !filters.hasNearPreference) {
                finder.setNear(area: nil, maxDistanceMiles: nil)
            }
            Section("Area") {
                ForEach(areas, id: \.self) { area in
                    nearButton(area, selected: filters.area == area) {
                        finder.setNear(
                            area: filters.area == area ? nil : area,
                            maxDistanceMiles: filters.maxDistanceMiles,
                            prefersNearby: filters.prefersNearby
                        )
                    }
                }
            }
            Section("Distance") {
                ForEach(Self.distanceOptions, id: \.self) { miles in
                    nearButton("Within \(FinderFilters.milesText(miles)) mi", selected: filters.maxDistanceMiles == miles) {
                        finder.setNear(
                            area: filters.area,
                            maxDistanceMiles: filters.maxDistanceMiles == miles ? nil : miles,
                            prefersNearby: filters.prefersNearby
                        )
                    }
                }
            }
        }
    }

    private func nearButton(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            if selected {
                Label(title, systemImage: "checkmark")
            } else {
                Text(title)
            }
        }
    }

    private var urgencyChip: some View {
        FinderChip(
            title: "Urgency",
            value: finder.filters.urgency.displayName,
            state: state(.urgency, isSet: finder.filters.urgency != .anyTime),
            identifier: AccessibilityID.Finder.chip("urgency")
        ) {
            Picker("Urgency", selection: Binding(get: { finder.filters.urgency }, set: { finder.setUrgency($0) })) {
                ForEach(FinderUrgency.allCases, id: \.self) { urgency in
                    Text(urgency.displayName).tag(urgency)
                }
            }
        }
    }
}

/// Asks one question about the most important uncertain chip, with tappable answers.
struct ClarifyPrompt: View {
    let question: ClarifyQuestion
    var onAnswer: (ClarifyAnswer) -> Void
    var onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(question.prompt, systemImage: "questionmark.bubble")
                .font(Theme.bodyFont)
                .foregroundStyle(Theme.ink)
                .accessibilityAddTraits(.isHeader)

            FlowLayout(spacing: 8) {
                ForEach(Array(question.answers.enumerated()), id: \.element.id) { index, answer in
                    Button {
                        onAnswer(answer)
                    } label: {
                        Text(answer.title)
                            .font(Theme.captionFont.weight(.semibold))
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .foregroundStyle(Theme.deepTeal)
                            .background(Theme.teal.opacity(0.12), in: Capsule())
                    }
                    .buttonStyle(.borderless)
                    .accessibilityIdentifier(AccessibilityID.Finder.clarifyAnswer(index))
                }
            }

            Button("Not now", action: onDismiss)
                .font(Theme.captionFont)
                .tint(Theme.muted)
                .buttonStyle(.borderless)
                .accessibilityIdentifier(AccessibilityID.Finder.clarifyDismiss)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AccessibilityID.Finder.clarify)
    }
}

/// Empty results that name the limiting chip and offer to loosen it in one tap.
struct FinderNoMatchesView: View {
    let relaxation: FinderRelaxation?
    var onRelax: (FinderRelaxation) -> Void

    var body: some View {
        ContentUnavailableView {
            Label("No matches", systemImage: "eye.slash")
        } description: {
            Text(relaxation?.message ?? "Nothing matches every chip. Tap a chip above to change it, or clear the search to browse everyone.")
        } actions: {
            if let relaxation {
                Button(relaxation.actionTitle) {
                    onRelax(relaxation)
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.teal)
                .accessibilityHint("Shows \(relaxation.resultCount == 1 ? "1 match" : "\(relaxation.resultCount) matches").")
                .accessibilityIdentifier(AccessibilityID.Finder.relax)
            }
        }
    }
}

/// A provider card from the finder: the existing row plus the deterministic match reason.
struct FinderResultRow: View {
    let match: FinderMatch
    let isFavorite: Bool
    var onToggleFavorite: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ProviderRow(
                provider: match.provider,
                networkStatus: match.networkStatus,
                isFavorite: isFavorite,
                onToggleFavorite: onToggleFavorite
            )
            Label(match.reason, systemImage: "checkmark.circle")
                .font(Theme.captionFont)
                .foregroundStyle(Theme.deepTeal)
                .accessibilityLabel("Why this match: \(match.reason)")
                .accessibilityIdentifier(AccessibilityID.Finder.matchReason(match.provider.id))
        }
    }
}
