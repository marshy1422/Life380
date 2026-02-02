import SwiftUI

/// App shadow definitions
struct AppShadows {
    // MARK: - Shadow Presets

    /// Light shadow for cards and elevated elements
    static func card(colorScheme: ColorScheme) -> some View {
        Color.clear
            .shadow(
                color: colorScheme == .dark ? .clear : .black.opacity(0.08),
                radius: 12,
                x: 0,
                y: 4
            )
    }

    /// Elevated shadow for floating elements
    static func elevated(colorScheme: ColorScheme) -> some View {
        Color.clear
            .shadow(
                color: colorScheme == .dark ? .clear : .black.opacity(0.12),
                radius: 16,
                x: 0,
                y: 8
            )
    }

    /// Subtle shadow for buttons
    static func button(colorScheme: ColorScheme) -> some View {
        Color.clear
            .shadow(
                color: colorScheme == .dark ? .clear : .black.opacity(0.06),
                radius: 8,
                x: 0,
                y: 4
            )
    }
}

// MARK: - Shadow View Modifier

struct ShadowModifier: ViewModifier {
    @Environment(\.colorScheme) var colorScheme

    enum Style {
        case card
        case elevated
        case button
    }

    let style: Style

    func body(content: Content) -> some View {
        switch style {
        case .card:
            content.shadow(
                color: colorScheme == .dark ? .clear : .black.opacity(0.08),
                radius: 12,
                x: 0,
                y: 4
            )
        case .elevated:
            content.shadow(
                color: colorScheme == .dark ? .clear : .black.opacity(0.12),
                radius: 16,
                x: 0,
                y: 8
            )
        case .button:
            content.shadow(
                color: colorScheme == .dark ? .clear : .black.opacity(0.06),
                radius: 8,
                x: 0,
                y: 4
            )
        }
    }
}

extension View {
    func appShadow(_ style: ShadowModifier.Style) -> some View {
        modifier(ShadowModifier(style: style))
    }
}
