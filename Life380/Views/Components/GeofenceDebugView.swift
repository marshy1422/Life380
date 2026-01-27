import SwiftUI
import CoreLocation

/// Debug overlay showing geofence monitoring status
struct GeofenceDebugView: View {
    @ObservedObject var locationManager: PrecisionLocationManager
    @EnvironmentObject var firestoreService: FirestoreService
    @State private var isExpanded = false
    @State private var distances: [String: Double] = [:]
    @State private var updateTimer: Timer?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header - tap to expand
            Button(action: { withAnimation { isExpanded.toggle() } }) {
                HStack {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .foregroundColor(.purple)
                    Text("Geofence Debug")
                        .font(.system(size: 12, weight: .semibold))
                    Spacer()
                    Text("\(locationManager.monitoredRegions.count) active")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            .buttonStyle(.plain)

            if isExpanded {
                Divider()

                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        // Current location
                        if let location = locationManager.currentLocation {
                            LocationStatusRow(location: location)
                        } else {
                            Text("📍 No location")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 12)
                        }

                        Divider()

                        // Places (Firestore)
                        Text("Places (\(firestoreService.places.count))")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 12)

                        if firestoreService.places.isEmpty {
                            Text("No places saved - add a place to test geofencing")
                                .font(.system(size: 10))
                                .foregroundColor(.orange)
                                .padding(.horizontal, 12)
                        } else {
                            ForEach(firestoreService.places) { place in
                                PlaceDebugRow(
                                    place: place,
                                    distance: distances[place.id],
                                    isMonitored: locationManager.monitoredRegions.contains { $0.identifier == place.id }
                                )
                            }
                        }

                        Divider()

                        // Monitored regions
                        Text("Monitored Regions (\(locationManager.monitoredRegions.count))")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 12)

                        if locationManager.monitoredRegions.isEmpty {
                            Text("No geofences active")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 12)
                        } else {
                            ForEach(locationManager.monitoredRegions, id: \.identifier) { region in
                                GeofenceDebugRow(
                                    region: region,
                                    distance: distances[region.identifier],
                                    placeName: firestoreService.places.first { $0.id == region.identifier }?.name
                                )
                            }
                        }

                        // Stats
                        Divider()
                        StatsRow(locationManager: locationManager)

                        // ETA Test
                        Divider()
                        ETATestRow(
                            locationManager: locationManager,
                            firestoreService: firestoreService
                        )

                        // Test Actions
                        Divider()
                        TestActionsRow(
                            locationManager: locationManager,
                            firestoreService: firestoreService
                        )
                    }
                    .padding(.vertical, 8)
                }
                .frame(maxHeight: 350)
            }
        }
        .background(Color(.systemBackground).opacity(0.95))
        .cornerRadius(12)
        .shadow(radius: 4)
        .onAppear {
            startDistanceUpdates()
        }
        .onDisappear {
            updateTimer?.invalidate()
        }
    }

    private func startDistanceUpdates() {
        updateTimer?.invalidate()
        updateTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            updateDistances()
        }
    }

    private func updateDistances() {
        guard let location = locationManager.currentLocation else { return }
        let currentCL = CLLocation(latitude: location.latitude, longitude: location.longitude)

        var newDistances: [String: Double] = [:]

        // Calculate distances to places
        for place in firestoreService.places {
            let placeCL = CLLocation(latitude: place.latitude, longitude: place.longitude)
            newDistances[place.id] = currentCL.distance(from: placeCL)
        }

        // Calculate distances to monitored regions
        for region in locationManager.monitoredRegions {
            let regionCL = CLLocation(latitude: region.center.latitude, longitude: region.center.longitude)
            newDistances[region.identifier] = currentCL.distance(from: regionCL)
        }

        distances = newDistances
    }

}

// MARK: - Sub-views

private struct LocationStatusRow: View {
    let location: PrecisionLocation

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("📍 Current Location")
                    .font(.system(size: 11, weight: .semibold))
                Spacer()
                Text(location.confidence.displayName)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(confidenceColor)
            }

            Text("(\(String(format: "%.6f", location.latitude)), \(String(format: "%.6f", location.longitude)))")
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.secondary)

            HStack(spacing: 12) {
                Label("±\(Int(location.horizontalAccuracy))m", systemImage: "scope")
                if let speed = location.speed, speed > 0 {
                    Label("\(String(format: "%.1f", speed)) m/s", systemImage: "speedometer")
                }
            }
            .font(.system(size: 10))
            .foregroundColor(.secondary)
        }
        .padding(.horizontal, 12)
    }

    var confidenceColor: Color {
        switch location.confidence {
        case .high: return .green
        case .medium: return .blue
        case .low: return .orange
        case .approximate: return .red
        }
    }
}

