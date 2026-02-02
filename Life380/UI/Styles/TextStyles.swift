import SwiftUI

/// Title text style
struct TitleTextStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(AppTheme.Typography.title)
            .foregroundColor(AppTheme.Colors.primaryText)
    }
}

/// Headline text style
struct HeadlineTextStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(AppTheme.Typography.headline)
            .foregroundColor(AppTheme.Colors.primaryText)
    }
}

/// Body text style
struct BodyTextStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(AppTheme.Typography.body)
            .foregroundColor(AppTheme.Colors.primaryText)
    }
}

/// Secondary text style
struct SecondaryTextStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(AppTheme.Typography.subheadline)
            .foregroundColor(AppTheme.Colors.secondaryText)
    }
}

/// Caption text style
struct CaptionTextStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(AppTheme.Typography.caption)
            .foregroundColor(AppTheme.Colors.tertiaryText)
    }
}

/// Error text style
struct ErrorTextStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(AppTheme.Typography.caption)
            .foregroundColor(AppTheme.Colors.error)
    }
}

// MARK: - View Extensions

extension View {
    func titleStyle() -> some View {
        modifier(TitleTextStyle())
    }

    func headlineStyle() -> some View {
        modifier(HeadlineTextStyle())
    }

    func bodyStyle() -> some View {
        modifier(BodyTextStyle())
    }

    func secondaryStyle() -> some View {
        modifier(SecondaryTextStyle())
    }

    func captionStyle() -> some View {
        modifier(CaptionTextStyle())
    }

    func errorStyle() -> some View {
        modifier(ErrorTextStyle())
    }
}

// MARK: - Text Extensions

extension Text {
    func titleStyle() -> some View {
        modifier(TitleTextStyle())
    }

    func headlineStyle() -> some View {
        modifier(HeadlineTextStyle())
    }

    func bodyStyle() -> some View {
        modifier(BodyTextStyle())
    }

    func secondaryStyle() -> some View {
        modifier(SecondaryTextStyle())
    }

    func captionStyle() -> some View {
        modifier(CaptionTextStyle())
    }

    func errorStyle() -> some View {
        modifier(ErrorTextStyle())
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 16) {
        Text("Title Text").titleStyle()
        Text("Headline Text").headlineStyle()
        Text("Body Text").bodyStyle()
        Text("Secondary Text").secondaryStyle()
        Text("Caption Text").captionStyle()
        Text("Error Text").errorStyle()
    }
    .padding()
}
