import SwiftUI

struct ProviderDetailView: View {
    @Environment(ProviderStore.self) private var store
    @Environment(AppointmentStore.self) private var appointments
    let provider: Provider

    @State private var showBooking = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                bioSection
                servicesSection
                plansSection

                TimelineView(.everyMinute) { context in
                    let upcoming = provider.upcomingSlots(after: context.date)
                    VStack(alignment: .leading, spacing: 20) {
                        slotsPreview(upcoming)

                        Button {
                            showBooking = true
                        } label: {
                            Label("Request appointment", systemImage: "calendar.badge.plus")
                                .font(Theme.headlineFont)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Theme.teal)
                        .padding(.top, 4)
                        .disabled(upcoming.isEmpty)
                        .accessibilityIdentifier(AccessibilityID.Detail.requestAppointment)
                    }
                }
            }
            .padding(20)
        }
        .background(Theme.sand.ignoresSafeArea())
        .navigationTitle("Provider")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    store.toggleFavorite(provider)
                } label: {
                    Image(systemName: store.isFavorite(provider) ? "heart.fill" : "heart")
                        .foregroundStyle(store.isFavorite(provider) ? .red : Theme.muted)
                }
                .accessibilityLabel(store.isFavorite(provider) ? "Remove from favorites" : "Add to favorites")
                .accessibilityIdentifier(AccessibilityID.Detail.favorite)
            }
        }
        .sheet(isPresented: $showBooking) {
            BookingSheet(provider: provider)
                .environment(store)
                .environment(appointments)
        }
    }

    private var header: some View {
        VStack(spacing: 14) {
            ProviderAvatar(provider: provider, size: 96)

            Text(provider.name)
                .font(Theme.titleFont)
                .foregroundStyle(Theme.ink)
                .multilineTextAlignment(.center)

            Text("\(provider.breed) · \(provider.specialty.displayName)")
                .font(Theme.bodyFont)
                .foregroundStyle(Theme.muted)

            HStack(spacing: 12) {
                Label(String(format: "%.1f", provider.rating), systemImage: "star.fill")
                Text("\(provider.reviewCount) reviews")
                Text(String(format: "%.1f mi away", provider.distanceMiles))
            }
            .font(Theme.captionFont)
            .foregroundStyle(Theme.muted)

            if let status = provider.networkStatus(for: store.coverage) {
                NetworkBadge(status: status)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var bioSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("About")
                .font(Theme.headlineFont)
                .foregroundStyle(Theme.ink)
            Text(provider.bio)
                .font(Theme.bodyFont)
                .foregroundStyle(Theme.muted)
        }
    }

    private var servicesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Services")
                .font(Theme.headlineFont)
                .foregroundStyle(Theme.ink)

            ForEach(provider.services, id: \.self) { service in
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Theme.teal)
                    Text(service)
                        .font(Theme.bodyFont)
                        .foregroundStyle(Theme.ink)
                }
            }
        }
    }

    private var plansSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Accepted plans")
                .font(Theme.headlineFont)
                .foregroundStyle(Theme.ink)

            if provider.acceptedPlans.isEmpty {
                Text("No insurance plans on file.")
                    .font(Theme.bodyFont)
                    .foregroundStyle(Theme.muted)
            } else {
                FlowWrap(items: provider.acceptedPlans.map(\.displayName))
            }

            Label(
                provider.acceptsSelfPay ? "Self-pay accepted" : "Self-pay not accepted",
                systemImage: provider.acceptsSelfPay ? "creditcard" : "xmark.circle"
            )
            .font(Theme.captionFont)
            .foregroundStyle(Theme.muted)
        }
    }

    private func slotsPreview(_ upcoming: [Date]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Next available")
                .font(Theme.headlineFont)
                .foregroundStyle(Theme.ink)

            if upcoming.isEmpty {
                Label("No upcoming openings. Check back soon.", systemImage: "calendar.badge.exclamationmark")
                    .font(Theme.bodyFont)
                    .foregroundStyle(Theme.muted)
                    .accessibilityIdentifier(AccessibilityID.Detail.noOpenings)
            } else {
                ForEach(upcoming.prefix(3), id: \.self) { date in
                    Label(SlotFormatter.string(for: date, in: provider.timeZone), systemImage: "clock")
                        .font(Theme.bodyFont)
                        .foregroundStyle(Theme.ink)
                }
                Text("Times shown in the clinic’s time zone.")
                    .font(Theme.captionFont)
                    .foregroundStyle(Theme.muted)
            }
        }
    }
}

private struct FlowWrap: View {
    let items: [String]

    var body: some View {
        FlexibleChipLayout(spacing: 8) {
            ForEach(items, id: \.self) { item in
                Text(item)
                    .font(Theme.captionFont.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Theme.teal.opacity(0.12), in: Capsule())
                    .foregroundStyle(Theme.deepTeal)
            }
        }
    }
}

private struct FlexibleChipLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, frame) in result.frames.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY),
                proposal: ProposedViewSize(frame.size)
            )
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, frames: [CGRect]) {
        let maxWidth = proposal.width ?? .infinity
        var frames: [CGRect] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var widthUsed: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            frames.append(CGRect(origin: CGPoint(x: x, y: y), size: size))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
            widthUsed = max(widthUsed, x - spacing)
        }

        return (CGSize(width: widthUsed, height: y + rowHeight), frames)
    }
}

#Preview {
    NavigationStack {
        ProviderDetailView(
            provider: Provider(
                id: "preview",
                name: "Dr. Biscuit Barkley, OD",
                breed: "Golden Retriever",
                specialty: .optometry,
                acceptedPlans: [.vsp, .eyeMed],
                rating: 4.9,
                reviewCount: 214,
                distanceMiles: 1.2,
                bio: "Warm, thorough exams with a gentle paw.",
                services: ["Comprehensive eye exam", "Prescription renewal"],
                availableSlots: [Date().addingTimeInterval(86_400)],
                avatarColor: "C4A35A"
            )
        )
    }
    .environment(ProviderStore())
    .environment(AppointmentStore(userDefaults: nil))
}
