import SwiftUI
import MapKit
import CoreLocation
import UIKit
import FirebaseAuth

struct MapView: View {
    @EnvironmentObject var firestoreService: FirestoreService
    @EnvironmentObject var locationManager: PrecisionLocationManager  // Use shared instance
    @StateObject private var sosService = SOSService.shared
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    )
    @State private var selectedMember: UserProfile?
    @State private var showPrecisionInfo: Bool = false
    @State private var showSOSSheet: Bool = false
    @State private var hasInitiallyLocated: Bool = false
    @State private var isRefreshing: Bool = false

    // Task management to prevent memory leaks
    @State private var locationUpdateTask: Task<Void, Never>?

    // Throttling to prevent excessive Firestore writes and battery drain
    @State private var lastUploadedLocation: CLLocationCoordinate2D?
    @State private var lastUploadTime: Date?
    private let minimumUploadInterval: TimeInterval = 30 // seconds
    private let minimumDistanceChange: Double = 20 // meters (tighter with precision filtering)

    var body: some View {
        NavigationStack {
            mainContent
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
            locationManager.handleAppResignedActive()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            locationManager.handleAppBecameActive()
        }
    }

    @ViewBuilder
    private var mainContent: some View {
        ZStack {
            mapView
            MapOverlayView(
                locationManager: locationManager,
                showPrecisionInfo: $showPrecisionInfo,
                selectedMember: $selectedMember,
                isRefreshing: $isRefreshing,
                centerOnUser: centerOnUser,
                refreshLocations: refreshLocations,
                onSOSAlertTap: { alert in
                    // Center map on the SOS location
                    withAnimation {
                        region.center = alert.coordinate
                        region.span = MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                    }
                }
            )
        }
        .navigationTitle("Life380")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbarContent }
        .onAppear {
            locationManager.requestPermission()
            // Request "Always" permission for background features (geofencing, SOS)
            locationManager.requestAlwaysPermission()
            startLocationUpdates()
            locationManager.syncGeofencesWithPlaces(firestoreService.places)
            // Start listening for SOS alerts
            if let circleId = firestoreService.currentCircleId {
                sosService.listenToCircleAlerts(circleId: circleId)
            }
            // Auto-center on user's location at launch
            centerOnUserIfNeeded()
        }
        .onChange(of: locationManager.currentLocation) { _, newLocation in
            // Center map on first location received
            if !hasInitiallyLocated, let location = newLocation {
                withAnimation {
                    region.center = location.coordinate
                }
                hasInitiallyLocated = true
            }
        }
        .onDisappear {
            locationUpdateTask?.cancel()
            locationUpdateTask = nil
        }
        .onChange(of: firestoreService.places) { _, newPlaces in
            locationManager.syncGeofencesWithPlaces(newPlaces)
        }
        .onChange(of: firestoreService.currentCircleId) { _, newCircleId in
            // Restart SOS listener when circle changes
            if let circleId = newCircleId {
                sosService.listenToCircleAlerts(circleId: circleId)
            }
        }
        .sheet(isPresented: $showSOSSheet) {
            SOSSheetView(locationManager: locationManager)
        }
    }

    /// Filter members to only show those with valid locations (not nil and not 0,0)
    private var membersWithValidLocation: [UserProfile] {
        firestoreService.circleMembers.filter { $0.hasValidLocation }
    }

    private var mapView: some View {
        Map(coordinateRegion: $region, showsUserLocation: true, annotationItems: membersWithValidLocation) { member in
            // Safe to force-unwrap since we filtered for hasValidLocation
            MapAnnotation(coordinate: member.coordinate!) {
                MemberAnnotation(member: member, isSelected: selectedMember?.id == member.id)
                    .onTapGesture {
                        withAnimation {
                            selectedMember = member
                            if let coordinate = member.coordinate {
                                region.center = coordinate
                            }
                        }
                    }
            }
        }
        .ignoresSafeArea(edges: .top)
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            Button(action: { showSOSSheet = true }) {
                Image(systemName: "sos")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 28, height: 28)
                    .background(sosService.isSOSActive ? Color.red.opacity(0.8) : Color.red)
                    .clipShape(Circle())
            }
        }

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
            } label: {
                Image(systemName: "person.3.fill")
            }
        }
    }

    private func centerOnUser() {
        if let location = locationManager.currentLocation {
            withAnimation {
                region.center = location.coordinate
            }
        }
    }

    private func centerOnUserIfNeeded() {
        if !hasInitiallyLocated, let location = locationManager.currentLocation {
            withAnimation {
                region.center = location.coordinate
            }
            hasInitiallyLocated = true
        }
    }

    private func refreshLocations() {
        guard !isRefreshing else { return }
        isRefreshing = true

        // Re-switch to the current circle to trigger fresh data fetch
        if let circleId = firestoreService.currentCircleId {
            firestoreService.switchCircle(to: circleId)
        }

        // Show refreshing state briefly
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            isRefreshing = false
        }
    }

    private func startLocationUpdates() {
        // Cancel any existing task to prevent duplicates
        locationUpdateTask?.cancel()

        // Update location to Firebase when it changes (with throttling)
        locationUpdateTask = Task {
            for await _ in locationManager.$currentLocation.values {
                // Check if task was cancelled
                guard !Task.isCancelled else { break }

                if let precisionLocation = locationManager.currentLocation {
                    // Only upload high-confidence locations
                    guard precisionLocation.confidence != .approximate else { continue }

                    let coordinate = precisionLocation.coordinate
                    // Apply throttling to prevent excessive writes
                    guard shouldUploadLocation(coordinate) else { continue }

                    let battery = getBatteryLevel()
                    await firestoreService.updateUserLocation(
                        latitude: coordinate.latitude,
                        longitude: coordinate.longitude,
                        batteryLevel: battery,
                        accuracy: precisionLocation.horizontalAccuracy,
                        floor: precisionLocation.floor
                    )

                    // Mark this location as uploaded
                    lastUploadedLocation = coordinate
                    lastUploadTime = Date()
                }
            }
        }
    }

    private func shouldUploadLocation(_ newLocation: CLLocationCoordinate2D) -> Bool {
        // Always upload if this is the first location
        guard let lastLocation = lastUploadedLocation,
              let lastTime = lastUploadTime else {
            return true
        }

        let timeSinceLastUpload = Date().timeIntervalSince(lastTime)
        let distance = distanceBetween(lastLocation, newLocation)

        // Upload if significant time has passed OR significant distance moved
        return timeSinceLastUpload >= minimumUploadInterval || distance >= minimumDistanceChange
    }

    private func distanceBetween(_ coord1: CLLocationCoordinate2D, _ coord2: CLLocationCoordinate2D) -> Double {
        let location1 = CLLocation(latitude: coord1.latitude, longitude: coord1.longitude)
        let location2 = CLLocation(latitude: coord2.latitude, longitude: coord2.longitude)
        return location1.distance(from: location2)
    }

    private func getBatteryLevel() -> Int {
        UIDevice.current.isBatteryMonitoringEnabled = true
        let level = UIDevice.current.batteryLevel
        return level < 0 ? 100 : Int(level * 100)
    }
}

