import UIKit

/// Haptic feedback utility for consistent haptic patterns throughout the app
enum Haptics {
    // MARK: - Notification Feedback

    /// Triggers a success haptic feedback
    static func success() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }

    /// Triggers a warning haptic feedback
    static func warning() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.warning)
    }

    /// Triggers an error haptic feedback
    static func error() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.error)
    }

    // MARK: - Impact Feedback

    /// Triggers a light impact haptic
    static func light() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }

    /// Triggers a medium impact haptic
    static func medium() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }

    /// Triggers a heavy impact haptic
    static func heavy() {
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.impactOccurred()
    }

    /// Triggers a soft impact haptic
    static func soft() {
        let generator = UIImpactFeedbackGenerator(style: .soft)
        generator.impactOccurred()
    }

    /// Triggers a rigid impact haptic
    static func rigid() {
        let generator = UIImpactFeedbackGenerator(style: .rigid)
        generator.impactOccurred()
    }

    // MARK: - Selection Feedback

    /// Triggers a selection changed haptic
    static func selection() {
        let generator = UISelectionFeedbackGenerator()
        generator.selectionChanged()
    }

    // MARK: - Custom Patterns

    /// Triggers a tap pattern for button presses
    static func tap() {
        light()
    }

    /// Triggers an SOS alert pattern
    static func sosAlert() {
        heavy()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            heavy()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            heavy()
        }
    }

    /// Triggers a location update haptic
    static func locationUpdate() {
        soft()
    }

    /// Triggers a notification received haptic
    static func notificationReceived() {
        medium()
    }
}
