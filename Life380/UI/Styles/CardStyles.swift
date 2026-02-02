import SwiftUI

/// Standard card style with blur background and shadow
struct CardStyle: ViewModifier {
    @Environment(\.colorScheme) var colorScheme

    func body(content: Content) -> some View {
        content
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.lg, style: .continuous))
            .shadow(color: colorScheme == .dark ? .clear : .black.opacity(0.08), radius: 12, x: 0, y: 4)
    }
}

/// Glass card with material background
struct GlassCard: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.lg, style: .continuous))
    }
}

/// Adaptive card that changes based on color scheme
struct AdaptiveCardStyle: ViewModifier {
    @Environment(\.colorScheme) var colorScheme

    var elevated: Bool = false

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: AppTheme.Radius.lg, style: .continuous)
                    .fill(colorScheme == .dark
                          ? Color(.secondarySystemBackground)
                          : Color(.systemBackground))
                    .shadow(
                        color: colorScheme == .dark
                            ? .clear
                            : .black.opacity(elevated ? 0.12 : 0.06),
                        radius: elevated ? 16 : 8,
                        x: 0,
                        y: elevated ? 8 : 4
                    )
            )
    }
}

/// Outlined card style
struct OutlinedCardStyle: ViewModifier {
    @Environment(\.colorScheme) var colorScheme
    let color: Color

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: AppTheme.Radius.lg, style: .continuous)
                    .fill(colorScheme == .dark
                          ? Color(.secondarySystemBackground)
                          : Color(.systemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.Radius.lg, style: .continuous)
                    .stroke(color.opacity(0.3), lineWidth: 1)
            )
    }
}

// MARK: - View Extensions

extension View {
    func cardStyle() -> some View {
        modifier(CardStyle())
    }

    func glassCard() -> some View {
        modifier(GlassCard())
    }

    func adaptiveCard(elevated: Bool = false) -> some View {
        modifier(AdaptiveCardStyle(elevated: elevated))
    }

    func outlinedCard(color: Color = AppTheme.Colors.primaryGradientStart) -> some View {
        modifier(OutlinedCardStyle(color: color))
    }
}

#Preview {
    VStack(spacing: 20) {
        Text("Card Style")
            .padding()
            .frame(maxWidth: .infinity)
            .cardStyle()

        Text("Glass Card")
            .padding()
            .frame(maxWidth: .infinity)
            .glassCard()

        Text("Adaptive Card")
            .padding()
            .frame(maxWidth: .infinity)
            .adaptiveCard()

        Text("Elevated Card")
            .padding()
            .frame(maxWidth: .infinity)
            .adaptiveCard(elevated: true)

        Text("Outlined Card")
            .padding()
            .frame(maxWidth: .infinity)
            .outlinedCard()
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}
