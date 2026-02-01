import SwiftUI
import MapKit
import CoreLocation

/// View showing location history timeline for a member
struct LocationHistoryView: View {
    let memberId: String
    let memberName: String

    @EnvironmentObject var firestoreService: FirestoreService
    @State private var selectedDate = Date()
    @State private var locationHistory: [LocationHistoryEntry] = []
    @State private var isLoading = false
    @State private var selectedEntry: LocationHistoryEntry?
    @State private var cameraPosition = MapCameraPosition.region(MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: -33.8688, longitude: 151.2093),
        span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
    ))

    var body: some View {
        VStack(spacing: 0) {
            // Date selector
            DatePicker(
                "Select Date",
                selection: $selectedDate,
                in: ...Date(),
                displayedComponents: .date
            )
            .datePickerStyle(.compact)
            .padding()
            .background(Color(.systemBackground))

            // Map with route
            Map(position: $cameraPosition) {
                ForEach(locationHistory) { entry in
                    Annotation(entry.placeName ?? "Location", coordinate: entry.coordinate) {
                        LocationHistoryPin(entry: entry, isSelected: selectedEntry?.id == entry.id)
                            .onTapGesture {
                                selectEntry(entry)
                            }
                    }
                }
            }
            .overlay(alignment: .bottom) {
                if let entry = selectedEntry {
                    LocationDetailCard(entry: entry)
                        .padding()
                        .transition(.move(edge: .bottom))
                }
            }
            .frame(height: 300)

            // Timeline list
            if isLoading {
                ProgressView("Loading history...")
                    .padding()
            } else if locationHistory.isEmpty {
                ContentUnavailableView(
                    "No Location History",
                    systemImage: "clock.arrow.circlepath",
                    description: Text("No locations recorded for this date")
                )
            } else {
                List {
                    ForEach(groupedByPlace) { group in
                        Section {
                            ForEach(group.entries) { entry in
                                LocationHistoryRow(entry: entry)
                                    .onTapGesture {
                                        selectEntry(entry)
                                    }
                                    .listRowBackground(
                                        selectedEntry?.id == entry.id ?
                                        Color.blue.opacity(0.1) : Color.clear
                                    )
                            }
                        } header: {
                            HStack {
                                Image(systemName: group.icon)
                                    .foregroundColor(group.color)
                                Text(group.name)
                                Spacer()
                                Text(group.duration)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("\(memberName)'s History")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    loadHistory()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
            }
        }
        .onChange(of: selectedDate) { _, _ in
            loadHistory()
        }
        .onAppear {
            loadHistory()
        }
    }

    private func loadHistory() {
        isLoading = true

        // Simulate loading location history
        // In production, this would fetch from Firestore
        Task {
            try? await Task.sleep(nanoseconds: 500_000_000)

            await MainActor.run {
                locationHistory = generateSampleHistory()
                isLoading = false

                // Center map on first entry
                if let first = locationHistory.first {
                    cameraPosition = .region(MKCoordinateRegion(
                        center: first.coordinate,
                        span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
                    ))
                }
            }
        }
    }

    private func selectEntry(_ entry: LocationHistoryEntry) {
        withAnimation {
            selectedEntry = entry
            cameraPosition = .region(MKCoordinateRegion(
                center: entry.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            ))
        }
    }

    private var groupedByPlace: [PlaceGroup] {
        var groups: [PlaceGroup] = []
        var currentGroup: PlaceGroup?

        for entry in locationHistory.sorted(by: { $0.timestamp < $1.timestamp }) {
            let placeName = entry.placeName ?? "On the move"

            if currentGroup?.name == placeName {
                currentGroup?.entries.append(entry)
            } else {
                if let group = currentGroup {
                    groups.append(group)
                }
                currentGroup = PlaceGroup(
                    name: placeName,
                    icon: entry.placeIcon ?? "location.fill",
                    color: entry.placeName != nil ? .blue : .gray,
                    entries: [entry]
                )
            }
        }

        if let group = currentGroup {
            groups.append(group)
        }

        return groups
    }

    private func generateSampleHistory() -> [LocationHistoryEntry] {
        // Sample data for demonstration
        let baseCoord = CLLocationCoordinate2D(latitude: -33.8688, longitude: 151.2093)
        var entries: [LocationHistoryEntry] = []

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: selectedDate)

        // Home in morning
        for hour in 6..<9 {
            let time = calendar.date(byAdding: .hour, value: hour, to: startOfDay)!
            entries.append(LocationHistoryEntry(
                id: UUID().uuidString,
                latitude: baseCoord.latitude + 0.01,
                longitude: baseCoord.longitude,
                timestamp: time,
                accuracy: 10,
                placeName: "Home",
                placeIcon: "house.fill",
                address: "123 Example Street"
            ))
        }

        // Commute
        for minute in stride(from: 0, to: 30, by: 5) {
            let time = calendar.date(byAdding: .minute, value: 9 * 60 + minute, to: startOfDay)!
            let progress = Double(minute) / 30.0
            entries.append(LocationHistoryEntry(
                id: UUID().uuidString,
                latitude: baseCoord.latitude + 0.01 - (0.02 * progress),
                longitude: baseCoord.longitude + (0.03 * progress),
                timestamp: time,
                accuracy: 15,
                speed: 12.5
            ))
        }

        // Work
        for hour in 9..<17 {
            let time = calendar.date(byAdding: .hour, value: hour, to: startOfDay)!
            entries.append(LocationHistoryEntry(
                id: UUID().uuidString,
                latitude: baseCoord.latitude - 0.01,
                longitude: baseCoord.longitude + 0.03,
                timestamp: time,
                accuracy: 8,
                placeName: "Work",
                placeIcon: "building.2.fill",
                address: "456 Office Building"
            ))
        }

        return entries
    }
}

// MARK: - Models

struct LocationHistoryEntry: Identifiable {
    let id: String
    let latitude: Double
    let longitude: Double
    let timestamp: Date
    let accuracy: Double
    var speed: Double?
    var placeName: String?
    var placeIcon: String?
    var address: String?

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var timeString: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: timestamp)
    }
}

