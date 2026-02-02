import SwiftUI

/// Circular icon button
struct IconButton: View {
    let icon: String
    let color: Color
    let size: CGFloat
    let action: () -> Void

    init(
        icon: String,
        color: Color = AppTheme.Colors.primaryGradientStart,
        size: CGFloat = 44,
        action: @escaping () -> Void
    ) {
        self.icon = icon
        self.color = color
        self.size = size
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: size * 0.4))
                .foregroundColor(color)
                .frame(width: size, height: size)
                .background(color.opacity(0.12))
                .clipShape(Circle())
        }
    }
}

/// Circular icon button with fill
struct FilledIconButton: View {
    let icon: String
    let color: Color
    let size: CGFloat
    let action: () -> Void

    init(
        icon: String,
        color: Color = AppTheme.Colors.primaryGradientStart,
        size: CGFloat = 44,
        action: @escaping () -> Void
    ) {
        self.icon = icon
        self.color = color
        self.size = size
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: size * 0.4))
                .foregroundColor(.white)
                .frame(width: size, height: size)
                .background(color)
                .clipShape(Circle())
        }
    }
}

#Preview {
    HStack(spacing: 20) {
        IconButton(icon: "plus") {}
        IconButton(icon: "gear", color: .gray) {}
        FilledIconButton(icon: "location.fill") {}
        FilledIconButton(icon: "bell.fill", color: .orange) {}
    }
    .padding()
}
