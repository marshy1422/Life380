import SwiftUI

/// Empty state view for when there's no content
struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    let actionTitle: String?
    let action: (() -> Void)?

    init(
        icon: String,
        title: String,
        message: String,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.icon = icon
        self.title = title
        self.message = message
        self.actionTitle = actionTitle
        self.action = action
    }

    var body: some View {
        VStack(spacing: AppTheme.Spacing.lg) {
            Image(systemName: icon)
                .font(.system(size: 64))
                .foregroundColor(AppTheme.Colors.secondaryText.opacity(0.5))

            VStack(spacing: AppTheme.Spacing.xs) {
                Text(title)
                    .font(AppTheme.Typography.title3)
                    .foregroundColor(AppTheme.Colors.primaryText)

                Text(message)
                    .font(AppTheme.Typography.body)
                    .foregroundColor(AppTheme.Colors.secondaryText)
                    .multilineTextAlignment(.center)
            }

            if let actionTitle = actionTitle, let action = action {
                Button(actionTitle, action: action)
                    .buttonStyle(PrimaryButtonStyle())
                    .padding(.horizontal, AppTheme.Spacing.xl)
            }
        }
        .padding(AppTheme.Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Preset Empty States

extension EmptyStateView {
    /// No circles empty state
    static func noCircles(action: @escaping () -> Void) -> EmptyStateView {
        EmptyStateView(
            icon: "person.3",
            title: "No Circles Yet",
            message: "Create a circle to start sharing your location with family and friends.",
            actionTitle: "Create Circle",
            action: action
        )
    }

    /// No places empty state
    static func noPlaces(action: @escaping () -> Void) -> EmptyStateView {
        EmptyStateView(
            icon: "mappin.and.ellipse",
            title: "No Places Saved",
            message: "Add places like Home or Work to get notified when family members arrive or leave.",
            actionTitle: "Add Place",
            action: action
        )
    }

    /// No members empty state
    static func noMembers(action: @escaping () -> Void) -> EmptyStateView {
        EmptyStateView(
            icon: "person.badge.plus",
            title: "No Members",
            message: "Invite family members to join your circle and start sharing locations.",
            actionTitle: "Invite Members",
            action: action
        )
    }

    /// No location permission
    static func noLocationPermission(action: @escaping () -> Void) -> EmptyStateView {
        EmptyStateView(
            icon: "location.slash",
            title: "Location Access Required",
            message: "Life380 needs location access to share your location with your circle.",
            actionTitle: "Open Settings",
            action: action
        )
    }

    /// Search no results
    static func searchNoResults(query: String) -> EmptyStateView {
        EmptyStateView(
            icon: "magnifyingglass",
            title: "No Results",
            message: "No results found for \"\(query)\". Try a different search."
        )
    }
}

#Preview {
    EmptyStateView.noCircles {}
}
