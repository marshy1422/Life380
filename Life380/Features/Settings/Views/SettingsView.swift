import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var authService: AuthenticationService
    @EnvironmentObject var firestoreService: FirestoreService
    @StateObject private var biometricService = BiometricAuthService.shared

    @AppStorage("locationSharing") private var locationSharing = true
    @AppStorage("ghostMode") private var ghostMode = false
    @AppStorage("notificationsEnabled") private var notificationsEnabled = true
    @AppStorage("batterySharing") private var batterySharing = true

    @State private var showingBiometricAuth = false
    @State private var pendingLocationSharingValue = true
    @AppStorage(Constants.UserDefaultsKey.preferredMapsApp) private var preferredMapsApp = Constants.MapsProvider.apple.rawValue

    private var currentMapsProvider: Constants.MapsProvider {
        Constants.MapsProvider(rawValue: preferredMapsApp) ?? .apple
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    private var batteryModeDescription: String {
        "Balanced"
    }

    var body: some View {
        NavigationStack {
            List {
                // Profile Section
                Section {
                    if let profile = firestoreService.currentUserProfile {
                        HStack(spacing: 16) {
                            Text(profile.initials)
                                .font(.title.bold())
                                .foregroundColor(.white)
                                .frame(width: 60, height: 60)
                                .background(profile.color)
                                .clipShape(Circle())

                            VStack(alignment: .leading, spacing: 4) {
                                Text(profile.displayName)
                                    .font(.headline)
                                Text(profile.email)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 8)
                    } else {
                        HStack(spacing: 16) {
                            Text("?")
                                .font(.title.bold())
                                .foregroundColor(.white)
                                .frame(width: 60, height: 60)
                                .background(Color.gray)
                                .clipShape(Circle())

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Loading...")
                                    .font(.headline)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }

                // Location Settings
                Section("Location") {
                    Toggle("Location Sharing", isOn: Binding(
                        get: { locationSharing },
                        set: { newValue in
                            // Check if biometric auth is required
                            if biometricService.isAuthRequired(for: .toggleLocationSharing) && !biometricService.isAuthenticationValid {
                                pendingLocationSharingValue = newValue
                                showingBiometricAuth = true
                            } else {
                                locationSharing = newValue
                                Task {
                                    try? await firestoreService.updateUserProfile(isLocationSharing: newValue)
                                }
                            }
                        }
                    ))

                    Toggle("Ghost Mode", isOn: $ghostMode)

                    NavigationLink {
                        LocationAccuracyView()
                    } label: {
                        HStack {
                            Text("Location Accuracy")
                            Spacer()
                            Text("High")
                                .foregroundColor(.secondary)
                        }
                    }

                    HStack {
                        Label("Battery Optimization", systemImage: "battery.100")
                        Spacer()
                        Text(batteryModeDescription)
                            .foregroundColor(.secondary)
                    }

                    NavigationLink {
                        MapsPreferenceView()
                    } label: {
                        HStack {
                            Text("Preferred Maps App")
                            Spacer()
                            Text(currentMapsProvider.displayName)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                // Notifications
                Section("Notifications") {
                    Toggle("Push Notifications", isOn: $notificationsEnabled)

                    NavigationLink {
                        NotificationSettingsView()
                    } label: {
                        Text("Notification Preferences")
                    }
                }

                // Privacy
                Section("Privacy & Security") {
                    Toggle("Share Battery Level", isOn: $batterySharing)

                    NavigationLink {
                        PrivacySettingsView()
                    } label: {
                        Text("Privacy Settings")
                    }
                }

                // Security
                BiometricSettingsView()

                // Circles
                Section("My Circles") {
                    ForEach(firestoreService.circles) { circle in
                        HStack {
                            Image(systemName: "person.3.fill")
                                .foregroundColor(.blue)
                            VStack(alignment: .leading) {
                                Text(circle.name)
                                    .font(.headline)
                                Text("Code: \(circle.inviteCode)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            if circle.id == firestoreService.currentCircleId {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            firestoreService.switchCircle(to: circle.id)
                        }
                    }

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
                }

                // Legal (Required by App Store)
                Section("Legal") {
                    NavigationLink {
                        TermsOfServiceView()
                    } label: {
                        Text("Terms of Service")
                    }

                    NavigationLink {
                        PrivacyPolicyView()
                    } label: {
                        Text("Privacy Policy")
                    }
                }

                // Beta Feedback
                Section("Beta Program") {
                    NavigationLink {
                        BetaFeedbackView()
                    } label: {
                        Label("Send Feedback", systemImage: "bubble.left.fill")
                    }

                    if let testFlightURL = URL(string: "https://testflight.apple.com/join/Life380Beta") {
                        Link(destination: testFlightURL) {
                            Label("Invite Friends to Beta", systemImage: "person.badge.plus")
                        }
                    }
                }

                // About
                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("\(appVersion) (\(buildNumber))")
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("Build")
                        Spacer()
                        HStack(spacing: 4) {
                            Text("Beta")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.orange)
                                .cornerRadius(4)
                        }
                    }
                }

                // Account Actions
                Section {
                    Button("Sign Out") {
                        firestoreService.removeAllListeners()
                        authService.signOut()
                    }

                    // Account Deletion (Required by App Store)
                    NavigationLink {
                        DeleteAccountView()
                    } label: {
                        Text("Delete Account")
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("Settings")
            .task(id: showingBiometricAuth) {
                guard showingBiometricAuth else { return }
                let success = await biometricService.authenticate(
                    reason: "Authenticate to change location sharing"
                )
                if success {
                    locationSharing = pendingLocationSharingValue
                    Task {
                        try? await firestoreService.updateUserProfile(isLocationSharing: pendingLocationSharingValue)
                    }
                }
                showingBiometricAuth = false
            }
        }
    }
}

struct LocationAccuracyView: View {
    @State private var selectedAccuracy = "high"

    var body: some View {
        List {
            Section {
                ForEach(["high", "medium", "low"], id: \.self) { accuracy in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(accuracy.capitalized)
                                .font(.headline)
                            Text(accuracyDescription(accuracy))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        if selectedAccuracy == accuracy {
                            Image(systemName: "checkmark")
                                .foregroundColor(.blue)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedAccuracy = accuracy
                    }
                }
            } footer: {
                Text("Higher accuracy uses more battery but provides more precise location updates.")
            }
        }
        .navigationTitle("Location Accuracy")
    }

    private func accuracyDescription(_ accuracy: String) -> String {
        switch accuracy {
        case "high": return "Best precision, higher battery usage"
        case "medium": return "Balanced precision and battery"
        case "low": return "Lower precision, saves battery"
        default: return ""
        }
    }
}

struct MapsPreferenceView: View {
    @AppStorage(Constants.UserDefaultsKey.preferredMapsApp) private var preferredMapsApp = Constants.MapsProvider.apple.rawValue

    var body: some View {
        List {
            Section {
                ForEach(Constants.MapsProvider.allCases, id: \.rawValue) { provider in
                    HStack {
                        Image(systemName: provider.icon)
                            .foregroundColor(provider == .apple ? .blue : .green)
                            .frame(width: 30)

                        Text(provider.displayName)
                            .font(.body)

                        Spacer()

                        if preferredMapsApp == provider.rawValue {
                            Image(systemName: "checkmark")
                                .foregroundColor(.blue)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        preferredMapsApp = provider.rawValue
                    }
                }
            } footer: {
                Text("Choose which maps app opens when you tap 'Directions' to a family member's location.")
            }

            Section {
                if !isGoogleMapsInstalled {
                    HStack {
                        Image(systemName: "info.circle")
                            .foregroundColor(.orange)
                        Text("Google Maps not installed. Will open in browser instead.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .navigationTitle("Preferred Maps App")
    }

    private var isGoogleMapsInstalled: Bool {
        guard let url = URL(string: "comgooglemaps://") else { return false }
        return UIApplication.shared.canOpenURL(url)
    }
}

struct NotificationSettingsView: View {
    @AppStorage("arrivalNotifications") private var arrivalNotifications = true
    @AppStorage("departureNotifications") private var departureNotifications = true
    @AppStorage("lowBatteryAlerts") private var lowBatteryAlerts = true

    var body: some View {
        List {
            Section("Place Notifications") {
                Toggle("Arrival Notifications", isOn: $arrivalNotifications)
                Toggle("Departure Notifications", isOn: $departureNotifications)
            }

            Section("Safety Alerts") {
                Toggle("Low Battery Alerts", isOn: $lowBatteryAlerts)
            }
        }
        .navigationTitle("Notifications")
    }
}

struct PrivacySettingsView: View {
    var body: some View {
        List {
            Section {
                NavigationLink("Blocked Members") {
                    Text("No blocked members")
                }
                NavigationLink("Data & Storage") {
                    Text("Data settings")
                }
            }

            Section {
                NavigationLink("Export My Data") {
                    DataExportView()
                }
            }
        }
        .navigationTitle("Privacy")
    }
}

struct DataExportView: View {
    @State private var isExporting = false
    @State private var exportComplete = false

    var body: some View {
        List {
            Section {
                Text("You can request a copy of all your personal data stored in Life380.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Section {
                Button(action: exportData) {
                    if isExporting {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                    } else {
                        HStack {
                            Spacer()
                            Text("Request Data Export")
                            Spacer()
                        }
                    }
                }
                .disabled(isExporting)
            }

            if exportComplete {
                Section {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Export requested! You'll receive an email with your data.")
                    }
                }
            }
        }
        .navigationTitle("Export Data")
    }

    private func exportData() {
        isExporting = true
        // Simulate export request
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            isExporting = false
            exportComplete = true
        }
    }
}

struct CreateCircleView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var firestoreService: FirestoreService

    @State private var circleName = ""
    @State private var isCreating = false
    @State private var errorMessage: String?

    var body: some View {
        Form {
            Section("Circle Name") {
                TextField("Family, Friends, etc.", text: $circleName)
            }

            if let error = errorMessage {
                Section {
                    Text(error)
                        .foregroundColor(.red)
                }
            }

            Section {
                Button(action: createCircle) {
                    if isCreating {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                    } else {
                        HStack {
                            Spacer()
                            Text("Create Circle")
                            Spacer()
                        }
                    }
                }
                .disabled(circleName.isEmpty || isCreating)
            }
        }
        .navigationTitle("Create Circle")
    }

    private func createCircle() {
        isCreating = true
        errorMessage = nil

        Task {
            do {
                _ = try await firestoreService.createCircle(name: circleName)
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
            isCreating = false
        }
    }
}

struct JoinCircleView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var firestoreService: FirestoreService

    @State private var inviteCode = ""
    @State private var isJoining = false
    @State private var errorMessage: String?
    @State private var showSuccess = false

    var body: some View {
        Form {
            Section {
                TextField("XXXXXX", text: $inviteCode)
                    .textInputAutocapitalization(.characters)
                    .font(.system(.title2, design: .monospaced))
                    .multilineTextAlignment(.center)
                    .onChange(of: inviteCode) { _, newValue in
                        // Limit to 6 characters and uppercase
                        let filtered = newValue.uppercased().filter { $0.isLetter || $0.isNumber }
                        if filtered.count > 6 {
                            inviteCode = String(filtered.prefix(6))
                        } else {
                            inviteCode = filtered
                        }
                    }
            } header: {
                Text("Invite Code")
            } footer: {
                if inviteCode.isEmpty {
                    Text("Enter the 6-character code shared by a circle member")
                } else if inviteCode.count < 6 {
                    Text("\(6 - inviteCode.count) more characters needed")
                }
            }

            if let error = errorMessage {
                Section {
                    HStack {
                        Image(systemName: "exclamationmark.circle.fill")
                            .foregroundColor(.red)
                        Text(error)
                            .foregroundColor(.red)
                    }
                }
            }

            if showSuccess {
                Section {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Successfully joined circle!")
                            .foregroundColor(.green)
                    }
                }
            }

            Section {
                Button(action: joinCircle) {
                    if isJoining {
                        HStack {
                            Spacer()
                            ProgressView()
                            Text("Joining...")
                            Spacer()
                        }
                    } else {
                        HStack {
                            Spacer()
                            Text("Join Circle")
                            Spacer()
                        }
                    }
                }
                .disabled(inviteCode.count < 6 || isJoining || showSuccess)
            }
        }
        .navigationTitle("Join Circle")
    }

    private func joinCircle() {
        isJoining = true
        errorMessage = nil
        showSuccess = false

        Task {
            do {
                _ = try await firestoreService.joinCircle(inviteCode: inviteCode)

                // Show success message
                showSuccess = true

                // Wait briefly so user sees success
                try await Task.sleep(nanoseconds: 1_500_000_000)

                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
            isJoining = false
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(AuthenticationService())
        .environmentObject(FirestoreService.shared)
}
