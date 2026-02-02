import SwiftUI

enum AppColors {
    // Primary
    static let primary = Color("Primary")           // Main brand color
    static let primaryDark = Color("PrimaryDark")
    static let primaryLight = Color("PrimaryLight")

    // Status
    static let success = Color("Success")           // Online/Active
    static let warning = Color("Warning")           // Low battery
    static let error = Color("Error")               // Offline/Error

    // Backgrounds
    static let background = Color("Background")
    static let surface = Color("Surface")
    static let surfaceSecondary = Color("SurfaceSecondary")

    // Text
    static let textPrimary = Color("TextPrimary")
    static let textSecondary = Color("TextSecondary")
    static let textTertiary = Color("TextTertiary")

    // Map
    static let memberPinMe = Color("MemberPinMe")
    static let memberPinOther = Color("MemberPinOther")

    // MARK: - Fallback Colors (used when asset colors not defined)

    static var primaryFallback: Color { Color(red: 0.4, green: 0.49, blue: 0.92) }
    static var successFallback: Color { Color(red: 0.06, green: 0.73, blue: 0.51) }
    static var warningFallback: Color { Color(red: 0.96, green: 0.62, blue: 0.04) }
    static var errorFallback: Color { Color(red: 0.94, green: 0.27, blue: 0.27) }
}
