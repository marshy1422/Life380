import SwiftUI

/// Full screen loading overlay
struct LoadingView: View {
    let message: String?

    init(_ message: String? = nil) {
        self.message = message
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()

            VStack(spacing: AppTheme.Spacing.md) {
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(.white)

                if let message = message {
                    Text(message)
                        .font(AppTheme.Typography.subheadline)
                        .foregroundColor(.white)
                }
            }
            .padding(AppTheme.Spacing.xl)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.lg))
        }
    }
}

/// Inline loading indicator
struct InlineLoadingView: View {
    let message: String

    var body: some View {
        HStack(spacing: AppTheme.Spacing.sm) {
            ProgressView()
            Text(message)
                .font(AppTheme.Typography.subheadline)
                .foregroundColor(AppTheme.Colors.secondaryText)
        }
    }
}

/// Loading placeholder for content
struct LoadingPlaceholder: View {
    var body: some View {
        VStack(spacing: AppTheme.Spacing.md) {
            ProgressView()
            Text("Loading...")
                .font(AppTheme.Typography.subheadline)
                .foregroundColor(AppTheme.Colors.secondaryText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    ZStack {
        Color.gray.opacity(0.3).ignoresSafeArea()
        LoadingView("Please wait...")
    }
}
