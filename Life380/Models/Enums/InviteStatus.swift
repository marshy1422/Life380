import Foundation

/// Status of a circle invitation
enum InviteStatus: String, Codable, CaseIterable {
    case pending = "pending"       // Invitation sent, not yet used
    case accepted = "accepted"     // Invitation has been accepted
    case expired = "expired"       // Invitation has expired
    case revoked = "revoked"       // Invitation was manually revoked

    var displayName: String {
        switch self {
        case .pending: return "Pending"
        case .accepted: return "Accepted"
        case .expired: return "Expired"
        case .revoked: return "Revoked"
        }
    }

    var iconName: String {
        switch self {
        case .pending: return "clock.fill"
        case .accepted: return "checkmark.circle.fill"
        case .expired: return "xmark.circle.fill"
        case .revoked: return "nosign"
        }
    }

    var color: String {
        switch self {
        case .pending: return "orange"
        case .accepted: return "green"
        case .expired: return "gray"
        case .revoked: return "red"
        }
    }

    var isActive: Bool {
        self == .pending
    }
}
