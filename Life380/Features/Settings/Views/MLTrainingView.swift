import SwiftUI
import CoreLocation

/// UI for ML model training, monitoring, and user corrections
struct MLTrainingView: View {
    @StateObject private var mlService = LocationMLService.shared
    @State private var showingCorrectionSheet = false
    @State private var showingResetAlert = false
    @State private var trainingResult: TrainingResult?
    @State private var showingResultAlert = false

    var body: some View {
        List {
            // Model Status Section
            Section {
                ModelStatusCard(status: mlService.getModelInfo())
            } header: {
                Text("Model Status")
            }

            // Data Collection Section
            Section {
                DataCollectionCard(
                    totalSamples: mlService.totalSamples,
                    groundTruthSamples: mlService.samplesWithGroundTruth,
                    quality: mlService.dataQuality
                )
            } header: {
                Text("Training Data")
            } footer: {
                Text("Ground truth samples come from: high-accuracy GPS, known place arrivals, and manual corrections.")
            }

            // Training Section
            Section {
                if mlService.isTraining {
                    TrainingProgressCard(progress: mlService.trainingProgress)
                } else {
                    TrainModelButton(
                        canTrain: mlService.dataQuality.minimumForTraining,
                        onTrain: startTraining
                    )
                }

                if mlService.isModelTrained {
                    HStack {
                        Label("Model Accuracy", systemImage: "checkmark.seal")
                        Spacer()
                        Text("\(Int(mlService.modelAccuracy * 100))%")
                            .foregroundColor(accuracyColor)
                            .fontWeight(.semibold)
                    }

                    if mlService.averageImprovement > 0 {
                        HStack {
                            Label("Avg Improvement", systemImage: "arrow.up.right")
                            Spacer()
                            Text("\(String(format: "%.1f", mlService.averageImprovement))m better")
                                .foregroundColor(.green)
                        }
                    }

                    if let lastTrain = mlService.lastTrainingDate {
                        HStack {
                            Label("Last Trained", systemImage: "clock")
                            Spacer()
                            Text(lastTrain, style: .relative)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            } header: {
                Text("Training")
            }

            // Manual Correction Section
            Section {
                Button {
                    showingCorrectionSheet = true
                } label: {
                    Label("Correct My Location", systemImage: "location.magnifyingglass")
                }

                Text("If your current location is wrong, tap above to provide the correct location. This helps train a more accurate model.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } header: {
                Text("Improve Accuracy")
            }

            // How It Works
            Section {
                DisclosureGroup {
                    VStack(alignment: .leading, spacing: 12) {
                        MLExplanationRow(
                            icon: "1.circle.fill",
                            title: "Data Collection",
                            description: "The app collects GPS readings along with context (time, motion, battery, etc.)"
                        )

                        MLExplanationRow(
                            icon: "2.circle.fill",
                            title: "Ground Truth",
                            description: "We learn correct locations from: very accurate GPS readings, known place arrivals, and your manual corrections."
                        )

                        MLExplanationRow(
                            icon: "3.circle.fill",
                            title: "Training",
                            description: "A neural network learns patterns in YOUR GPS errors specific to your device and locations."
                        )

                        MLExplanationRow(
                            icon: "4.circle.fill",
                            title: "Prediction",
                            description: "The trained model corrects GPS errors in real-time, improving accuracy by 30-50%."
                        )
                    }
                    .padding(.vertical, 8)
                } label: {
                    Label("How ML Training Works", systemImage: "brain")
                }
            }

            // Reset Section
            Section {
                Button(role: .destructive) {
                    showingResetAlert = true
                } label: {
                    Label("Reset ML Model & Data", systemImage: "trash")
                }
            } footer: {
                Text("This will delete all collected training data and the trained model. The app will start learning from scratch.")
            }
        }
        .navigationTitle("ML Training")
        .sheet(isPresented: $showingCorrectionSheet) {
            LocationCorrectionSheet(onCorrect: { coordinate in
                mlService.userCorrectedLocation(to: coordinate)
            })
        }
        .alert("Reset ML System?", isPresented: $showingResetAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Reset", role: .destructive) {
                mlService.resetAll()
            }
        } message: {
            Text("This will delete all training data and the model. You'll need to collect data again for 1-2 weeks before the model can be retrained.")
        }
        .alert("Training Complete", isPresented: $showingResultAlert) {
            Button("OK") {}
        } message: {
            if let result = trainingResult {
                if result.success {
                    Text("Model trained successfully!\n\nAccuracy: \(Int(result.finalAccuracy * 100))%\nEpochs: \(result.epochsCompleted)")
                } else {
                    Text("Training failed: \(result.error ?? "Unknown error")")
                }
            }
        }
    }

    private var accuracyColor: Color {
        if mlService.modelAccuracy >= 0.8 { return .green }
        if mlService.modelAccuracy >= 0.6 { return .yellow }
        return .orange
    }

    private func startTraining() {
        Task {
            trainingResult = await mlService.trainModel()
            showingResultAlert = true
        }
    }
}

// MARK: - Supporting Views

struct ModelStatusCard: View {
    let status: ModelStatus

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: status.isTrained ? "checkmark.circle.fill" : "circle.dashed")
                    .font(.title)
                    .foregroundColor(status.isTrained ? .green : .gray)

                VStack(alignment: .leading) {
                    Text(status.isTrained ? "Model Trained" : "Not Yet Trained")
                        .font(.headline)
                    Text("Version: \(status.version)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }

            if status.isTrained {
                HStack(spacing: 20) {
                    VStack {
                        Text("\(Int(status.accuracy * 100))%")
                            .font(.title2)
                            .fontWeight(.bold)
                        Text("Accuracy")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    VStack {
                        Text("±\(Int(status.averageError))m")
                            .font(.title2)
                            .fontWeight(.bold)
                        Text("Avg Error")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    VStack {
                        Text("\(status.samplesUsed)")
                            .font(.title2)
                            .fontWeight(.bold)
                        Text("Samples")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, 8)
    }
}

struct DataCollectionCard: View {
    let totalSamples: Int
    let groundTruthSamples: Int
    let quality: DataQuality

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading) {
                    Text("\(totalSamples)")
                        .font(.title)
                        .fontWeight(.bold)
                    Text("Total Samples")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing) {
                    Text("\(groundTruthSamples)")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                    Text("With Ground Truth")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            HStack {
                Text("Data Quality:")
                    .font(.subheadline)
                Spacer()
                QualityBadge(quality: quality)
            }

            ProgressView(value: min(1.0, Double(groundTruthSamples) / 500.0))
                .tint(qualityColor)

            Text(quality.description)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 8)
    }

    private var qualityColor: Color {
        switch quality {
        case .insufficient: return .red
        case .minimal: return .orange
        case .moderate: return .yellow
        case .good: return .green
        case .excellent: return .blue
        }
    }
}

struct QualityBadge: View {
    let quality: DataQuality

    var body: some View {
        Text(quality.rawValue)
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(backgroundColor)
            .foregroundColor(.white)
            .cornerRadius(8)
    }

    private var backgroundColor: Color {
        switch quality {
        case .insufficient: return .red
        case .minimal: return .orange
        case .moderate: return .yellow
        case .good: return .green
        case .excellent: return .blue
        }
    }
}

struct TrainingProgressCard: View {
    let progress: Double

    var body: some View {
        VStack(spacing: 12) {
            ProgressView(value: progress)
                .progressViewStyle(.linear)

            HStack {
                ProgressView()
                    .scaleEffect(0.8)
                Text("Training in progress...")
                    .font(.subheadline)
                Spacer()
                Text("\(Int(progress * 100))%")
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
        }
        .padding(.vertical, 8)
    }
}

struct TrainModelButton: View {
    let canTrain: Bool
    let onTrain: () -> Void

    var body: some View {
        Button(action: onTrain) {
            HStack {
                Image(systemName: "brain")
                Text("Train Model")
            }
        }
        .disabled(!canTrain)

        if !canTrain {
            Text("Need at least 100 ground truth samples to train.")
                .font(.caption)
                .foregroundColor(.orange)
        }
    }
}

struct MLExplanationRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 30)

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

// MARK: - Location Correction Sheet

struct LocationCorrectionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var locationManager = CorrectionLocationManager()
    @State private var manualLatitude: String = ""
    @State private var manualLongitude: String = ""

    let onCorrect: (CLLocationCoordinate2D) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    if let location = locationManager.currentLocation {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Current GPS Reading:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("\(location.coordinate.latitude), \(location.coordinate.longitude)")
                                .font(.system(.body, design: .monospaced))
                            Text("Accuracy: ±\(Int(location.horizontalAccuracy))m")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    } else {
                        HStack {
                            ProgressView()
                            Text("Getting current location...")
                        }
                    }
                } header: {
                    Text("Current Location")
                }

                Section {
                    TextField("Latitude", text: $manualLatitude)
                        .keyboardType(.decimalPad)
                    TextField("Longitude", text: $manualLongitude)
                        .keyboardType(.decimalPad)

                    Button("Use Current GPS as Correct") {
                        if let loc = locationManager.currentLocation {
                            manualLatitude = String(loc.coordinate.latitude)
                            manualLongitude = String(loc.coordinate.longitude)
                        }
                    }
                    .disabled(locationManager.currentLocation == nil)
                } header: {
                    Text("Correct Location")
                } footer: {
                    Text("Enter the coordinates where you actually are. You can get these from Apple Maps by long-pressing on your actual location.")
                }

                Section {
                    Button("Submit Correction") {
                        if let lat = Double(manualLatitude),
                           let lon = Double(manualLongitude) {
                            let coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
                            onCorrect(coordinate)
                            dismiss()
                        }
                    }
                    .disabled(manualLatitude.isEmpty || manualLongitude.isEmpty)
                }
            }
            .navigationTitle("Correct Location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                locationManager.requestLocation()
            }
        }
    }
}

// MARK: - Correction Location Manager

private class CorrectionLocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var currentLocation: CLLocation?

    private let manager = CLLocationManager()

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
    }

    func requestLocation() {
        manager.requestLocation()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        currentLocation = locations.last
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location error: \(error)")
    }
}

#Preview {
    NavigationStack {
        MLTrainingView()
    }
}