private struct PlaceDebugRow: View {
    let place: Place
    let distance: Double?
    let isMonitored: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: place.icon)
                .font(.system(size: 12))
                .foregroundColor(place.color)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(place.name)
                    .font(.system(size: 11, weight: .medium))

                if let dist = distance {
                    Text(distanceText(dist))
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(dist <= place.radius ? .green : .secondary)
                }
            }

            Spacer()

            // Status indicator
            VStack(alignment: .trailing, spacing: 2) {
                if isMonitored {
                    Label("Monitored", systemImage: "checkmark.circle.fill")
                        .font(.system(size: 9))
                        .foregroundColor(.green)
                } else {
                    Label("Not monitored", systemImage: "xmark.circle")
                        .font(.system(size: 9))
                        .foregroundColor(.orange)
                }

                Text("r=\(Int(place.radius))m")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .background(isInside ? Color.green.opacity(0.1) : Color.clear)
    }

    var isInside: Bool {
        guard let dist = distance else { return false }
        return dist <= place.radius
    }

    func distanceText(_ meters: Double) -> String {
        if meters < 1000 {
            return "\(Int(meters))m away"
        } else {
            return String(format: "%.1f km away", meters / 1000)
        }
    }
}

private struct GeofenceDebugRow: View {
    let region: CLCircularRegion
    let distance: Double?
    let placeName: String?

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(isInside ? Color.green : Color.gray)
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 2) {
                Text(placeName ?? region.identifier.prefix(8) + "...")
                    .font(.system(size: 11, weight: .medium))

                if let dist = distance {
                    HStack(spacing: 4) {
                        Text(distanceText(dist))
                            .foregroundColor(isInside ? .green : .secondary)
                        Text("•")
                        Text("r=\(Int(region.radius))m")
                    }
                    .font(.system(size: 10, design: .monospaced))
                }
            }

            Spacer()

            Text(isInside ? "INSIDE" : "OUTSIDE")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundColor(isInside ? .green : .gray)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(
                    Capsule()
                        .fill(isInside ? Color.green.opacity(0.2) : Color.gray.opacity(0.2))
                )
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
    }

    var isInside: Bool {
        guard let dist = distance else { return false }
        return dist <= region.radius
    }

    func distanceText(_ meters: Double) -> String {
        if meters < 1000 {
            return "\(Int(meters))m"
        } else {
            return String(format: "%.1f km", meters / 1000)
        }
    }
}

private struct StatsRow: View {
    @ObservedObject var locationManager: PrecisionLocationManager

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Location Stats")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.secondary)

            HStack(spacing: 16) {
                StatItem(label: "Received", value: "\(locationManager.totalLocationsReceived)")
                StatItem(label: "Accepted", value: "\(locationManager.locationsAccepted)")
                StatItem(label: "Rejected", value: "\(locationManager.locationsRejected)")
                StatItem(label: "Rate", value: String(format: "%.0f%%", locationManager.acceptanceRate))
            }
        }
        .padding(.horizontal, 12)
    }
}

private struct ETATestRow: View {
    @ObservedObject var locationManager: PrecisionLocationManager
    @ObservedObject var firestoreService: FirestoreService
    @State private var etas: [ETAResult] = []
    @State private var isCalculating = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("ETA Test")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)

                Spacer()

                Button(action: calculateETAs) {
                    HStack(spacing: 4) {
                        if isCalculating {
                            ProgressView()
                                .scaleEffect(0.6)
                        } else {
                            Image(systemName: "arrow.clockwise")
                        }
                        Text("Calculate")
                            .font(.system(size: 10))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(6)
                }
                .disabled(isCalculating || locationManager.currentLocation == nil || firestoreService.places.isEmpty)
            }

            if firestoreService.places.isEmpty {
                Text("Add a place to test ETAs")
                    .font(.system(size: 10))
                    .foregroundColor(.orange)
            } else if etas.isEmpty {
                Text("Tap Calculate to compute ETAs")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            } else {
                ForEach(etas) { eta in
                    HStack(spacing: 8) {
                        Image(systemName: eta.place.icon)
                            .font(.system(size: 10))
                            .foregroundColor(eta.place.color)

                        Text(eta.place.name)
                            .font(.system(size: 10, weight: .medium))

                        Spacer()

                        // Distance
                        Text(eta.distanceText)
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)

                        // ETA
                        Text(eta.etaText)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(eta.isAlmostThere ? .blue : .primary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(eta.isAlmostThere ? Color.blue.opacity(0.2) : Color.gray.opacity(0.15))
                            )

                        // Method indicator
                        Text(eta.calculationMethod == .mapKit ? "MK" : "S")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding(.horizontal, 12)
        .onAppear {
            // Auto-calculate ETAs after a short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                if !firestoreService.places.isEmpty && locationManager.currentLocation != nil && etas.isEmpty {
                    calculateETAs()
                }
            }
        }
    }

    private func calculateETAs() {
        guard let location = locationManager.currentLocation else { return }

        isCalculating = true

        Task {
            let results = await ETAService.shared.calculateETAsToAllPlaces(
                from: location,
                places: firestoreService.places
            )

            await MainActor.run {
                etas = results
                isCalculating = false
            }

            #if DEBUG
            print("📊 [ETA TEST] Calculated \(results.count) ETAs")
            for eta in results {
                print("   → \(eta.place.name): \(eta.etaText) (\(eta.distanceText), \(eta.calculationMethod.rawValue))")
            }
            #endif
        }
    }
}

