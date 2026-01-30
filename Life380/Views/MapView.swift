import SwiftUI
import MapKit
import CoreLocation
import UIKit
import FirebaseAuth

struct MapView: View {
    @EnvironmentObject var firestoreService: FirestoreService
    @StateObject private var locationManager = PrecisionLocationManager()
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

    private var mapView: some View {
        Map(coordinateRegion: $region, showsUserLocation: true, annotationItems: firestoreService.circleMembers) { member in
            MapAnnotation(coordinate: member.coordinate) {
                MemberAnnotation(member: member, isSelected: selectedMember?.id == member.id)
                    .onTapGesture {
                        withAnimation {
                            selectedMember = member
                            region.center = member.coordinate
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
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header row
            HStack(spacing: 16) {
                Text(member.initials)
                    .font(.title2.bold())
                    .foregroundColor(.white)
                    .frame(width: 56, height: 56)
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
                        Text("Location sharing off")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }

                Spacer()

                VStack(spacing: 4) {
                    Image(systemName: member.batteryIcon)
                        .foregroundColor(member.batteryColor)
                    Text("\(member.batteryLevel)%")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            }

            // ETA section (if places exist)
            if !etas.isEmpty {
                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    Text("Estimated Arrival")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    ForEach(etas.prefix(2)) { eta in
                        ETARow(eta: eta)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(radius: 8)
        .task {
            await calculateETAs()
        }
    }

    private func calculateETAs() async {
        guard member.isLocationSharing,
              let accuracy = member.horizontalAccuracy,
              accuracy < 100 else { return }

        // Create a PrecisionLocation from member data
        let location = PrecisionLocation(
            latitude: member.latitude,
            longitude: member.longitude,
            horizontalAccuracy: accuracy,
            source: .fused
        )

        etas = await ETAService.shared.calculateETAsToAllPlaces(
            from: location,
            places: firestoreService.places
        )
    }
}

#Preview {
    MapView()
        .environmentObject(FirestoreService.shared)
}
