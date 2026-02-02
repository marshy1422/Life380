import SwiftUI

/// Shimmer loading effect for skeleton screens
struct ShimmerView: View {
    @State private var phase: CGFloat = 0

    let width: CGFloat
    let height: CGFloat
    let cornerRadius: CGFloat

    init(width: CGFloat = .infinity, height: CGFloat = 20, cornerRadius: CGFloat = 8) {
        self.width = width
        self.height = height
        self.cornerRadius = cornerRadius
    }

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(Color.gray.opacity(0.3))
            .frame(maxWidth: width == .infinity ? .infinity : width, maxHeight: height)
            .frame(height: height)
            .overlay(
                GeometryReader { geometry in
                    LinearGradient(
                        colors: [
                            Color.clear,
                            Color.white.opacity(0.5),
                            Color.clear
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: geometry.size.width * 0.5)
                    .offset(x: phase * geometry.size.width * 1.5 - geometry.size.width * 0.5)
                }
                .mask(
                    RoundedRectangle(cornerRadius: cornerRadius)
                )
            )
            .onAppear {
                withAnimation(
                    .linear(duration: 1.5)
                    .repeatForever(autoreverses: false)
                ) {
                    phase = 1
                }
            }
    }
}

/// Shimmer loading placeholder for list rows
struct ShimmerListRow: View {
    var body: some View {
        HStack(spacing: AppTheme.Spacing.md) {
            ShimmerView(width: 44, height: 44, cornerRadius: 22)

            VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                ShimmerView(height: 16)
                ShimmerView(width: 150, height: 12)
            }
        }
        .padding(AppTheme.Spacing.md)
    }
}

/// Shimmer loading placeholder for cards
struct ShimmerCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            ShimmerView(height: 20)
            ShimmerView(height: 14)
            ShimmerView(width: 200, height: 14)
        }
        .padding(AppTheme.Spacing.md)
        .background(AppTheme.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.md))
    }
}

#Preview {
    VStack(spacing: 20) {
        ShimmerView(height: 40)

        ShimmerListRow()

        ShimmerCard()
    }
    .padding()
}
