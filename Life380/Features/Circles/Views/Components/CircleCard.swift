import SwiftUI

struct CircleCard: View {
    let circle: FamilyCircle
    let memberCount: Int
    let recentMembers: [UserProfile]

    init(circle: FamilyCircle, memberCount: Int = 0, recentMembers: [UserProfile] = []) {
        self.circle = circle
        self.memberCount = memberCount > 0 ? memberCount : circle.memberIds.count
        self.recentMembers = recentMembers
    }

    var body: some View {
        HStack(spacing: AppTheme.Spacing.md) {
            // Circle Icon
            ZStack {
                Circle()
                    .fill(AppTheme.Colors.primaryGradient)
                    .frame(width: 56, height: 56)

                Text(circle.name.prefix(1).uppercased())
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
            }

            // Info
            VStack(alignment: .leading, spacing: AppTheme.Spacing.xxs) {
                Text(circle.name)
                    .font(AppTheme.Typography.title3)
                    .foregroundColor(AppTheme.Colors.primaryText)

                Text("\(memberCount) member\(memberCount == 1 ? "" : "s")")
                    .font(AppTheme.Typography.subheadline)
                    .foregroundColor(AppTheme.Colors.secondaryText)
            }

            Spacer()

            // Member avatars stack
            if !recentMembers.isEmpty {
                HStack(spacing: -8) {
                    ForEach(recentMembers.prefix(3)) { member in
                        MemberAvatarView(member: member, size: 32)
                    }
                }
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(AppTheme.Colors.tertiaryText)
        }
        .padding(AppTheme.Spacing.md)
        .background(AppTheme.Colors.cardBackground)
        .cornerRadius(AppTheme.Radius.lg)
        .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
    }
}

// MARK: - Member Avatar View

struct MemberAvatarView: View {
    let member: UserProfile
    let size: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .fill(colorForMember)
                .frame(width: size, height: size)

            Text(member.displayName.prefix(1).uppercased())
                .font(.system(size: size * 0.4, weight: .semibold))
                .foregroundColor(.white)
        }
        .overlay(
            Circle()
                .stroke(Color.white, lineWidth: 2)
        )
    }

    private var colorForMember: Color {
        let colors: [Color] = [
            .blue, .green, .orange, .purple, .pink, .teal
        ]
        let index = abs(member.id.hashValue) % colors.count
        return colors[index]
    }
}

#Preview {
    VStack {
        CircleCard(
            circle: FamilyCircle(
                id: "1",
                name: "Smith Family",
                createdBy: "user1",
                memberIds: ["user1", "user2", "user3"],
                inviteCode: "ABC123",
                createdAt: Date()
            ),
            memberCount: 3,
            recentMembers: []
        )
    }
    .padding()
}
