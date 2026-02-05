import SwiftUI
import MapKit

/// Full-featured location history timeline view
struct LocationHistoryMapView: View {
    @StateObject private var historyService = LocationHistoryService.shared
    @State private var selectedDate = Date()
    @State private var selectedPoint: LocationHistoryPoint?
    @State private var showingDatePicker = false
    @State private var mapPosition: MapCameraPosition = .region(MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
        span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
    ))

    var body: some View {
        VStack(spacing: 0) {
            // Map (iOS 17+ API)
            Map(position: $mapPosition) {
                ForEach(historyPoints) { point in
                    Annotation("", coordinate: point.coordinate) {
                        HistoryPointMarker(point: point, isSelected: selectedPoint?.id == point.id)
                            .onTapGesture {
                                selectedPoint = point
                            }
                    }
                }
            }
            .overlay(alignment: .topTrailing) {
                // Map controls
                VStack(spacing: 8) {
                    Button {
                        fitMapToHistory()
                    } label: {
                        Image(systemName: "arrow.up.left.and.down.right.magnifyingglass")
                            .padding(10)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }
                }
                .padding()
            }
            .frame(height: UIScreen.main.bounds.height * 0.45)

            // Timeline
            VStack(spacing: 0) {
                // Date selector
                HStack {
                    Button {
                        changeDate(by: -1)
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.title3)
                    }

                    Spacer()

                    Button {
                        showingDatePicker = true
                    } label: {
                        VStack(spacing: 2) {
                            Text(selectedDate, style: .date)
                                .font(.headline)
                            if let summary = historyService.todaySummary, Calendar.current.isDateInToday(selectedDate) {
                                Text("\(String(format: "%.1f", summary.totalDistanceMiles)) mi • \(summary.placesVisited) places")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .foregroundColor(.primary)

                    Spacer()

                    Button {
                        changeDate(by: 1)
                    } label: {
                        Image(systemName: "chevron.right")
                            .font(.title3)
                    }
                    .disabled(Calendar.current.isDateInToday(selectedDate))
                }
                .padding()

                Divider()

                // Timeline list
                if historyPoints.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "location.slash")
                            .font(.largeTitle)
                            .foregroundColor(.secondary)
                        Text("No location history")
                            .font(.headline)
                        Text("Location history will appear here as you move around.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(timelineItems) { item in
                                TimelineItemRow(item: item, isSelected: selectedPoint?.id == item.point?.id)
                                    .onTapGesture {
                                        if let point = item.point {
                                            selectedPoint = point
                                            centerMap(on: point.coordinate)
                                        }
                                    }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Location History")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingDatePicker) {
            DatePickerSheet(selectedDate: $selectedDate)
        }
        .onChange(of: selectedDate) { _, _ in
            fitMapToHistory()
        }
        .onAppear {
            fitMapToHistory()
        }
    }

    // MARK: - Computed Properties

    private var historyPoints: [LocationHistoryPoint] {
        historyService.getHistory(for: selectedDate)
    }

    private var historyVisits: [LocationVisit] {
        historyService.getVisits(for: selectedDate)
    }

    private var timelineItems: [TimelineItem] {
        var items: [TimelineItem] = []

        // Combine visits and travel into timeline
        let sortedPoints = historyPoints.sorted { $0.timestamp < $1.timestamp }

        var lastVisitEnd: Date?

        for visit in historyVisits.sorted(by: { $0.arrivalTime < $1.arrivalTime }) {
            // Add travel segment before visit
            if let lastEnd = lastVisitEnd {
                let travelPoints = sortedPoints.filter {
                    $0.timestamp > lastEnd && $0.timestamp < visit.arrivalTime
                }
                if !travelPoints.isEmpty {
                    items.append(TimelineItem(
                        type: .travel,
                        startTime: lastEnd,
                        endTime: visit.arrivalTime,
                        point: travelPoints.first
                    ))
                }
            }

            // Add visit
            items.append(TimelineItem(
                type: .visit(visit),
                startTime: visit.arrivalTime,
                endTime: visit.departureTime,
                point: nil
            ))

            lastVisitEnd = visit.departureTime
        }

        // If no visits, show points as travel
        if historyVisits.isEmpty,
           let firstPoint = sortedPoints.first,
           let lastPoint = sortedPoints.last {
            items.append(TimelineItem(
                type: .travel,
                startTime: firstPoint.timestamp,
                endTime: lastPoint.timestamp,
                point: firstPoint
            ))
        }

        return items.sorted { $0.startTime > $1.startTime }  // Most recent first
    }

    // MARK: - Actions

    private func changeDate(by days: Int) {
        if let newDate = Calendar.current.date(byAdding: .day, value: days, to: selectedDate) {
            if newDate <= Date() {
                selectedDate = newDate
            }
        }
    }

    private func fitMapToHistory() {
        let points = historyPoints
        guard !points.isEmpty else { return }

        let lats = points.map { $0.latitude }
        let lons = points.map { $0.longitude }

        let minLat = lats.min() ?? 0
        let maxLat = lats.max() ?? 0
        let minLon = lons.min() ?? 0
        let maxLon = lons.max() ?? 0

        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )

        let span = MKCoordinateSpan(
            latitudeDelta: max(0.01, (maxLat - minLat) * 1.3),
            longitudeDelta: max(0.01, (maxLon - minLon) * 1.3)
        )

        withAnimation {
            mapPosition = .region(MKCoordinateRegion(center: center, span: span))
        }
    }

    private func centerMap(on coordinate: CLLocationCoordinate2D) {
        withAnimation {
            mapPosition = .camera(MapCamera(centerCoordinate: coordinate, distance: 1000))
        }
    }
}

// MARK: - Timeline Item

struct TimelineItem: Identifiable {
    let id = UUID()
    let type: TimelineItemType
    let startTime: Date
    let endTime: Date?
    let point: LocationHistoryPoint?
}

enum TimelineItemType {
    case visit(LocationVisit)
    case travel
}

// MARK: - Supporting Views

struct HistoryPointMarker: View {
    let point: LocationHistoryPoint
    let isSelected: Bool

    var body: some View {
        ZStack {
            Circle()
                .fill(isSelected ? Color.blue : Color.blue.opacity(0.5))
                .frame(width: isSelected ? 16 : 8, height: isSelected ? 16 : 8)

            if isSelected {
                Circle()
                    .stroke(Color.white, lineWidth: 2)
                    .frame(width: 16, height: 16)
            }
        }
    }
}

struct TimelineItemRow: View {
    let item: TimelineItem
    let isSelected: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Time column
            VStack {
                Text(item.startTime, style: .time)
                    .font(.caption)
                    .foregroundColor(.secondary)

                if let end = item.endTime {
                    Text("–")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(end, style: .time)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .frame(width: 50)

            // Timeline line
            VStack(spacing: 0) {
                Circle()
                    .fill(iconColor)
                    .frame(width: 12, height: 12)

                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 2)
            }

            // Content
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: icon)
                        .foregroundColor(iconColor)

                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                }

                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(isSelected ? Color.blue.opacity(0.1) : Color.clear)
    }

    private var icon: String {
        switch item.type {
        case .visit(let visit):
            return visit.placeCategory.icon
        case .travel:
            return "car.fill"
        }
    }

    private var iconColor: Color {
        switch item.type {
        case .visit:
            return .green
        case .travel:
            return .blue
        }
    }

    private var title: String {
        switch item.type {
        case .visit(let visit):
            return visit.placeName ?? visit.placeCategory.rawValue
        case .travel:
            return "Traveling"
        }
    }

    private var subtitle: String {
        switch item.type {
        case .visit(let visit):
            if let duration = visit.durationMinutes {
                return "\(Int(duration)) minutes"
            }
            return "Currently here"
        case .travel:
            if let end = item.endTime {
                let duration = end.timeIntervalSince(item.startTime) / 60
                return "\(Int(duration)) minutes"
            }
            return ""
        }
    }
}

struct DatePickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedDate: Date

    var body: some View {
        NavigationStack {
            DatePicker(
                "Select Date",
                selection: $selectedDate,
                in: ...Date(),
                displayedComponents: .date
            )
            .datePickerStyle(.graphical)
            .padding()
            .navigationTitle("Select Date")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        LocationHistoryMapView()
    }
}
