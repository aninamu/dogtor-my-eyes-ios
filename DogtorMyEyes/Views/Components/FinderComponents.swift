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

/// A tappable "understood" chip; the menu content edits the value.
struct FinderChip<MenuContent: View>: View {
    let title: String
    let value: String
    let isSet: Bool
    let identifier: String
    @ViewBuilder var menu: () -> MenuContent

    var body: some View {
        Menu(content: menu) {
            HStack(spacing: 0) {
                Text("\(title): ")
                    .font(Theme.captionFont)
                Text(value)
                    .font(Theme.captionFont.weight(.semibold))
                Image(systemName: "chevron.down")
                    .padding(.leading, 4)
                    .font(Theme.captionFont)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .foregroundStyle(isSet ? .white : Theme.deepTeal)
            .background(isSet ? Theme.teal : Theme.teal.opacity(0.12), in: Capsule())
        }
        .accessibilityLabel("\(title), \(value)")
        .accessibilityHint("Double-tap to change.")
        .accessibilityIdentifier(identifier)
    }
}

/// "Here's what I understood": Specialty, Plan, Near, and Urgency chips over the finder's filters.
struct UnderstoodChipsRow: View {
    @Bindable var finder: FinderModel
    let areas: [String]

    private static let distanceOptions: [Double] = [2, 5, 10]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Here’s what I understood")
                .font(Theme.captionFont.weight(.semibold))
                .foregroundStyle(Theme.muted)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    specialtyChip
                    planChip
                    nearChip
                    urgencyChip
                }
                .padding(.vertical, 2)
            }
        }
    }

    private var specialtyChip: some View {
        FinderChip(
            title: "Specialty",
            value: finder.filters.specialty?.displayName ?? "Any",
            isSet: finder.filters.specialty != nil,
            identifier: AccessibilityID.Finder.chip("specialty")
        ) {
            Picker("Specialty", selection: $finder.filters.specialty) {
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
            isSet: finder.plan != nil,
            identifier: AccessibilityID.Finder.chip("plan")
        ) {
            Picker("Plan", selection: Binding(get: { finder.plan }, set: { finder.setPlan($0) })) {
                Text("Any plan").tag(PlanUnderstanding?.none)
                ForEach(planOptions, id: \.self) { option in
                    Text(option.displayName).tag(PlanUnderstanding?.some(option))
                }
            }
            if case .coverage(.insurance)? = finder.plan {
                Toggle("In-network only", isOn: $finder.filters.inNetworkOnly)
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
        FinderChip(
            title: "Near",
            value: finder.filters.nearDisplayName,
            isSet: finder.filters.hasNearPreference,
            identifier: AccessibilityID.Finder.chip("near")
        ) {
            nearButton("Anywhere", selected: !finder.filters.hasNearPreference) {
                finder.filters.area = nil
                finder.filters.maxDistanceMiles = nil
                finder.filters.prefersNearby = false
            }
            Section("Area") {
                ForEach(areas, id: \.self) { area in
                    nearButton(area, selected: finder.filters.area == area) {
                        finder.filters.area = finder.filters.area == area ? nil : area
                    }
                }
            }
            Section("Distance") {
                ForEach(Self.distanceOptions, id: \.self) { miles in
                    nearButton("Within \(FinderFilters.milesText(miles)) mi", selected: finder.filters.maxDistanceMiles == miles) {
                        finder.filters.maxDistanceMiles = finder.filters.maxDistanceMiles == miles ? nil : miles
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
            isSet: finder.filters.urgency != .anyTime,
            identifier: AccessibilityID.Finder.chip("urgency")
        ) {
            Picker("Urgency", selection: $finder.filters.urgency) {
                ForEach(FinderUrgency.allCases, id: \.self) { urgency in
                    Text(urgency.displayName).tag(urgency)
                }
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
