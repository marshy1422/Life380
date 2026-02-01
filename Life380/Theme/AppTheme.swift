import SwiftUI
import UIKit
import AuthenticationServices

// MARK: - App Theme
struct AppTheme {
    // MARK: - Colors
    struct Colors {
        // Primary brand colors (purple/indigo gradient)
        static let primaryGradientStart = Color(red: 0.4, green: 0.49, blue: 0.92)
        static let primaryGradientEnd = Color(red: 0.46, green: 0.29, blue: 0.64)

        // Semantic colors
        static let success = Color(red: 0.06, green: 0.73, blue: 0.51)
        static let warning = Color(red: 0.96, green: 0.62, blue: 0.04)
        static let error = Color(red: 0.94, green: 0.27, blue: 0.27)

        // Adaptive colors for dark mode (use in View context)
        static var cardBackground: Color { Color(UIColor.systemBackground) }
        static var secondaryCardBackground: Color { Color(UIColor.secondarySystemBackground) }
        static var tertiaryCardBackground: Color { Color(UIColor.tertiarySystemBackground) }
        static var groupedBackground: Color { Color(UIColor.systemGroupedBackground) }
        static var secondaryGroupedBackground: Color { Color(UIColor.secondarySystemGroupedBackground) }

        // Text colors (adaptive)
        static var primaryText: Color { Color(UIColor.label) }
        static var secondaryText: Color { Color(UIColor.secondaryLabel) }
        static var tertiaryText: Color { Color(UIColor.tertiaryLabel) }

        // Separator colors
        static var separator: Color { Color(UIColor.separator) }
        static var opaqueSeparator: Color { Color(UIColor.opaqueSeparator) }

        // Gradient presets
        static let primaryGradient = LinearGradient(
            colors: [primaryGradientStart, primaryGradientEnd],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        // Dark mode aware gradient
        static func adaptiveGradient(for colorScheme: ColorScheme) -> LinearGradient {
            if colorScheme == .dark {
                return LinearGradient(
                    colors: [
                        primaryGradientStart.opacity(0.8),
                        primaryGradientEnd.opacity(0.7)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
            return primaryGradient
        }
    }

    // MARK: - Typography
    struct Typography {
        static let largeTitle = Font.system(.largeTitle, design: .rounded).weight(.bold)
        static let title = Font.system(.title, design: .rounded).weight(.semibold)
        static let title2 = Font.system(.title2, design: .rounded).weight(.semibold)
        static let title3 = Font.system(.title3, design: .rounded).weight(.medium)
        static let headline = Font.system(.headline, design: .rounded)
        static let body = Font.system(.body, design: .default)
        static let callout = Font.system(.callout, design: .default)
        static let subheadline = Font.system(.subheadline, design: .default)
        static let footnote = Font.system(.footnote, design: .default)
        static let caption = Font.system(.caption, design: .default)
    }

    // MARK: - Spacing
    struct Spacing {
        static let xxs: CGFloat = 4
        static let xs: CGFloat = 8
        static let sm: CGFloat = 12
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
        static let xxl: CGFloat = 48
    }

    // MARK: - Radius
    struct Radius {
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 24
        static let full: CGFloat = 9999
    }
}

// MARK: - Reusable View Modifiers
struct CardStyle: ViewModifier {
    @Environment(\.colorScheme) var colorScheme

    func body(content: Content) -> some View {
        content
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.lg, style: .continuous))
            .shadow(color: colorScheme == .dark ? .clear : .black.opacity(0.08), radius: 12, x: 0, y: 4)
    }
}

struct GlassCard: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.lg, style: .continuous))
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppTheme.Typography.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                Group {
                    if isEnabled {
                        AppTheme.Colors.primaryGradient
                    } else {
                        Color.gray.opacity(0.3)
                    }
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.md, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppTheme.Typography.headline)
            .foregroundStyle(AppTheme.Colors.primaryGradientStart)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.Radius.md, style: .continuous)
                    .stroke(AppTheme.Colors.primaryGradientStart.opacity(0.3), lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: configuration.isPressed)
    }
}

// MARK: - Adaptive Card Style
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

// MARK: - Dark Mode Aware Badge Style
struct AdaptiveBadgeStyle: ViewModifier {
    @Environment(\.colorScheme) var colorScheme
    let color: Color

    func body(content: Content) -> some View {
        content
            .foregroundColor(colorScheme == .dark ? color : .white)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(colorScheme == .dark ? color.opacity(0.2) : color)
            )
            .overlay(
                Capsule()
                    .strokeBorder(color.opacity(colorScheme == .dark ? 0.4 : 0), lineWidth: 1)
            )
    }
}

// MARK: - Adaptive List Row Style
struct AdaptiveListRowStyle: ViewModifier {
    @Environment(\.colorScheme) var colorScheme

    func body(content: Content) -> some View {
        content
            .listRowBackground(
                colorScheme == .dark
                    ? Color(.secondarySystemGroupedBackground)
                    : Color(.systemBackground)
            )
            .listRowSeparatorTint(colorScheme == .dark ? .gray.opacity(0.3) : nil)
    }
}

// MARK: - Adaptive Icon Background
struct AdaptiveIconBackground: ViewModifier {
    @Environment(\.colorScheme) var colorScheme
    let color: Color

    func body(content: Content) -> some View {
        content
            .foregroundColor(color)
            .padding(10)
            .background(
                Circle()
                    .fill(colorScheme == .dark
                          ? color.opacity(0.15)
                          : color.opacity(0.12))
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

    func adaptiveBadge(color: Color) -> some View {
        modifier(AdaptiveBadgeStyle(color: color))
    }

    func adaptiveListRow() -> some View {
        modifier(AdaptiveListRowStyle())
    }

    func adaptiveIconBackground(color: Color) -> some View {
        modifier(AdaptiveIconBackground(color: color))
    }
}

// MARK: - Color Scheme Helper
extension ColorScheme {
    var isDark: Bool {
        self == .dark
    }
}

// MARK: - Adaptive Sign In With Apple Button Style
extension SignInWithAppleButton.Style {
    static func adaptive(for colorScheme: ColorScheme) -> SignInWithAppleButton.Style {
        colorScheme == .dark ? .white : .black
    }
}
