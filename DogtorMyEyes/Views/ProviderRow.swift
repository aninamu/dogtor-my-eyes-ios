import SwiftUI

struct ProviderRow: View {
    let provider: Provider
    let plan: InsurancePlan
    let isFavorite: Bool
    var onToggleFavorite: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            ProviderAvatar(provider: provider)

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline) {
                    Text(provider.name)
                        .font(Theme.headlineFont)
                        .foregroundStyle(Theme.ink)
                        .multilineTextAlignment(.leading)

                    Spacer(minLength: 8)

                    Button(action: onToggleFavorite) {
                        Image(systemName: isFavorite ? "heart.fill" : "heart")
                            .foregroundStyle(isFavorite ? .red : Theme.muted)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(isFavorite ? "Remove from favorites" : "Add to favorites")
                }

                Text("\(provider.breed) · \(provider.specialty.displayName)")
                    .font(Theme.captionFont)
                    .foregroundStyle(Theme.muted)

                HStack(spacing: 10) {
                    Label(String(format: "%.1f", provider.rating), systemImage: "star.fill")
                        .foregroundStyle(Theme.teal)
                    Text("\(provider.reviewCount) reviews")
                        .foregroundStyle(Theme.muted)
                    Text(String(format: "%.1f mi", provider.distanceMiles))
                        .foregroundStyle(Theme.muted)
                }
                .font(Theme.captionFont)

                NetworkBadge(inNetwork: provider.isInNetwork(for: plan))
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityAction(named: isFavorite ? "Remove from favorites" : "Add to favorites", onToggleFavorite)
    }
}
