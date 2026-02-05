import Foundation
import SwiftUI
import WidgetKit

/// Service to sync data between the main app and widgets via App Groups
final class WidgetDataService {
    static let shared = WidgetDataService()

    private let appGroupIdentifier = "group.com.life380.app"
    private let membersKey = "widget.family.members"
    private let circleNameKey = "widget.circle.name"
    private let lastUpdateKey = "widget.last.update"

    private var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: appGroupIdentifier)
    }

    private init() {}

    // MARK: - Public API

    /// Update widget with current family member data
    func updateWidgetData(members: [UserProfile], circleName: String?) {
        guard let defaults = sharedDefaults else {
            #if DEBUG
            print("⚠️ WidgetDataService: Failed to access App Group container")
            #endif
            return
        }

        // Convert UserProfile to widget-friendly format
        let widgetMembers = members.map { member in
            WidgetMemberData(
                id: member.id,
                name: member.displayName,
                initials: member.initials,
                status: determineStatus(for: member),
                colorName: colorNameForUser(id: member.id),
                lastUpdated: member.lastUpdated,
                batteryLevel: member.batteryLevel,
                isLocationSharing: member.isLocationSharing
            )
        }

        // Encode and save
        if let data = try? JSONEncoder().encode(widgetMembers) {
            defaults.set(data, forKey: membersKey)
        }

        if let name = circleName {
            defaults.set(name, forKey: circleNameKey)
        }

        defaults.set(Date(), forKey: lastUpdateKey)

        // Trigger widget refresh
        WidgetCenter.shared.reloadTimelines(ofKind: "Life380Widget")

        #if DEBUG
        print("📱 WidgetDataService: Updated widget with \(widgetMembers.count) members")
        #endif
    }

    /// Clear widget data (e.g., on logout)
    func clearWidgetData() {
        guard let defaults = sharedDefaults else { return }

        defaults.removeObject(forKey: membersKey)
        defaults.removeObject(forKey: circleNameKey)
        defaults.removeObject(forKey: lastUpdateKey)

        WidgetCenter.shared.reloadTimelines(ofKind: "Life380Widget")
    }

    // MARK: - Helpers

    private func determineStatus(for member: UserProfile) -> String {
        guard member.isLocationSharing else {
            return "Location off"
        }

        // Check if at a known place (would need places data)
        // For now, return time-based status
        let timeSinceUpdate = Date().timeIntervalSince(member.lastUpdated)

        if timeSinceUpdate > 600 { // 10+ minutes
            return "Last seen \(formatTimeAgo(timeSinceUpdate))"
        } else if timeSinceUpdate > 300 { // 5+ minutes
            return "Idle"
        } else {
            return "Active"
        }
    }

    private func formatTimeAgo(_ interval: TimeInterval) -> String {
        let minutes = Int(interval / 60)
        if minutes < 60 {
            return "\(minutes)m ago"
        }
        let hours = minutes / 60
        if hours < 24 {
            return "\(hours)h ago"
        }
        return "\(hours / 24)d ago"
    }

    /// Convert user ID to a consistent color name for widget display
    /// Uses the same hash approach as UserProfile.color for consistency
    private func colorNameForUser(id: String) -> String {
        let hash = abs(id.hashValue)
        let colorIndex = hash % 6

        // Map to widget's supported colors
        switch colorIndex {
        case 0: return "blue"
        case 1: return "green"
        case 2: return "orange"
        case 3: return "purple"
        case 4: return "red"
        case 5: return "pink"
        default: return "blue"
        }
    }
}

// MARK: - Widget Data Model

/// Data structure for widget (must match what widget expects)
struct WidgetMemberData: Codable {
    let id: String
    let name: String
    let initials: String
    let status: String
    let colorName: String
    let lastUpdated: Date
    let batteryLevel: Int?
    let isLocationSharing: Bool
}