// MARK: - ETA Test Row Extension (Auto-calculate)
extension ETATestRow {
    func autoCalculateOnAppear() -> some View {
        self.onAppear {
            // Auto-calculate ETAs after a short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                if !firestoreService.places.isEmpty && locationManager.currentLocation != nil {
                    calculateETAs()
                }
            }
        }
    }
}

private struct TestActionsRow: View {
    @ObservedObject var locationManager: PrecisionLocationManager
    @ObservedObject var firestoreService: FirestoreService
    @State private var isAddingPlace = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Test Actions")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.secondary)

            HStack(spacing: 8) {
                // Add test place at current location
                Button(action: addTestPlace) {
                    HStack(spacing: 4) {
                        if isAddingPlace {
                            ProgressView()
                                .scaleEffect(0.7)
                        } else {
                            Image(systemName: "plus.circle.fill")
                        }
                        Text("Add Test Place Here")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .disabled(isAddingPlace || locationManager.currentLocation == nil || firestoreService.currentCircleId == nil)

                // Clear all test places
                if !firestoreService.places.isEmpty {
                    Button(action: clearTestPlaces) {
                        HStack(spacing: 4) {
                            Image(systemName: "trash")
                            Text("Clear")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.red.opacity(0.8))
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                }
            }

            // Status message and create circle button
            if firestoreService.currentCircleId == nil {
                HStack {
                    Text("⚠️ No circle")
                        .font(.system(size: 10))
                        .foregroundColor(.orange)

                    Button(action: createTestCircle) {
                        Text("Create Test Circle")
                            .font(.system(size: 10, weight: .medium))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.orange)
                            .foregroundColor(.white)
                            .cornerRadius(4)
                    }
                }
            } else if locationManager.currentLocation == nil {
                Text("⚠️ Waiting for location...")
                    .font(.system(size: 10))
                    .foregroundColor(.orange)
            } else {
                Text("✅ Ready - Circle: \(firestoreService.currentCircleId?.prefix(8) ?? "")...")
                    .font(.system(size: 10))
                    .foregroundColor(.green)
            }
        }
        .padding(.horizontal, 12)
    }

    private func createTestCircle() {
        Task {
            do {
                let circleId = try await firestoreService.createCircle(name: "Test Circle")
                print("✅ [TEST] Created test circle: \(circleId)")
            } catch {
                print("❌ [TEST] Failed to create circle: \(error)")
            }
        }
    }

    private func addTestPlace() {
        guard let location = locationManager.currentLocation,
              let circleId = firestoreService.currentCircleId else { return }

        isAddingPlace = true

        let testPlace = Place(
            name: "Test Place \(Int.random(in: 100...999))",
            address: "Test location at (\(String(format: "%.4f", location.latitude)), \(String(format: "%.4f", location.longitude)))",
            icon: "mappin.circle.fill",
            color: .purple,
            notificationsEnabled: true,
            latitude: location.latitude,
            longitude: location.longitude,
            radius: 100  // 100 meter radius
        )

        Task {
            do {
                try await firestoreService.addPlace(testPlace, circleId: circleId)
                print("✅ [TEST] Added test place: \(testPlace.name) at (\(location.latitude), \(location.longitude))")
            } catch {
                print("❌ [TEST] Failed to add place: \(error)")
            }
            await MainActor.run {
                isAddingPlace = false
            }
        }
    }

    private func clearTestPlaces() {
        guard let circleId = firestoreService.currentCircleId else { return }

        Task {
            for place in firestoreService.places {
                try? await firestoreService.deletePlace(placeId: place.id, circleId: circleId)
                print("🗑️ [TEST] Deleted place: \(place.name)")
            }
        }
    }
}

private struct StatItem: View {
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
            Text(label)
                .font(.system(size: 9))
                .foregroundColor(.secondary)
        }
    }
}

#Preview {
    GeofenceDebugView(locationManager: PrecisionLocationManager())
        .environmentObject(FirestoreService.shared)
        .padding()
}
