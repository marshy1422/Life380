import Foundation

/// Status of a circle member
enum MemberStatus: String, Codable, CaseIterable {
    case active = "active"           // Member is active and sharing location
    case inactive = "inactive"       // Member has disabled location sharing
    case offline = "offline"         // Member hasn't updated in a while
    case pending = "pending"         // Invitation accepted but not yet set up

    var displayName: String {
        switch self {
        case .active: return "Active"
        case .inactive: return "Inactive"
        case .offline: return "Offline"
        case .pending: return "Pending"
        }
    }

    var iconName: String {
        switch self {
        case .active: return "checkmark.circle.fill"
        case .inactive: return "pause.circle.fill"
        case .offline: return "wifi.slash"
        case .pending: return "clock.fill"
        }
    }

    var color: String {
        switch self {
        case .active: return "green"
        case .inactive: return "gray"
        case .offline: return "orange"
        case .pending: return "blue"
        }
    }
}
