import SwiftUI
import CoreLocation

/// Settings view showing AI learning progress and discovered places
struct AILearningView: View {
    @StateObject private var aiService = LocationIntelligenceService.shared
    @State private var showingPlaceDetail: LearnedPlace?
    @State private var placeToRename: LearnedPlace?
    @State private var newPlaceName = ""

    var body: some View {
        List {
            // Learning Progress Section
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "brain")
                            .font(.title2)
                            .foregroundColor(.purple)

                        VStack(alignment: .leading) {
                            Text("Location Intelligence")
                                .font(.headline)
                            Text(learningStatusText)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        if aiService.isLearning {
                            ProgressView()
                        }
                    }

                    ProgressView(value: aiService.learningProgress)
                        .tint(.purple)

                    Text(learningDescription)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 8)
            } header: {
                Text("Learning Progress")
            }

            // Current Status Section
            Section {
                HStack {
                    Label("Environment", systemImage: "antenna.radiowaves.left.and.right")
                    Spacer()
                    Text(aiService.currentEnvironment.displayName)
                        .foregroundColor(.secondary)
                }

                HStack {
                    Label("GPS Reliability", systemImage: "location.fill")
                    Spacer()
                    GPSReliabilityBadge(reliability: aiService.gpsReliability)
                }

                HStack {
                    Label("AI Confidence", systemImage: "sparkles")
                    Spacer()
                    Text("\(Int(aiService.aiConfidence * 100))%")
                        .foregroundColor(.secondary)
                }
            } header: {
                Text("Current Status")
            }

            // Learned Places Section
            Section {
                if aiService.learnedPlacesCount == 0 {
                    VStack(spacing: 8) {
                        Image(systemName: "mappin.slash")
                            .font(.largeTitle)
                            .foregroundColor(.secondary)
                        Text("No places learned yet")
                            .font(.headline)
                        Text("Life380 will automatically learn your frequently visited places over time.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                } else {
                    ForEach(aiService.getLearnedPlaces()) { place in
                        LearnedPlaceRow(place: place)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                showingPlaceDetail = place
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    aiService.deletePlace(place)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }

                                Button {
                                    placeToRename = place
                                    newPlaceName = place.name ?? ""
                                } label: {
                                    Label("Rename", systemImage: "pencil")
                                }
                                .tint(.blue)
                            }
                    }
                }
            } header: {
                HStack {
                    Text("Learned Places")
                    Spacer()
                    Text("\(aiService.learnedPlacesCount)")
                        .foregroundColor(.secondary)
                }
            } footer: {
                if aiService.learnedPlacesCount > 0 {
                    Text("Swipe left on a place to rename or delete it. Confirmed places improve location accuracy.")
                }
            }

            // How It Works Section
            Section {
                DisclosureGroup {
                    VStack(alignment: .leading, spacing: 12) {
                        FeatureExplanation(
                            icon: "location.fill",
                            title: "Smart Place Detection",
                            description: "Life380 learns places where you spend 15+ minutes regularly, like home, work, and favorite spots."
                        )

                        FeatureExplanation(
                            icon: "battery.100",
                            title: "Battery Optimization",
                            description: "When you're at a known place, Life380 reduces GPS polling to save battery."
                        )

                        FeatureExplanation(
                            icon: "sparkles",
                            title: "Accuracy Improvement",
                            description: "AI filters out GPS noise and improves location precision, especially indoors."
                        )

                        FeatureExplanation(
                            icon: "lock.shield",
                            title: "Privacy First",
                            description: "All learning happens on your device. Your location history is never sent to our servers."
                        )
                    }
                    .padding(.vertical, 8)
                } label: {
                    Label("How AI Learning Works", systemImage: "questionmark.circle")
                }
            }

            // Actions Section
            Section {
                Button {
                    aiService.reanalyzeHistory()
                } label: {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                        Text("Reanalyze Location History")
                    }
                }
                .disabled(aiService.isLearning)
            }
        }
        .navigationTitle("AI Learning")
        .sheet(item: $showingPlaceDetail) { place in
            PlaceDetailSheet(place: place, aiService: aiService)
        }
        .alert("Rename Place", isPresented: .init(
            get: { placeToRename != nil },
            set: { if !$0 { placeToRename = nil } }
        )) {
            TextField("Place name", text: $newPlaceName)
            Button("Cancel", role: .cancel) {
                placeToRename = nil
            }
            Button("Save") {
                if let place = placeToRename {
                    aiService.confirmPlace(place, withName: newPlaceName)
                }
                placeToRename = nil
            }
        } message: {
            Text("Enter a name for this place")
        }
    }

    private var learningStatusText: String {
        if aiService.learningProgress < 0.3 {
            return "Getting started..."
        } else if aiService.learningProgress < 0.6 {
            return "Learning your patterns..."
        } else if aiService.learningProgress < 0.9 {
            return "Almost fully trained"
        } else {
            return "Fully trained"
        }
    }

    private var learningDescription: String {
        let percentage = Int(aiService.learningProgress * 100)
        if percentage < 30 {
            return "Keep using Life380 for better accuracy. \(percentage)% complete."
        } else if percentage < 70 {
            return "Life380 is learning your routine. \(percentage)% complete."
        } else {
            return "Location intelligence is \(percentage)% optimized for your patterns."
        }
    }
}