// MARK: - Map Overlay View

struct MapOverlayView: View {
    @ObservedObject var locationManager: PrecisionLocationManager
    @StateObject private var sosService = SOSService.shared
    @Binding var showPrecisionInfo: Bool
    @Binding var selectedMember: UserProfile?
    @Binding var isRefreshing: Bool
    @State private var showDebugPanel: Bool = false
    @State private var dismissedAlertIds: Set<String> = []
    let centerOnUser: () -> Void
    let refreshLocations: () -> Void
    let onSOSAlertTap: ((SOSAlert) -> Void)?

    init(locationManager: PrecisionLocationManager,
         showPrecisionInfo: Binding<Bool>,
         selectedMember: Binding<UserProfile?>,
         isRefreshing: Binding<Bool>,
         centerOnUser: @escaping () -> Void,
         refreshLocations: @escaping () -> Void,
         onSOSAlertTap: ((SOSAlert) -> Void)? = nil) {
        self._locationManager = ObservedObject(wrappedValue: locationManager)
        self._showPrecisionInfo = showPrecisionInfo
        self._selectedMember = selectedMember
        self._isRefreshing = isRefreshing
        self.centerOnUser = centerOnUser
        self.refreshLocations = refreshLocations
        self.onSOSAlertTap = onSOSAlertTap
    }

