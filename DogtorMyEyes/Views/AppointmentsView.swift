import SwiftUI

struct AppointmentsView: View {
    @Environment(ProviderStore.self) private var store
    @Environment(AppointmentStore.self) private var appointments
    var onBrowse: () -> Void

    var body: some View {
        NavigationStack {
            TimelineView(.everyMinute) { context in
                let sections = appointments.sections(now: context.date)
                if sections.isEmpty {
                    ContentUnavailableView {
                        Label("No appointment requests", systemImage: "calendar")
                    } description: {
                        Text("Requests you send to a provider show up here.")
                    } actions: {
                        Button("Browse providers", action: onBrowse)
                            .buttonStyle(.borderedProminent)
                            .tint(Theme.teal)
                            .accessibilityIdentifier(AccessibilityID.Appointments.emptyBrowse)
                    }
                } else {
                    List {
                        if !sections.upcoming.isEmpty {
                            Section("Upcoming") {
                                ForEach(sections.upcoming) { request in
                                    row(for: request)
                                }
                            }
                        }
                        if !sections.past.isEmpty {
                            Section("Past") {
                                ForEach(sections.past) { request in
                                    row(for: request)
                                }
                            }
                        }
                    }
                    .accessibilityIdentifier(AccessibilityID.Appointments.list)
                }
            }
            .navigationTitle("Appointments")
            .navigationDestination(for: String.self) { id in
                if let provider = store.provider(id: id) {
                    ProviderDetailView(provider: provider)
                } else {
                    ContentUnavailableView("Provider not found", systemImage: "questionmark.circle")
                }
            }
            .background(Theme.sand.ignoresSafeArea())
        }
    }

    private func row(for request: AppointmentRequest) -> some View {
        NavigationLink(value: request.providerID) {
            AppointmentRow(request: request)
        }
        .accessibilityIdentifier(AccessibilityID.Appointments.row(request.id))
    }
}

struct AppointmentRow: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let request: AppointmentRequest

    var body: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 10))
            : AnyLayout(HStackLayout(alignment: .top, spacing: 14))

        layout {
            ProviderAvatar(colorHex: request.avatarColor)

            VStack(alignment: .leading, spacing: 6) {
                Text(request.providerName)
                    .font(Theme.headlineFont)
                    .foregroundStyle(Theme.ink)
                    .multilineTextAlignment(.leading)

                Text(request.specialty.displayName)
                    .font(Theme.captionFont)
                    .foregroundStyle(Theme.muted)

                Label(SlotFormatter.string(for: request.slot, in: request.timeZone), systemImage: "clock")
                    .font(Theme.bodyFont)
                    .foregroundStyle(Theme.ink)

                HStack(spacing: 8) {
                    Text(request.coverage.displayName)
                        .font(Theme.captionFont)
                        .foregroundStyle(Theme.muted)

                    Text(request.status.displayName)
                        .font(Theme.captionFont.weight(.semibold))
                        .foregroundStyle(Theme.deepTeal)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Theme.teal.opacity(Palette.tintOpacity), in: Capsule())
                }
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(request.accessibilityLabel())
        .accessibilityHint("Opens the provider’s details.")
    }
}

#Preview {
    AppointmentsView(onBrowse: {})
        .environment(ProviderStore())
        .environment(AppointmentStore(userDefaults: nil))
}
