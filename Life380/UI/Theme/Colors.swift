import SwiftUI
import UIKit

/// App color definitions
struct AppColors {
    // MARK: - Primary Brand Colors (purple/indigo gradient)

    static let primaryGradientStart = Color(red: 0.4, green: 0.49, blue: 0.92)
    static let primaryGradientEnd = Color(red: 0.46, green: 0.29, blue: 0.64)

    // MARK: - Semantic Colors

    static let success = Color(red: 0.06, green: 0.73, blue: 0.51)
    static let warning = Color(red: 0.96, green: 0.62, blue: 0.04)
    static let error = Color(red: 0.94, green: 0.27, blue: 0.27)

    // MARK: - Adaptive Background Colors

    static var cardBackground: Color { Color(UIColor.systemBackground) }
    static var secondaryCardBackground: Color { Color(UIColor.secondarySystemBackground) }
    static var tertiaryCardBackground: Color { Color(UIColor.tertiarySystemBackground) }
    static var groupedBackground: Color { Color(UIColor.systemGroupedBackground) }
    static var secondaryGroupedBackground: Color { Color(UIColor.secondarySystemGroupedBackground) }

    // MARK: - Adaptive Text Colors

    static var primaryText: Color { Color(UIColor.label) }
    static var secondaryText: Color { Color(UIColor.secondaryLabel) }
    static var tertiaryText: Color { Color(UIColor.tertiaryLabel) }

    // MARK: - Separator Colors

    static var separator: Color { Color(UIColor.separator) }
    static var opaqueSeparator: Color { Color(UIColor.opaqueSeparator) }

    // MARK: - Gradient Presets

    static let primaryGradient = LinearGradient(
        colors: [primaryGradientStart, primaryGradientEnd],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Dark mode aware gradient
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

    // MARK: - Location Accuracy Colors

    static func forAccuracy(_ accuracy: Double) -> Color {
        switch accuracy {
        case ..<5: return .green
        case 5..<15: return .blue
        case 15..<50: return .teal
        case 50..<100: return .orange
        default: return .red
        }
    }

    // MARK: - Battery Level Colors

    static func forBatteryLevel(_ level: Int) -> Color {
        switch level {
        case 0...20: return .red
        case 21...50: return .orange
        default: return .green
        }
    }
}

// MARK: - Backward Compatibility

extension AppTheme {
    typealias Colors = AppColors
}
