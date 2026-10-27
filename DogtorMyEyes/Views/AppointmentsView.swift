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
                        description: Text("Request a time from any provider's page to see it here.")
                    )
                } else {
                    appointmentList
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

    private var appointmentList: some View {
        let upcoming = resolved(store.upcomingAppointments())
        let past = resolved(store.pastAppointments())

        return List {
            if !upcoming.isEmpty {
                Section("Upcoming") {
                    ForEach(upcoming) { item in
                        NavigationLink(value: item.provider.id) {
                            AppointmentRow(provider: item.provider, request: item.request)
                        }
                    }
                }
            }

            if !past.isEmpty {
                Section("Past") {
                    ForEach(past) { item in
                        NavigationLink(value: item.provider.id) {
                            AppointmentRow(provider: item.provider, request: item.request, isPast: true)
                        }
                    }
                }
            }
        }
    }

    private func resolved(_ requests: [AppointmentRequest]) -> [ResolvedAppointment] {
        requests.compactMap { request in
            guard let provider = store.provider(id: request.providerID) else { return nil }
            return ResolvedAppointment(request: request, provider: provider)
        }
    }
}

private struct ResolvedAppointment: Identifiable {
    let request: AppointmentRequest
    let provider: Provider

    var id: UUID { request.id }
}

private struct AppointmentRow: View {
    let provider: Provider
    let request: AppointmentRequest
    var isPast: Bool = false

    private var primaryText: Color {
        isPast ? Theme.muted : Theme.ink
    }

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            ProviderAvatar(provider: provider)
                .opacity(isPast ? 0.6 : 1)

            VStack(alignment: .leading, spacing: 6) {
                Text(provider.name)
                    .font(Theme.headlineFont)
                    .foregroundStyle(primaryText)
                    .multilineTextAlignment(.leading)

                Text(provider.specialty.displayName)
                    .font(Theme.captionFont)
                    .foregroundStyle(Theme.muted)

                Text(request.slot.formatted(date: .abbreviated, time: .shortened))
                    .font(Theme.bodyFont)
                    .foregroundStyle(primaryText)

                Text(request.plan.displayName)
                    .font(Theme.captionFont)
                    .foregroundStyle(Theme.muted)

                Text(request.status.displayName)
                    .font(Theme.captionFont.weight(.semibold))
                    .foregroundStyle(Theme.teal)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Theme.teal.opacity(0.14), in: Capsule())
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    AppointmentsView()
        .environment(ProviderStore())
}
