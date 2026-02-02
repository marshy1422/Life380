import SwiftUI

/// App spacing definitions
struct AppSpacing {
    // MARK: - Base Spacing Values

    static let xxs: CGFloat = 4
    static let xs: CGFloat = 8
    static let sm: CGFloat = 12
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
    static let xxl: CGFloat = 48

    // MARK: - Screen Padding

    static let screenHorizontal: CGFloat = 16
    static let screenVertical: CGFloat = 20

    // MARK: - Component Spacing

    static let cardPadding: CGFloat = 16
    static let listRowPadding: CGFloat = 12
    static let sectionSpacing: CGFloat = 24
    static let formSpacing: CGFloat = 16
}

/// App corner radius definitions
struct AppRadius {
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 24
    static let full: CGFloat = 9999
}

// MARK: - Backward Compatibility

extension AppTheme {
    typealias Spacing = AppSpacing
    typealias Radius = AppRadius
}
