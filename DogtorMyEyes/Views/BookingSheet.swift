import SwiftUI

struct BookingSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(ProviderStore.self) private var providerStore
    @Environment(AppointmentStore.self) private var appointments
    let provider: Provider

    @State private var selectedSlot: Date?
    @State private var confirmedRequest: AppointmentRequest?
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Group {
                if let confirmedRequest {
                    confirmation(for: confirmedRequest)
                } else {
                    TimelineView(.everyMinute) { context in
                        slotPicker(upcoming: provider.upcomingSlots(after: context.date))
                    }
                }
            }
            .navigationTitle(confirmedRequest == nil ? "Request appointment" : "Confirmed")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(confirmedRequest == nil ? "Cancel" : "Done") {
                        dismiss()
                    }
                    .accessibilityIdentifier(AccessibilityID.Booking.cancel)
                }
            }
        }
    }

    @ViewBuilder
    private func slotPicker(upcoming: [Date]) -> some View {
        if upcoming.isEmpty {
            ContentUnavailableView(
                "No upcoming openings",
                systemImage: "calendar.badge.exclamationmark",
                description: Text("\(provider.name) has no open times right now. Check back soon or browse other providers.")
            )
            .background(Theme.sand.ignoresSafeArea())
            .accessibilityIdentifier(AccessibilityID.Booking.noOpenings)
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(provider.name)
                        .font(Theme.headlineFont)
                        .foregroundStyle(Theme.ink)

                    Text("Pick a time that works. Times are in the clinic’s time zone. This is a local demo request — nothing is sent to a clinic.")
                        .font(Theme.captionFont)
                        .foregroundStyle(Theme.muted)

                    VStack(spacing: 10) {
                        ForEach(Array(upcoming.enumerated()), id: \.element) { index, slot in
                            slotButton(slot)
                                .accessibilityIdentifier(AccessibilityID.Booking.slot(index))
                        }
                    }

                    if let errorMessage {
                        Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                            .font(Theme.captionFont)
                            .foregroundStyle(Theme.warning)
                            .accessibilityIdentifier(AccessibilityID.Booking.error)
                    }

                    Button {
                        confirm()
                    } label: {
                        Text("Confirm request")
                            .font(Theme.headlineFont)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.teal)
                    .disabled(selectedSlot.map { !upcoming.contains($0) } ?? true)
                    .accessibilityIdentifier(AccessibilityID.Booking.confirm)
                }
                .padding(20)
            }
            .background(Theme.sand.ignoresSafeArea())
        }
    }

    private func slotButton(_ slot: Date) -> some View {
        Button {
            selectedSlot = slot
            errorMessage = nil
        } label: {
            HStack {
                Text(SlotFormatter.string(for: slot, in: provider.timeZone))
                    .font(Theme.bodyFont)
                    .foregroundStyle(Theme.ink)
                Spacer()
                if selectedSlot == slot {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Theme.teal)
                }
            }
            .padding(14)
            .background(
                selectedSlot == slot ? Theme.teal.opacity(0.12) : Theme.card,
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(selectedSlot == slot ? Theme.teal : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selectedSlot == slot ? .isSelected : [])
    }

    private func confirm() {
        guard let selectedSlot else { return }
        do {
            confirmedRequest = try appointments.requestAppointment(
                with: provider,
                slot: selectedSlot,
                coverage: providerStore.coverage
            )
        } catch BookingError.slotInPast {
            self.selectedSlot = nil
            errorMessage = "That time just passed. Please pick another."
        } catch {
            self.selectedSlot = nil
            errorMessage = "That time is no longer available. Please pick another."
        }
    }

    private func confirmation(for request: AppointmentRequest) -> some View {
        ScrollView {
            VStack(spacing: 18) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(Theme.success)
                    .accessibilityHidden(true)

                Text("Appointment requested")
                    .font(Theme.titleFont)
                    .foregroundStyle(Theme.ink)

                Text("\(request.providerName)\n\(SlotFormatter.string(for: request.slot, in: request.timeZone, date: .complete))")
                    .font(Theme.bodyFont)
                    .foregroundStyle(Theme.muted)
                    .multilineTextAlignment(.center)

                Text("Saved to Appointments on this device. This demo doesn’t contact the clinic, and no data leaves your device.")
                    .font(Theme.captionFont)
                    .foregroundStyle(Theme.muted)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            .padding(24)
            .frame(maxWidth: .infinity)
        }
        .background(Theme.sand.ignoresSafeArea())
    }
}

#Preview {
    BookingSheet(
        provider: Provider(
            id: "preview",
            name: "Dr. Biscuit Barkley, OD",
            breed: "Golden Retriever",
            specialty: .optometry,
            acceptedPlans: [.vsp],
            rating: 4.9,
            reviewCount: 214,
            distanceMiles: 1.2,
            bio: "Warm exams.",
            services: ["Exam"],
            availableSlots: [
                Date().addingTimeInterval(86_400),
                Date().addingTimeInterval(172_800)
            ],
            avatarColor: "C4A35A"
        )
    )
    .environment(ProviderStore(providers: []))
    .environment(AppointmentStore(userDefaults: nil))
}
