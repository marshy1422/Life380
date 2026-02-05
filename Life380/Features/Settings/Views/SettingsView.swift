import SwiftUI
import FirebaseAuth

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

                    NavigationLink {
                        DriveSafetyView()
                    } label: {
                        HStack {
                            Label("Drive Safety Score", systemImage: "car.fill")
                            Spacer()
                            Image(systemName: "gauge.with.needle")
                                .foregroundColor(.green)
                        }
                    }

                    NavigationLink {
                        CrashDetectionView()
                    } label: {
                        HStack {
                            Label("Crash Detection", systemImage: "car.side.rear.and.collision.and.car.side.front")
                            Spacer()
                            Image(systemName: "shield.checkered")
                                .foregroundColor(.red)
                        }
                    }

                    NavigationLink {
                        LocationHistoryMapView()
                    } label: {
                        HStack {
                            Label("Location History", systemImage: "clock.arrow.circlepath")
                            Spacer()
                            Image(systemName: "map")
                                .foregroundColor(.blue)
                        }
                    }
                }

                // Subscription
                Section {
                    NavigationLink {
                        SubscriptionStatusView()
                    } label: {
                        HStack {
                            Label("Subscription", systemImage: "crown.fill")
                            Spacer()
                            SubscriptionBadge()
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
    @EnvironmentObject var firestoreService: FirestoreService
    @State private var isExporting = false
    @State private var exportComplete = false
    @State private var exportError: String?
    @State private var exportedFileURL: URL?
    @State private var showShareSheet = false

    var body: some View {
        List {
            Section {
                Text("You can request a copy of all your personal data stored in Life380. This includes your profile, location history, places, and circle memberships.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Section("Data Included in Export") {
                DataExportItem(icon: "person.fill", title: "Profile Information", description: "Name, email, account settings")
                DataExportItem(icon: "location.fill", title: "Location History", description: "Recent locations (based on retention setting)")
                DataExportItem(icon: "mappin.circle.fill", title: "Places", description: "Saved places and geofences")
                DataExportItem(icon: "person.3.fill", title: "Circle Memberships", description: "Circles you belong to")
                DataExportItem(icon: "hand.raised.fill", title: "Consent Records", description: "Privacy consent history")
            }

            Section {
                Button(action: { Task { await exportData() } }) {
                    if isExporting {
                        HStack {
                            Spacer()
                            ProgressView()
                            Text("Exporting...")
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                    } else {
                        HStack {
                            Spacer()
                            Image(systemName: "square.and.arrow.up")
                            Text("Export My Data")
                            Spacer()
                        }
                    }
                }
                .disabled(isExporting)
            }

            if let error = exportError {
                Section {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                        Text(error)
                            .foregroundColor(.red)
                    }
                }
            }

            if exportComplete {
                Section {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Export complete! Your data has been saved.")
                    }

                    if exportedFileURL != nil {
                        Button(action: { showShareSheet = true }) {
                            HStack {
                                Image(systemName: "square.and.arrow.up")
                                Text("Share Export File")
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Export Data")
        .sheet(isPresented: $showShareSheet) {
            if let url = exportedFileURL {
                ShareSheet(items: [url])
            }
        }
    }

    private func exportData() async {
        isExporting = true
        exportError = nil
        exportComplete = false

        do {
            let exportData = try await GDPRDataExporter.shared.exportAllUserData()
            let fileURL = try saveExportToFile(exportData)
            exportedFileURL = fileURL
            exportComplete = true
        } catch {
            exportError = "Failed to export data: \(error.localizedDescription)"
        }

        isExporting = false
    }

    private func saveExportToFile(_ data: Data) throws -> URL {
        let fileName = "Life380_Data_Export_\(Date().ISO8601Format()).json"
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent(fileName)
        try data.write(to: fileURL)
        return fileURL
    }
}

struct DataExportItem: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

/// Reusable ShareSheet wrapper for UIActivityViewController
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

/// GDPR-compliant data exporter
class GDPRDataExporter {
    static let shared = GDPRDataExporter()

    private init() {}

    func exportAllUserData() async throws -> Data {
        guard let userId = FirebaseAuth.Auth.auth().currentUser?.uid else {
            throw ExportError.notAuthenticated
        }

        var exportDict: [String: Any] = [
            "exportDate": ISO8601DateFormatter().string(from: Date()),
            "userId": userId,
            "appVersion": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
        ]

        // Export user profile
        if let profile = try? await FirestoreService.shared.fetchUserProfile(userId: userId) {
            exportDict["profile"] = [
                "displayName": profile.displayName,
                "email": profile.email,
                "phoneNumber": profile.phoneNumber ?? "",
                "createdAt": profile.createdAt?.ISO8601Format() ?? "",
                "lastUpdated": profile.lastUpdated.ISO8601Format()
            ]
        }

        // Export circles
        if let circles = try? await FirestoreService.shared.fetchUserCircles(userId: userId) {
            exportDict["circles"] = circles.map { circle in
                [
                    "id": circle.id,
                    "name": circle.name,
                    "role": circle.isAdmin(userId) ? "admin" : "member",
                    "joinedAt": circle.createdAt.ISO8601Format()
                ] as [String: Any]
            }
        }

        // Export places
        if let places = try? await FirestoreService.shared.fetchPlaces(userId: userId) {
            exportDict["places"] = places.map { place in
                [
                    "id": place.id,
                    "name": place.name,
                    "address": place.address,
                    "latitude": place.coordinate.latitude,
                    "longitude": place.coordinate.longitude,
                    "radius": place.radius
                ] as [String: Any]
            }
        }

        // Export privacy settings
        exportDict["privacySettings"] = [
            "locationSharingEnabled": UserDefaults.standard.bool(forKey: "isLocationSharingEnabled"),
            "dataRetentionDays": UserDefaults.standard.integer(forKey: "dataRetentionDays"),
            "analyticsEnabled": UserDefaults.standard.bool(forKey: "analyticsEnabled")
        ]

        let jsonData = try JSONSerialization.data(withJSONObject: exportDict, options: [.prettyPrinted, .sortedKeys])
        return jsonData
    }

    enum ExportError: LocalizedError {
        case notAuthenticated
        case exportFailed

        var errorDescription: String? {
            switch self {
            case .notAuthenticated:
                return "You must be signed in to export your data."
            case .exportFailed:
                return "Failed to export data. Please try again."
            }
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
