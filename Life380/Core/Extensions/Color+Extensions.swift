import SwiftUI
import UIKit

extension Color {
    // MARK: - Hex Initialization

    /// Creates a Color from a hex string (e.g., "#FF5733" or "FF5733")
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0

        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else {
            return nil
        }

        let length = hexSanitized.count
        if length == 6 {
            self.init(
                red: Double((rgb & 0xFF0000) >> 16) / 255.0,
                green: Double((rgb & 0x00FF00) >> 8) / 255.0,
                blue: Double(rgb & 0x0000FF) / 255.0
            )
        } else if length == 8 {
            self.init(
                red: Double((rgb & 0xFF000000) >> 24) / 255.0,
                green: Double((rgb & 0x00FF0000) >> 16) / 255.0,
                blue: Double((rgb & 0x0000FF00) >> 8) / 255.0,
                opacity: Double(rgb & 0x000000FF) / 255.0
            )
        } else {
            return nil
        }
    }

    // MARK: - Hex Conversion

    /// Converts the Color to a hex string
    func toHex() -> String? {
        guard let components = UIColor(self).cgColor.components, components.count >= 3 else {
            return nil
        }

        let r = Float(components[0])
        let g = Float(components[1])
        let b = Float(components[2])

        return String(format: "#%02lX%02lX%02lX", lroundf(r * 255), lroundf(g * 255), lroundf(b * 255))
    }

    // MARK: - Color from String

    /// Creates a consistent color from any string (useful for user avatars)
    static func fromString(_ string: String) -> Color {
        let hash = string.hashValue
        let hue = Double(abs(hash) % 360) / 360.0
        return Color(hue: hue, saturation: 0.6, brightness: 0.8)
    }

    // MARK: - Color Manipulation

    /// Returns a lighter version of the color
    func lighter(by percentage: CGFloat = 0.2) -> Color {
        return adjust(by: abs(percentage))
    }

    /// Returns a darker version of the color
    func darker(by percentage: CGFloat = 0.2) -> Color {
        return adjust(by: -abs(percentage))
    }

    private func adjust(by percentage: CGFloat) -> Color {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0

        UIColor(self).getRed(&red, green: &green, blue: &blue, alpha: &alpha)

        return Color(
            red: min(max(red + percentage, 0), 1),
            green: min(max(green + percentage, 0), 1),
            blue: min(max(blue + percentage, 0), 1),
            opacity: alpha
        )
    }

    // MARK: - Semantic Colors

    /// Battery color based on level
    static func forBatteryLevel(_ level: Int) -> Color {
        switch level {
        case 0...20: return .red
        case 21...50: return .orange
        default: return .green
        }
    }

    /// Location accuracy color
    static func forAccuracy(_ accuracy: Double) -> Color {
        switch accuracy {
        case ..<5: return .green
        case 5..<15: return .blue
        case 15..<50: return .teal
        case 50..<100: return .orange
        default: return .red
        }
    }
}
