import SwiftUI
import Charts

struct InsightsView: View {
    @EnvironmentObject var firestoreService: FirestoreService
    @StateObject private var insightsService = InsightsService.shared
    @State private var selectedMember: UserProfile?
    @State private var selectedTimeRange: TimeRange = .week
    @State private var isLoading: Bool = false

    enum TimeRange: String, CaseIterable {
        case today = "Today"
        case week = "This Week"
        case month = "This Month"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Tracking toggle
                    trackingToggle

                    if insightsService.isTrackingEnabled {
                        // Time range picker
                        timeRangePicker

                        // Member selector (if viewing others)
                        memberSelector

                        // Dwell Time Card (Option A)
                        dwellTimeCard

                        // Travel Insights Card (Option B)
                        travelInsightsCard

                        // Weekly Activity Chart (Option C)
                        weeklyActivityCard

                        // Commute Stats (Option B)
                        commuteStatsCard
                    } else {
                        enableTrackingPrompt
                    }
                }
                .padding()
            }
            .overlay {
                if isLoading {
                    ProgressView()
                        .scaleEffect(1.5)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color(.systemBackground).opacity(0.5))
                }
            }
            .navigationTitle("Insights")
            .refreshable {
                await loadInsights()
            }
            .task {
                await loadInsights()
            }
        }
    }

    // MARK: - Tracking Toggle

    private var trackingToggle: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Location Insights")
                    .font(.headline)
                Text("Track time at places & travel patterns")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Toggle("", isOn: Binding(
                get: { insightsService.isTrackingEnabled },
                set: { enabled in
                    if enabled {
                        insightsService.enableTracking()
                    } else {
                        insightsService.disableTracking()
                    }
                }
            ))
            .labelsHidden()
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }

    // MARK: - Enable Tracking Prompt

    private var enableTrackingPrompt: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.pie.fill")
                .font(.system(size: 60))
                .foregroundColor(.blue.opacity(0.5))

            Text("Enable Insights")
                .font(.title2.bold())

            Text("Track how much time you spend at home, work, and other places. See your travel patterns and commute stats.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Button(action: {
                insightsService.enableTracking()
            }) {
                Text("Enable Tracking")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(12)
            }

            Text("Your data stays private and is only shared with your circle.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(32)
    }

    // MARK: - Time Range Picker

    private var timeRangePicker: some View {
        Picker("Time Range", selection: $selectedTimeRange) {
            ForEach(TimeRange.allCases, id: \.self) { range in
                Text(range.rawValue).tag(range)
            }
        }
        .pickerStyle(.segmented)
    }

    // MARK: - Member Selector

    private var memberSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                // Self
                MemberChip(
                    name: "You",
                    initials: firestoreService.currentUserProfile?.initials ?? "?",
                    isSelected: selectedMember == nil,
                    color: .blue
                ) {
                    selectedMember = nil
                    Task { await loadInsights() }
                }

                // Circle members
                ForEach(firestoreService.circleMembers) { member in
                    if member.id != firestoreService.currentUserProfile?.id {
                        MemberChip(
                            name: member.displayName,
                            initials: member.initials,
                            isSelected: selectedMember?.id == member.id,
                            color: member.color
                        ) {
                            selectedMember = member
                            Task { await loadInsights() }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Dwell Time Card (Option A)

    private var dwellTimeCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "clock.fill")
                    .foregroundColor(.blue)
                Text("Time at Places")
                    .font(.headline)
                Spacer()
            }

            let slices = insightsService.getDwellTimeSlices()

            if slices.isEmpty {
                emptyStateView(message: "No location data yet", icon: "mappin.slash")
            } else {
                // Pie chart placeholder (simplified for now)
                HStack(spacing: 16) {
                    // Visual representation
                    ZStack {
                        ForEach(Array(slices.enumerated()), id: \.element.id) { index, slice in
                            Circle()
                                .trim(from: trimStart(for: index, in: slices),
                                      to: trimEnd(for: index, in: slices))
                                .stroke(Color(hex: slice.color) ?? .gray, lineWidth: 20)
                                .frame(width: 100, height: 100)
                        }
                    }
                    .frame(width: 100, height: 100)

                    // Legend
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(slices.prefix(4)) { slice in
                            HStack(spacing: 8) {
                                Image(systemName: slice.icon)
                                    .foregroundColor(Color(hex: slice.color))
                                    .frame(width: 20)

                                VStack(alignment: .leading) {
                                    Text(slice.placeName)
                                        .font(.subheadline)
                                    Text(slice.formattedDuration)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }

    // MARK: - Travel Insights Card (Option B)

    private var travelInsightsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "car.fill")
                    .foregroundColor(.orange)
                Text("Travel Insights")
                    .font(.headline)
                Spacer()
            }

            if insightsService.recentTravelRecords.isEmpty {
                emptyStateView(message: "No trips recorded yet", icon: "car.slash")
            } else {
                let stats = calculateTravelStats()

                HStack(spacing: 20) {
                    TravelStatBox(
                        icon: "clock",
                        value: formatDuration(stats.avgDuration),
                        label: "Avg Trip"
                    )

                    TravelStatBox(
                        icon: "road.lanes",
                        value: String(format: "%.1f km", stats.totalDistance / 1000),
                        label: "Total"
                    )

                    TravelStatBox(
                        icon: "number",
                        value: "\(stats.tripCount)",
                        label: "Trips"
                    )
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }

    // MARK: - Weekly Activity Card (Option C)

    private var weeklyActivityCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "chart.bar.fill")
                    .foregroundColor(.purple)
                Text("Weekly Activity")
                    .font(.headline)
                Spacer()
            }

            if insightsService.weeklyActivities.isEmpty {
                emptyStateView(message: "Not enough data yet", icon: "chart.bar.xaxis")
            } else {
                // Bar chart
                Chart(insightsService.weeklyActivities) { activity in
                    BarMark(
                        x: .value("Day", activity.dayOfWeek),
                        y: .value("Hours", activity.homeHours)
                    )
                    .foregroundStyle(Color.green.opacity(0.7))

                    BarMark(
                        x: .value("Day", activity.dayOfWeek),
                        y: .value("Hours", activity.workHours)
                    )
                    .foregroundStyle(Color.blue.opacity(0.7))

                    BarMark(
                        x: .value("Day", activity.dayOfWeek),
                        y: .value("Hours", activity.otherHours)
                    )
                    .foregroundStyle(Color.gray.opacity(0.5))
                }
                .frame(height: 150)
                .chartYAxis {
                    AxisMarks(position: .leading)
                }

                // Legend
                HStack(spacing: 16) {
                    LegendItem(color: .green, label: "Home")
                    LegendItem(color: .blue, label: "Work")
                    LegendItem(color: .gray, label: "Other")
                }
                .font(.caption)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }

    // MARK: - Commute Stats Card

    private var commuteStatsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "arrow.triangle.swap")
                    .foregroundColor(.teal)
                Text("Common Routes")
                    .font(.headline)
                Spacer()
            }

            if insightsService.commuteStats.isEmpty {
                emptyStateView(message: "No commute data yet", icon: "arrow.triangle.swap")
            } else {
                ForEach(insightsService.commuteStats.prefix(3)) { stats in
                    CommuteRow(stats: stats)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }

    // MARK: - Helpers

    private func emptyStateView(message: String, icon: String) -> some View {
        HStack {
            Spacer()
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title)
                    .foregroundColor(.secondary)
                Text(message)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding()
            Spacer()
        }
    }

    private func loadInsights() async {
        isLoading = true
        let userId = selectedMember?.id ?? Auth.auth().currentUser?.uid ?? ""
        await insightsService.loadInsights(for: userId)
        _ = await insightsService.generateWeeklySummary()
        isLoading = false
    }

    private func trimStart(for index: Int, in slices: [DwellTimeSlice]) -> CGFloat {
        let total = slices.reduce(0) { $0 + $1.duration }
        guard total > 0 else { return 0 }

        var start: CGFloat = 0
        for i in 0..<index {
            start += CGFloat(slices[i].duration / total)
        }
        return start
    }

    private func trimEnd(for index: Int, in slices: [DwellTimeSlice]) -> CGFloat {
        trimStart(for: index, in: slices) + CGFloat(slices[index].percentage / 100)
    }

    private func calculateTravelStats() -> (avgDuration: TimeInterval, totalDistance: Double, tripCount: Int) {
        let records = insightsService.recentTravelRecords
        guard !records.isEmpty else { return (0, 0, 0) }

        let totalDuration = records.reduce(0.0) { $0 + $1.duration }
        let totalDistance = records.reduce(0.0) { $0 + $1.distance }

        return (totalDuration / Double(records.count), totalDistance, records.count)
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration / 60)
        if minutes >= 60 {
            return "\(minutes / 60)h \(minutes % 60)m"
        }
        return "\(minutes) min"
    }
}

// MARK: - Supporting Views

struct MemberChip: View {
    let name: String
    let initials: String
    let isSelected: Bool
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(initials)
                    .font(.caption.bold())
                    .foregroundColor(.white)
                    .frame(width: 24, height: 24)
                    .background(color)
                    .clipShape(Circle())

                Text(name)
                    .font(.subheadline)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? color.opacity(0.2) : Color(.tertiarySystemBackground))
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(isSelected ? color : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

struct TravelStatBox: View {
    let icon: String
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .foregroundColor(.orange)

            Text(value)
                .font(.headline)

            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color(.tertiarySystemBackground))
        .cornerRadius(8)
    }
}

struct LegendItem: View {
    let color: Color
    let label: String

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .foregroundColor(.secondary)
        }
    }
}

struct CommuteRow: View {
    let stats: CommuteStats

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(stats.fromPlaceName)
                        .font(.subheadline)
                    Image(systemName: "arrow.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(stats.toPlaceName)
                        .font(.subheadline)
                }

                Text("\(stats.tripCount) trips")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(stats.averageDurationMinutes) min")
                    .font(.subheadline.bold())

                Text("avg")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

import FirebaseAuth

#Preview {
    InsightsView()
        .environmentObject(FirestoreService.shared)
}
