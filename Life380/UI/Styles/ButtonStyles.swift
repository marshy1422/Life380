import SwiftUI

/// Primary gradient button style
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

/// Secondary outline button style
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

/// Destructive button style for dangerous actions
struct DestructiveButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppTheme.Typography.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(isEnabled ? Color.red : Color.gray.opacity(0.3))
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.md, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: configuration.isPressed)
    }
}

/// Small pill button style
struct PillButtonStyle: ButtonStyle {
    let color: Color

    init(color: Color = AppTheme.Colors.primaryGradientStart) {
        self.color = color
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppTheme.Typography.caption)
            .foregroundStyle(color)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(color.opacity(0.15))
            .clipShape(Capsule())
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

/// Icon button style
struct IconButtonStyle: ButtonStyle {
    let size: CGFloat
    let backgroundColor: Color

    init(size: CGFloat = 44, backgroundColor: Color = .clear) {
        self.size = size
        self.backgroundColor = backgroundColor
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(width: size, height: size)
            .background(backgroundColor)
            .clipShape(Circle())
            .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Button Style Extensions

extension Button {
    func primaryStyle() -> some View {
        buttonStyle(PrimaryButtonStyle())
    }

    func secondaryStyle() -> some View {
        buttonStyle(SecondaryButtonStyle())
    }

    func destructiveStyle() -> some View {
        buttonStyle(DestructiveButtonStyle())
    }

    func pillStyle(color: Color = AppTheme.Colors.primaryGradientStart) -> some View {
        buttonStyle(PillButtonStyle(color: color))
    }

    func iconStyle(size: CGFloat = 44, backgroundColor: Color = .clear) -> some View {
        buttonStyle(IconButtonStyle(size: size, backgroundColor: backgroundColor))
    }
}

#Preview {
    VStack(spacing: 20) {
        Button("Primary Button") {}
            .primaryStyle()

        Button("Secondary Button") {}
            .secondaryStyle()

        Button("Delete Account") {}
            .destructiveStyle()

        Button("Pill Button") {}
            .pillStyle()

        Button {
        } label: {
            Image(systemName: "plus")
        }
        .iconStyle(size: 44, backgroundColor: AppTheme.Colors.primaryGradientStart.opacity(0.1))
    }
    .padding()
}
