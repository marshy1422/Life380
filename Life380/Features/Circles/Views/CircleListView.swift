import SwiftUI
import UIKit

struct CircleView: View {
    @EnvironmentObject var firestoreService: FirestoreService
    @Binding var memberToLocate: UserProfile?
    @Binding var selectedTab: Int
    @State private var showingCreateCircle = false
    @State private var showingJoinCircle = false
    @State private var showingManageCircles = false
    @State private var deepLinkCode: String?

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
                        MemberRow(member: member, onLocate: {
                            locateMember(member)
                        })
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

                        Button {
                            showingCreateCircle = true
                        } label: {
                            Label("Create New Circle", systemImage: "plus.circle")
                        }

                        Button {
                            showingJoinCircle = true
                        } label: {
                            Label("Join Circle", systemImage: "person.badge.plus")
                        }

                        Divider()

                        Button {
                            showingManageCircles = true
                        } label: {
                            Label("Manage Circles", systemImage: "gearshape")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .sheet(isPresented: $showingCreateCircle) {
                CreateCircleSheet()
            }
            .sheet(isPresented: $showingJoinCircle) {
                JoinCircleSheet(prefilledCode: deepLinkCode)
                    .onDisappear {
                        deepLinkCode = nil
                    }
            }
            .sheet(isPresented: $showingManageCircles) {
                ManageCirclesSheet()
            }
            .onReceive(NotificationCenter.default.publisher(for: .joinCircleDeepLink)) { notification in
                if let code = notification.userInfo?["code"] as? String {
                    deepLinkCode = code
                    showingJoinCircle = true
                }
            }
            .refreshable {
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

    private func locateMember(_ member: UserProfile) {
        guard member.coordinate != nil else { return }
        memberToLocate = member
        selectedTab = 0  // Switch to Map tab
    }
}

// MARK: - Create Circle Sheet

struct CreateCircleSheet: View {
    @EnvironmentObject var firestoreService: FirestoreService
    @Environment(\.dismiss) private var dismiss

    @State private var circleName = ""
    @State private var isCreating = false
    @State private var errorMessage: String?
    @State private var createdCircle: FamilyCircle?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Circle Name", text: $circleName)
                        .textContentType(.organizationName)
                } header: {
                    Text("Circle Details")
                } footer: {
                    Text("Choose a name like \"Smith Family\" or \"Close Friends\"")
                }

                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                    }
                }

                if let circle = createdCircle {
                    Section {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text("Circle Created!")
                                    .font(.headline)
                            }

                            Divider()

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Invite Code")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                HStack {
                                    Text(circle.inviteCode)
                                        .font(.system(.title2, design: .monospaced))
                                        .fontWeight(.bold)
                                    Spacer()
                                    Button {
                                        UIPasteboard.general.string = circle.inviteCode
                                    } label: {
                                        Image(systemName: "doc.on.doc")
                                    }
                                }
                            }

                            Text("Share this code with family members.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    Section {
                        Button("Done") { dismiss() }
                    }
                } else {
                    Section {
                        Button {
                            createCircle()
                        } label: {
                            HStack {
                                Spacer()
                                if isCreating {
                                    ProgressView()
                                        .padding(.trailing, 8)
                                }
                                Text(isCreating ? "Creating..." : "Create Circle")
                                Spacer()
                            }
                        }
                        .disabled(circleName.trimmingCharacters(in: .whitespaces).isEmpty || isCreating)
                    }
                }
            }
            .navigationTitle("Create Circle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func createCircle() {
        let name = circleName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }

        isCreating = true
        errorMessage = nil

        Task {
            do {
                let circle = try await firestoreService.createCircle(name: name)
                createdCircle = circle
            } catch {
                errorMessage = error.localizedDescription
            }
            isCreating = false
        }
    }
}

// MARK: - Join Circle Sheet

struct JoinCircleSheet: View {
    @EnvironmentObject var firestoreService: FirestoreService
    @Environment(\.dismiss) private var dismiss

    var prefilledCode: String?

    @State private var inviteCode = ""
    @State private var isJoining = false
    @State private var errorMessage: String?
    @State private var joinedCircle: FamilyCircle?
    @FocusState private var isCodeFieldFocused: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Invite Code", text: $inviteCode)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .font(.system(.title3, design: .monospaced))
                        .focused($isCodeFieldFocused)
                        .onChange(of: inviteCode) { _, newValue in
                            let filtered = String(newValue.uppercased().prefix(6))
                            if filtered != newValue {
                                inviteCode = filtered
                            }
                        }
                } header: {
                    Text("Enter Invite Code")
                } footer: {
                    Text("Ask a circle member to share their 6-character invite code.")
                }

                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                    }
                }

                if let circle = joinedCircle {
                    Section {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text("Joined Successfully!")
                                    .font(.headline)
                            }

                            Divider()

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Circle Name")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(circle.name)
                                    .font(.title3)
                                    .fontWeight(.semibold)
                            }

                            Text("\(circle.memberIds.count) member\(circle.memberIds.count == 1 ? "" : "s")")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    Section {
                        Button("Done") { dismiss() }
                    }
                } else {
                    Section {
                        Button {
                            joinCircle()
                        } label: {
                            HStack {
                                Spacer()
                                if isJoining {
                                    ProgressView()
                                        .padding(.trailing, 8)
                                }
                                Text(isJoining ? "Joining..." : "Join Circle")
                                Spacer()
                            }
                        }
                        .disabled(inviteCode.count != 6 || isJoining)
                    }
                }
            }
            .navigationTitle("Join Circle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear {
                if let code = prefilledCode, !code.isEmpty {
                    inviteCode = code.uppercased()
                    joinCircle()
                } else {
                    isCodeFieldFocused = true
                }
            }
        }
    }

    private func joinCircle() {
        let code = inviteCode.trimmingCharacters(in: .whitespaces).uppercased()
        guard code.count == 6 else { return }

        isJoining = true
        errorMessage = nil

        Task {
            do {
                let circle = try await firestoreService.joinCircle(inviteCode: code)
                joinedCircle = circle
            } catch {
                if let circleError = error as? FirestoreService.CircleError {
                    errorMessage = circleError.localizedDescription
                } else {
                    errorMessage = "Failed to join circle. Please check the code and try again."
                }
            }
            isJoining = false
        }
    }
}