struct PlaceGroup: Identifiable {
    let id = UUID()
    let name: String
    let icon: String
    let color: Color
    var entries: [LocationHistoryEntry]

    var duration: String {
        guard let first = entries.first, let last = entries.last else { return "" }
        let interval = last.timestamp.timeIntervalSince(first.timestamp)
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

// MARK: - Supporting Views

struct LocationHistoryPin: View {
    let entry: LocationHistoryEntry
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Circle()
                    .fill(entry.placeName != nil ? Color.blue : Color.gray)
                    .frame(width: isSelected ? 16 : 12, height: isSelected ? 16 : 12)

                if isSelected {
                    Circle()
                        .stroke(Color.white, lineWidth: 2)
                        .frame(width: 16, height: 16)
                }
            }

            if isSelected {
                Text(entry.timeString)
                    .font(.caption2)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(Color(.systemBackground))
                    .cornerRadius(4)
                    .shadow(radius: 2)
            }
        }
    }
}

struct LocationHistoryRow: View {
    let entry: LocationHistoryEntry

    var body: some View {
        HStack(spacing: 12) {
            // Time
            Text(entry.timeString)
                .font(.system(size: 14, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(width: 60, alignment: .leading)

            // Divider line
            Rectangle()
                .fill(Color.blue.opacity(0.3))
                .frame(width: 2)

            // Details
            VStack(alignment: .leading, spacing: 2) {
                if let place = entry.placeName {
                    HStack {
                        Image(systemName: entry.placeIcon ?? "mappin")
                            .foregroundColor(.blue)
                        Text(place)
                            .font(.subheadline.weight(.medium))
                    }
                }

                if let address = entry.address {
                    Text(address)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                if let speed = entry.speed, speed > 0 {
                    Text("\(Int(speed * 3.6)) km/h")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            // Accuracy indicator
            HStack(spacing: 2) {
                Circle()
                    .fill(entry.accuracy < 15 ? Color.green : entry.accuracy < 50 ? Color.orange : Color.red)
                    .frame(width: 6, height: 6)
                Text("±\(Int(entry.accuracy))m")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

struct LocationDetailCard: View {
    let entry: LocationHistoryEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                if let icon = entry.placeIcon {
                    Image(systemName: icon)
                        .foregroundColor(.blue)
                }
                Text(entry.placeName ?? "Location")
                    .font(.headline)
                Spacer()
                Text(entry.timeString)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            if let address = entry.address {
                Text(address)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            HStack {
                Label("±\(Int(entry.accuracy))m", systemImage: "scope")
                Spacer()
                if let speed = entry.speed, speed > 0 {
                    Label("\(Int(speed * 3.6)) km/h", systemImage: "speedometer")
                }
            }
            .font(.caption)
            .foregroundColor(.secondary)
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(12)
        .shadow(radius: 4)
    }
}

#Preview {
    NavigationStack {
        LocationHistoryView(memberId: "test", memberName: "John")
            .environmentObject(FirestoreService.shared)
    }
}