    var body: some View {
        VStack {
            // SOS Alert Banners
            sosAlertBanners
            precisionHeader
            Spacer()

            #if DEBUG
            // Debug panel (tap precision badge 3 times to toggle)
            if showDebugPanel {
                GeofenceDebugView(locationManager: locationManager)
                    .padding(.horizontal)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            #endif

            precisionInfoCard
            memberCard
            locationButton
        }
    }

    @ViewBuilder
    private var precisionHeader: some View {
        if let location = locationManager.currentLocation {
            HStack(spacing: 8) {
                PrecisionBadge(
                    confidence: location.confidence,
                    source: location.source,
                    isStale: location.isStale
                )
                .onTapGesture {
                    withAnimation {
                        showPrecisionInfo.toggle()
                    }
                }
                .onLongPressGesture(minimumDuration: 1.0) {
                    #if DEBUG
                    withAnimation {
                        showDebugPanel.toggle()
                    }
                    #endif
                }

                if let floor = location.floor {
                    FloorBadge(floor: floor)
                }

                #if DEBUG
                if showDebugPanel {
                    Image(systemName: "ladybug.fill")
                        .foregroundColor(.purple)
                        .font(.system(size: 12))
                }
                #endif

                Spacer()
            }
            .padding(.horizontal)
            .padding(.top, 8)
        }
    }

    @ViewBuilder
    private var precisionInfoCard: some View {
        if showPrecisionInfo, let location = locationManager.currentLocation {
            PrecisionInfoCard(location: location)
                .padding(.horizontal)
                .transition(.move(edge: .top).combined(with: .opacity))
        }
    }

    @ViewBuilder
    private var memberCard: some View {
        if let member = selectedMember {
            MemberDetailCard(member: member) {
                withAnimation {
                    selectedMember = nil
                }
            }
            .padding()
            .transition(.move(edge: .bottom))
        }
    }

    private var locationButton: some View {
        HStack {
            Spacer()
            VStack(spacing: 12) {
                // Refresh button
                Button(action: refreshLocations) {
                    Group {
                        if isRefreshing {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                        } else {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                    .frame(width: 24, height: 24)
                    .padding(12)
                    .background(Color(.systemBackground))
                    .clipShape(Circle())
                    .shadow(radius: 4)
                }
                .disabled(isRefreshing)

                // Center on user button
                Button(action: centerOnUser) {
                    Image(systemName: "location.fill")
                        .frame(width: 24, height: 24)
                        .padding(12)
                        .background(Color(.systemBackground))
                        .clipShape(Circle())
                        .shadow(radius: 4)
                }
            }
            .padding()
        }
    }

    @ViewBuilder
    private var sosAlertBanners: some View {
        let activeAlerts = sosService.circleAlerts.filter { alert in
            // Only show alerts from OTHER users that haven't been dismissed
            alert.userId != FirebaseAuth.Auth.auth().currentUser?.uid &&
            !dismissedAlertIds.contains(alert.id)
        }

        if !activeAlerts.isEmpty {
            VStack(spacing: 8) {
                ForEach(activeAlerts) { alert in
                    SOSAlertBanner(
                        alert: alert,
                        onTap: {
                            onSOSAlertTap?(alert)
                        },
                        onDismiss: {
                            withAnimation {
                                _ = dismissedAlertIds.insert(alert.id)
                            }
                        }
                    )
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }
}

// MARK: - Member Annotation

struct MemberAnnotation: View {
    let member: UserProfile
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 4) {
            Text(member.initials)
                .font(.caption.bold())
                .foregroundColor(.white)
                .frame(width: isSelected ? 44 : 36, height: isSelected ? 44 : 36)
                .background(member.color)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(Color.white, lineWidth: isSelected ? 3 : 2)
                )
                .shadow(radius: isSelected ? 4 : 2)

            if isSelected {
                Text(member.displayName)
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color(.systemBackground))
                    .cornerRadius(4)
                    .shadow(radius: 1)
            }
        }
        .animation(.spring(response: 0.3), value: isSelected)
    }
}

struct MemberDetailCard: View {
    let member: UserProfile
    @EnvironmentObject var firestoreService: FirestoreService
    @State private var etas: [ETAResult] = []
    @State private var addressText: String = "Loading address..."
    @State private var isLoadingAddress: Bool = true
    @State private var showAllETAs: Bool = false
    let onDismiss: () -> Void

    private var activityStatus: (icon: String, text: String, color: Color) {
        // Determine activity based on speed/movement
        let timeSinceUpdate = Date().timeIntervalSince(member.lastUpdated)

        if timeSinceUpdate > 600 { // 10+ minutes stale
            return ("moon.zzz.fill", "Inactive", .secondary)
        } else if timeSinceUpdate > 300 { // 5+ minutes
            return ("pause.circle.fill", "Idle", .orange)
        } else {
            // Active - assume stationary unless we have speed data
            return ("checkmark.circle.fill", "Active", .green)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header with dismiss button
            headerSection

            Divider()
                .padding(.vertical, 12)

            // Location & Address section
            if member.isLocationSharing {
                locationSection

                // Quick actions
                quickActionsSection

                // ETA section (if places exist)
                if !etas.isEmpty {
                    Divider()
                        .padding(.vertical, 12)
                    etaSection
                }
            } else {
                locationSharingOffSection
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.15), radius: 12, x: 0, y: 4)
        .task {
            await loadData()
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        HStack(spacing: 14) {
            // Avatar with activity indicator
            ZStack(alignment: .bottomTrailing) {
                Text(member.initials)
                    .font(.title2.bold())
                    .foregroundColor(.white)
                    .frame(width: 56, height: 56)
                    .background(member.color)
                    .clipShape(Circle())

                // Activity status dot
                Circle()
                    .fill(activityStatus.color)
                    .frame(width: 16, height: 16)
                    .overlay(
                        Circle()
                            .stroke(Color(.systemBackground), lineWidth: 2)
                    )
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(member.displayName)
                    .font(.headline)
                    .foregroundColor(.primary)

                HStack(spacing: 6) {
                    Image(systemName: activityStatus.icon)
                        .font(.caption)
                        .foregroundColor(activityStatus.color)
                    Text(activityStatus.text)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("•")
                        .foregroundColor(.secondary)
                    Text(member.lastUpdatedText)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            // Battery indicator
            VStack(spacing: 2) {
                ZStack {
                    Circle()
                        .stroke(Color(.systemGray5), lineWidth: 3)
                        .frame(width: 36, height: 36)
                    Circle()
                        .trim(from: 0, to: CGFloat(member.batteryLevel) / 100)
                        .stroke(member.batteryColor, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .frame(width: 36, height: 36)
                        .rotationEffect(.degrees(-90))
                    Text("\(member.batteryLevel)")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.primary)
                }
                Text("Battery")
                    .font(.system(size: 8))
                    .foregroundColor(.secondary)
            }

            Button(action: onDismiss) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(Color(.systemGray3))
            }
        }
    }

    // MARK: - Location Section

    private var locationSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: "mappin.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.red)

                VStack(alignment: .leading, spacing: 2) {
                    if isLoadingAddress {
                        HStack(spacing: 6) {
                            ProgressView()
                                .scaleEffect(0.7)
                            Text("Finding address...")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    } else {
                        Text(addressText)
                            .font(.subheadline)
                            .foregroundColor(.primary)
                            .lineLimit(2)
                    }

                    // Accuracy indicator
                    if let accuracy = member.horizontalAccuracy {
                        HStack(spacing: 4) {
                            Image(systemName: accuracyIcon(for: accuracy))
                                .font(.caption2)
                            Text(accuracyText(for: accuracy))
                                .font(.caption2)
                        }
                        .foregroundColor(accuracyColor(for: accuracy))
                    }

                    // Floor info
                    if let floorText = member.floorDisplayName {
                        HStack(spacing: 4) {
                            Image(systemName: "building.2")
                                .font(.caption2)
                            Text(floorText)
                                .font(.caption2)
                        }
                        .foregroundColor(.secondary)
                    }
                }

                Spacer()
            }
        }
    }

    // MARK: - Quick Actions

    private var quickActionsSection: some View {
        HStack(spacing: 12) {
            // Directions button
            Button(action: openDirections) {
                VStack(spacing: 4) {
                    Image(systemName: "arrow.triangle.turn.up.right.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(.blue)
                    Text("Directions")
                        .font(.caption2)
                        .foregroundColor(.primary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }

            // Call button
            Button(action: makeCall) {
                VStack(spacing: 4) {
                    Image(systemName: "phone.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(.green)
                    Text("Call")
                        .font(.caption2)
                        .foregroundColor(.primary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }

            // Message button
            Button(action: sendMessage) {
                VStack(spacing: 4) {
                    Image(systemName: "message.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(.orange)
                    Text("Message")
                        .font(.caption2)
                        .foregroundColor(.primary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }

            // History button
            NavigationLink(destination: LocationHistoryView(memberId: member.id, memberName: member.displayName)) {
                VStack(spacing: 4) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 28))
                        .foregroundColor(.purple)
                    Text("History")
                        .font(.caption2)
                        .foregroundColor(.primary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
        }
        .padding(.top, 12)
    }

    // MARK: - ETA Section

    private var etaSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Arrival Times")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.primary)

                Spacer()

                if etas.count > 2 {
                    Button(action: { withAnimation { showAllETAs.toggle() } }) {
                        Text(showAllETAs ? "Show Less" : "Show All")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }
            }

            ForEach(showAllETAs ? etas : Array(etas.prefix(2))) { eta in
                EnhancedETARow(eta: eta)
            }
        }
    }

    // MARK: - Location Sharing Off

    private var locationSharingOffSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "location.slash.fill")
                .font(.system(size: 40))
                .foregroundColor(.orange)

            Text("Location sharing is off")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Text("\(member.displayName) has disabled location sharing")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }

    // MARK: - Actions

    private func openDirections() {
        guard let coordinate = member.coordinate else { return }
        let mapItem = MKMapItem(placemark: MKPlacemark(coordinate: coordinate))
        mapItem.name = member.displayName
        mapItem.openInMaps(launchOptions: [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving
        ])
    }

    private func makeCall() {
        // In a real app, you'd store phone numbers in UserProfile
        // For now, we'll show an alert or use a placeholder
        if let url = URL(string: "tel://"), UIApplication.shared.canOpenURL(url) {
            // Would open phone app - in production, use actual phone number
        }
    }

    private func sendMessage() {
        // In a real app, you'd open Messages with the member's phone number
        if let url = URL(string: "sms://"), UIApplication.shared.canOpenURL(url) {
            // Would open Messages app - in production, use actual phone number
        }
    }

    // MARK: - Data Loading

    private func loadData() async {
        async let addressTask: () = lookupAddress()
        async let etaTask: () = calculateETAs()
        _ = await (addressTask, etaTask)
    }

    private func lookupAddress() async {
        guard let lat = member.latitude, let lon = member.longitude else {
            await MainActor.run {
                addressText = "Location not available"
                isLoadingAddress = false
            }
            return
        }
        let geocoder = CLGeocoder()
        let location = CLLocation(latitude: lat, longitude: lon)

        do {
            let placemarks = try await geocoder.reverseGeocodeLocation(location)
            if let placemark = placemarks.first {
                await MainActor.run {
                    addressText = formatAddress(placemark)
                    isLoadingAddress = false
                }
            }
        } catch {
            await MainActor.run {
                if let lat = member.latitude, let lon = member.longitude {
                    addressText = String(format: "%.4f, %.4f", lat, lon)
                } else {
                    addressText = "Location not available"
                }
                isLoadingAddress = false
            }
        }
    }

    private func formatAddress(_ placemark: CLPlacemark) -> String {
        var components: [String] = []

        if let name = placemark.name, !name.contains(placemark.thoroughfare ?? "") {
            components.append(name)
        }

        if let street = placemark.thoroughfare {
            if let number = placemark.subThoroughfare {
                components.append("\(number) \(street)")
            } else {
                components.append(street)
            }
        }

        if let city = placemark.locality {
            components.append(city)
        }

        return components.prefix(2).joined(separator: ", ")
    }

    private func calculateETAs() async {
        guard member.isLocationSharing,
              let lat = member.latitude,
              let lon = member.longitude,
              let accuracy = member.horizontalAccuracy,
              accuracy < 100 else { return }

        let location = PrecisionLocation(
            latitude: lat,
            longitude: lon,
            horizontalAccuracy: accuracy,
            source: .fused
        )

        let results = await ETAService.shared.calculateETAsToAllPlaces(
            from: location,
            places: firestoreService.places
        )

        await MainActor.run {
            etas = results
        }
    }

    // MARK: - Helpers

    private func accuracyIcon(for accuracy: Double) -> String {
        if accuracy < 10 { return "target" }
        if accuracy < 30 { return "scope" }
        if accuracy < 100 { return "circle.dashed" }
        return "questionmark.circle"
    }

    private func accuracyText(for accuracy: Double) -> String {
        if accuracy < 10 { return "Precise (±\(Int(accuracy))m)" }
        if accuracy < 30 { return "Good (±\(Int(accuracy))m)" }
        if accuracy < 100 { return "Approximate (±\(Int(accuracy))m)" }
        return "Low accuracy (±\(Int(accuracy))m)"
    }

    private func accuracyColor(for accuracy: Double) -> Color {
        if accuracy < 10 { return .green }
        if accuracy < 30 { return .blue }
        if accuracy < 100 { return .orange }
        return .red
    }
}

// MARK: - Enhanced ETA Row

struct EnhancedETARow: View {
    let eta: ETAResult

    var body: some View {
        HStack(spacing: 12) {
            // Place icon
            Image(systemName: eta.place.icon)
                .font(.system(size: 14))
                .foregroundColor(eta.place.color)
                .frame(width: 28, height: 28)
                .background(eta.place.color.opacity(0.15))
                .clipShape(Circle())

            // Place name and distance
            VStack(alignment: .leading, spacing: 2) {
                Text(eta.place.name)
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.primary)

                HStack(spacing: 4) {
                    Text(eta.distanceText)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    if let traffic = eta.trafficCondition, traffic != .unknown {
                        Text("•")
                            .foregroundColor(.secondary)
                        HStack(spacing: 2) {
                            Circle()
                                .fill(trafficColor(traffic))
                                .frame(width: 6, height: 6)
                            Text(traffic.rawValue.capitalized)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }

            Spacer()

            // ETA time
            VStack(alignment: .trailing, spacing: 2) {
                Text(eta.etaText)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(eta.isAlmostThere ? .green : .primary)

                if let mode = eta.travelMode {
                    Image(systemName: mode.icon)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 6)
    }

    private func trafficColor(_ condition: TrafficCondition) -> Color {
        switch condition {
        case .light: return .green
        case .moderate: return .yellow
        case .heavy: return .red
        case .unknown: return .gray
        }
    }
}

#Preview {
    MapView()
        .environmentObject(FirestoreService.shared)
        .environmentObject(PrecisionLocationManager())
}