// MARK: - Member Row

struct MemberRow: View {
    let member: UserProfile
    var onLocate: (() -> Void)?

    var body: some View {
        Button(action: {
            if member.isLocationSharing && member.coordinate != nil {
                onLocate?()
            }
        }) {
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
                        .foregroundColor(.primary)

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
                    HStack(spacing: 12) {
                        VStack(spacing: 4) {
                            Image(systemName: member.batteryIcon)
                                .foregroundColor(member.batteryColor)
                            Text("\(member.batteryLevel)%")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }

                        // Locate button indicator
                        if member.coordinate != nil {
                            Image(systemName: "location.circle.fill")
                                .font(.title2)
                                .foregroundColor(.blue)
                        }
                    }
                }
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Manage Circles Sheet

struct ManageCirclesSheet: View {
    @EnvironmentObject var firestoreService: FirestoreService
    @Environment(\.dismiss) private var dismiss

    @State private var circleToLeave: FamilyCircle?
    @State private var circleToDelete: FamilyCircle?
    @State private var showLeaveAlert = false
    @State private var showDeleteAlert = false
    @State private var isProcessing = false
    @State private var errorMessage: String?

    private var currentUserId: String? {
        FirebaseAuth.Auth.auth().currentUser?.uid
    }

    var body: some View {
        NavigationStack {
            List {
                if firestoreService.circles.isEmpty {
                    Section {
                        Text("You're not a member of any circles.")
                            .foregroundColor(.secondary)
                    }
                } else {
                    Section {
                        ForEach(firestoreService.circles) { circle in
                            CircleManagementRow(
                                circle: circle,
                                isCurrentCircle: circle.id == firestoreService.currentCircleId,
                                isAdmin: currentUserId.map { circle.isAdmin($0) } ?? false,
                                onLeave: {
                                    circleToLeave = circle
                                    showLeaveAlert = true
                                },
                                onDelete: {
                                    circleToDelete = circle
                                    showDeleteAlert = true
                                }
                            )
                        }
                    } header: {
                        Text("Your Circles")
                    } footer: {
                        Text("Swipe left on a circle to leave or delete it.")
                    }
                }

                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("Manage Circles")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .alert("Leave Circle?", isPresented: $showLeaveAlert, presenting: circleToLeave) { circle in
                Button("Cancel", role: .cancel) { }
                Button("Leave", role: .destructive) {
                    leaveCircle(circle)
                }
            } message: { circle in
                Text("Are you sure you want to leave \"\(circle.name)\"? You'll need an invite code to rejoin.")
            }
            .alert("Delete Circle?", isPresented: $showDeleteAlert, presenting: circleToDelete) { circle in
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    deleteCircle(circle)
                }
            } message: { circle in
                Text("Are you sure you want to permanently delete \"\(circle.name)\"? This will remove all members and cannot be undone.")
            }
            .overlay {
                if isProcessing {
                    ProgressView()
                        .scaleEffect(1.5)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color(.systemBackground).opacity(0.5))
                }
            }
        }
    }

    private func leaveCircle(_ circle: FamilyCircle) {
        guard firestoreService.circles.count > 1 else {
            errorMessage = "You cannot leave your only circle. Create or join another circle first."
            return
        }

        isProcessing = true
        errorMessage = nil

        Task {
            do {
                try await firestoreService.leaveCircle(circleId: circle.id)
            } catch {
                errorMessage = error.localizedDescription
            }
            isProcessing = false
        }
    }

    private func deleteCircle(_ circle: FamilyCircle) {
        isProcessing = true
        errorMessage = nil

        Task {
            do {
                try await firestoreService.deleteCircle(circleId: circle.id)
            } catch {
                errorMessage = error.localizedDescription
            }
            isProcessing = false
        }
    }
}

struct CircleManagementRow: View {
    let circle: FamilyCircle
    let isCurrentCircle: Bool
    let isAdmin: Bool
    let onLeave: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(circle.name)
                        .font(.headline)
                    if isCurrentCircle {
                        Text("Current")
                            .font(.caption)
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue)
                            .cornerRadius(4)
                    }
                }

                HStack(spacing: 8) {
                    Label("\(circle.memberIds.count)", systemImage: "person.2")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    if isAdmin {
                        Label("Admin", systemImage: "star.fill")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
            }

            Spacer()
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            if isAdmin {
                Button(role: .destructive, action: onDelete) {
                    Label("Delete", systemImage: "trash")
                }
            }

            Button(action: onLeave) {
                Label("Leave", systemImage: "rectangle.portrait.and.arrow.right")
            }
            .tint(.orange)
        }
    }
}

import FirebaseAuth

#Preview {
    CircleView(memberToLocate: .constant(nil), selectedTab: .constant(3))
        .environmentObject(FirestoreService.shared)
}