// MARK: - Supporting Views

struct LearnedPlaceRow: View {
    let place: LearnedPlace

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: place.inferredType.icon)
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 40)

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(place.displayName)
                        .font(.headline)

                    if place.isConfirmed {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }

                Text("\(place.visitCount) visits")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(Int(place.confidence * 100))%")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text("confidence")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

struct GPSReliabilityBadge: View {
    let reliability: GPSReliability

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(reliability.displayName)
                .font(.subheadline)
        }
        .foregroundColor(color)
    }

    private var color: Color {
        switch reliability {
        case .excellent, .good:
            return .green
        case .fair:
            return .yellow
        case .poor:
            return .orange
        case .unavailable:
            return .red
        case .unknown:
            return .gray
        }
    }
}

struct FeatureExplanation: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.blue)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct PlaceDetailSheet: View {
    let place: LearnedPlace
    let aiService: LocationIntelligenceService
    @Environment(\.dismiss) private var dismiss
    @State private var placeName: String = ""

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        Image(systemName: place.inferredType.icon)
                            .font(.largeTitle)
                            .foregroundColor(.blue)

                        VStack(alignment: .leading) {
                            Text(place.displayName)
                                .font(.title2)
                                .fontWeight(.bold)

                            Text(place.inferredType.suggestedName)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 8)
                }

                Section("Statistics") {
                    LabeledContent("Total Visits", value: "\(place.visitCount)")
                    LabeledContent("First Visit", value: place.firstVisit.formatted(date: .abbreviated, time: .omitted))
                    LabeledContent("Last Visit", value: place.lastVisit.formatted(date: .abbreviated, time: .omitted))
                    LabeledContent("Avg Stay", value: formatDuration(place.averageStayDuration))
                    LabeledContent("Confidence", value: "\(Int(place.confidence * 100))%")
                }

                Section("Schedule") {
                    if place.typicalSchedule.isWeekdayPlace {
                        Label("Primarily weekdays", systemImage: "briefcase")
                    }
                    if place.typicalSchedule.isWeekendPlace {
                        Label("Primarily weekends", systemImage: "figure.walk")
                    }
                    if place.typicalSchedule.hasOvernightStays {
                        Label("Overnight stays", systemImage: "moon.stars")
                    }
                    LabeledContent("Typical Arrival", value: "\(place.typicalSchedule.typicalArrivalHour):00")
                }

                Section("Actions") {
                    TextField("Custom name", text: $placeName)

                    Button("Confirm Place") {
                        aiService.confirmPlace(place, withName: placeName.isEmpty ? place.displayName : placeName)
                        dismiss()
                    }
                    .disabled(place.isConfirmed && placeName.isEmpty)

                    Button("Delete Place", role: .destructive) {
                        aiService.deletePlace(place)
                        dismiss()
                    }
                }
            }
            .navigationTitle("Place Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                placeName = place.name ?? ""
            }
        }
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes) min"
        }
    }
}

#Preview {
    NavigationStack {
        AILearningView()
    }
}
