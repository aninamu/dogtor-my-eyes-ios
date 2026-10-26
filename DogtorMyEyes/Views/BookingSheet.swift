import SwiftUI

struct BookingSheet: View {
    @Environment(\.dismiss) private var dismiss
    let provider: Provider

    @State private var selectedSlot: Date?
    @State private var confirmed = false

    var body: some View {
        NavigationStack {
            Group {
                if confirmed, let selectedSlot {
                    confirmation(for: selectedSlot)
                } else {
                    slotPicker
                }
            }
            .navigationTitle(confirmed ? "Confirmed" : "Request appointment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(confirmed ? "Done" : "Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }

    private var slotPicker: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(provider.name)
                .font(Theme.headlineFont)
                .foregroundStyle(Theme.ink)

            Text("Pick a time that works. This is a local demo request — nothing is sent to a clinic.")
                .font(Theme.captionFont)
                .foregroundStyle(Theme.muted)

            VStack(spacing: 10) {
                ForEach(provider.nextAvailable, id: \.self) { slot in
                    Button {
                        selectedSlot = slot
                    } label: {
                        HStack {
                            Text(slot.formatted(date: .abbreviated, time: .shortened))
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
                }
            }

            Button {
                guard selectedSlot != nil else { return }
                confirmed = true
            } label: {
                Text("Confirm request")
                    .font(Theme.headlineFont)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.teal)
            .disabled(selectedSlot == nil)

            Spacer()
        }
        .padding(20)
        .background(Theme.sand.ignoresSafeArea())
    }

    private func confirmation(for slot: Date) -> some View {
        VStack(spacing: 18) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 56))
                .foregroundStyle(Theme.success)

            Text("Appointment requested")
                .font(Theme.titleFont)
                .foregroundStyle(Theme.ink)

            Text("\(provider.name)\n\(slot.formatted(date: .complete, time: .shortened))")
                .font(Theme.bodyFont)
                .foregroundStyle(Theme.muted)
                .multilineTextAlignment(.center)

            Text("You’ll get a paw-shake confirmation in this demo only. No data leaves your device.")
                .font(Theme.captionFont)
                .foregroundStyle(Theme.muted)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Spacer()
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
            nextAvailable: [
                Date().addingTimeInterval(86_400),
                Date().addingTimeInterval(172_800)
            ],
            avatarColor: "C4A35A"
        )
    )
}
