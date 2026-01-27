import SwiftUI

struct CircleView: View {
    @EnvironmentObject var firestoreService: FirestoreService

    var body: some View {
        NavigationStack {
            List {
                if let currentCircle = firestoreService.circles.first(where: { $0.id == firestoreService.currentCircleId }) {
                    Section {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(currentCircle.name)
                                    .font(.headline)
                                Text("Invite Code: \(currentCircle.inviteCode)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            Button(action: {
                                UIPasteboard.general.string = currentCircle.inviteCode
                            }) {
                                Image(systemName: "doc.on.doc")
                            }

                            ShareLink(item: "Join my Life380 circle! Use code: \(currentCircle.inviteCode)") {
                                Image(systemName: "square.and.arrow.up")
                            }
                        }
                    } header: {
                        Text("Current Circle")
                    }
                }

                Section {
                    ForEach(firestoreService.circleMembers) { member in
                        MemberRow(member: member)
                    }
                } header: {
                    Text("Members (\(firestoreService.circleMembers.count))")
                }

                Section {
                    Button(action: inviteMember) {
                        Label("Invite New Member", systemImage: "person.badge.plus")
                    }
                }
            }
            .navigationTitle("My Circle")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        ForEach(firestoreService.circles) { circle in
                            Button(action: {
                                firestoreService.switchCircle(to: circle.id)
                            }) {
                                HStack {
                                    Text(circle.name)
                                    if circle.id == firestoreService.currentCircleId {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }

                        Divider()

                        NavigationLink {
                            CreateCircleView()
                        } label: {
                            Label("Create New Circle", systemImage: "plus.circle")
                        }

                        NavigationLink {
                            JoinCircleView()
                        } label: {
                            Label("Join Circle", systemImage: "person.badge.plus")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .refreshable {
                // Refresh circle members
                if let circleId = firestoreService.currentCircleId {
                    firestoreService.listenToCircleMembers(circleId: circleId)
                }
            }
        }
    }

    private func inviteMember() {
        guard let circle = firestoreService.circles.first(where: { $0.id == firestoreService.currentCircleId }) else { return }

        let shareText = "Join my Life380 circle! Download the app and use invite code: \(circle.inviteCode)"
        let activityVC = UIActivityViewController(activityItems: [shareText], applicationActivities: nil)

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            rootVC.present(activityVC, animated: true)
        }
    }
}

struct MemberRow: View {
    let member: UserProfile

    var body: some View {
        HStack(spacing: 12) {
            Text(member.initials)
                .font(.headline)
                .foregroundColor(.white)
                .frame(width: 50, height: 50)
                .background(member.color)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(member.displayName)
                    .font(.headline)

                if member.isLocationSharing {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.caption)
                        Text(member.lastUpdatedText)
                            .font(.caption)
                    }
                    .foregroundColor(.secondary)
                } else {
                    HStack(spacing: 4) {
                        Image(systemName: "location.slash")
                            .font(.caption)
                        Text("Location sharing off")
                            .font(.caption)
                    }
                    .foregroundColor(.orange)
                }
            }

            Spacer()

            if member.isLocationSharing {
                VStack(spacing: 4) {
                    Image(systemName: member.batteryIcon)
                        .foregroundColor(member.batteryColor)
                    Text("\(member.batteryLevel)%")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    CircleView()
        .environmentObject(FirestoreService.shared)
}
