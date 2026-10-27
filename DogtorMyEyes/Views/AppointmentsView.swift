import SwiftUI

struct AppointmentsView: View {
    @Environment(ProviderStore.self) private var store

    var body: some View {
        NavigationStack {
            Group {
                if store.appointments.isEmpty {
                    ContentUnavailableView(
                        "No appointments yet",
                        systemImage: "calendar",
                        description: Text("Browse providers and request a time to see it here.")
                    )
                } else {
                    let upcoming = store.upcomingAppointments()
                    let past = store.pastAppointments()
                    List {
                        if !upcoming.isEmpty {
                            Section("Upcoming") {
                                rows(for: upcoming, isPast: false)
                            }
                        }
                        if !past.isEmpty {
                            Section("Past") {
                                rows(for: past, isPast: true)
                            }
                        }
                    }
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

    @ViewBuilder
    private func rows(for appointments: [AppointmentRequest], isPast: Bool) -> some View {
        ForEach(appointments) { appointment in
            if let provider = store.provider(id: appointment.providerID) {
                NavigationLink(value: provider.id) {
                    AppointmentRow(appointment: appointment, provider: provider, isPast: isPast)
                }
            }
        }
    }
}

private struct AppointmentRow: View {
    let appointment: AppointmentRequest
    let provider: Provider
    let isPast: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            ProviderAvatar(provider: provider)
                .opacity(isPast ? 0.5 : 1)

            VStack(alignment: .leading, spacing: 6) {
                Text(provider.name)
                    .font(Theme.headlineFont)
                    .foregroundStyle(isPast ? Theme.muted : Theme.ink)
                    .multilineTextAlignment(.leading)

                Text(provider.specialty.displayName)
                    .font(Theme.captionFont)
                    .foregroundStyle(Theme.muted)

                Label(
                    appointment.slot.formatted(date: .abbreviated, time: .shortened),
                    systemImage: "clock"
                )
                .font(Theme.bodyFont)
                .foregroundStyle(isPast ? Theme.muted : Theme.ink)

                HStack(spacing: 8) {
                    Text(appointment.plan.displayName)
                        .font(Theme.captionFont)
                        .foregroundStyle(Theme.muted)

                    Text(appointment.status.displayName)
                        .font(Theme.captionFont.weight(.semibold))
                        .foregroundStyle(Theme.deepTeal)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Theme.teal.opacity(0.14), in: Capsule())
                }
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
        .accessibilityHint("Opens provider details")
    }

    private var accessibilityText: String {
        let when = appointment.slot.formatted(date: .complete, time: .shortened)
        let prefix = isPast ? "Past appointment" : "Appointment"
        return "\(prefix) with \(provider.name), \(provider.specialty.displayName), \(when), "
            + "\(appointment.plan.displayName), \(appointment.status.displayName)"
    }
}

#Preview {
    AppointmentsView()
        .environment(ProviderStore())
}
