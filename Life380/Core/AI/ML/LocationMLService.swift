import Foundation
import CoreLocation
import Combine
import UIKit

/// Main service for ML-powered location intelligence
/// Orchestrates data collection, training, and prediction
@MainActor
class LocationMLService: ObservableObject {

    static let shared = LocationMLService()

    // MARK: - Published State

    @Published private(set) var isModelTrained: Bool = false
    @Published private(set) var modelAccuracy: Double = 0
    @Published private(set) var isTraining: Bool = false
    @Published private(set) var trainingProgress: Double = 0
    @Published private(set) var dataQuality: DataQuality = .insufficient
    @Published private(set) var totalSamples: Int = 0
    @Published private(set) var samplesWithGroundTruth: Int = 0
    @Published private(set) var lastTrainingDate: Date?
    @Published private(set) var averageImprovement: Double = 0  // meters improved

    // MARK: - Components

    let dataCollector: LocationDataCollector
    let correctionModel: LocationCorrectionModel

    // MARK: - Configuration

    private let minSamplesForTraining = 100
    private let retrainThreshold = 500  // Retrain after this many new samples

    // MARK: - State

    private var samplesSinceLastTrain = 0
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    private init() {
        self.dataCollector = LocationDataCollector.shared
        self.correctionModel = LocationCorrectionModel()

        setupBindings()
        updateState()

        // Start collecting data automatically
        dataCollector.startCollecting()
    }

    // MARK: - Public API

    /// Process a location through the ML pipeline
    func processLocation(_ location: CLLocation, motionState: MotionState = .unknown) -> MLCorrectedLocation {
        // Record sample for training
        dataCollector.recordSample(location: location, motionState: motionState)
        samplesSinceLastTrain += 1

        // Check if we should auto-retrain
        if samplesSinceLastTrain >= retrainThreshold && dataQuality.minimumForTraining && !isTraining {
            Task {
                await trainModelInBackground()
            }
        }

        // Get prediction if model is trained
        if isModelTrained {
            let sample = createSampleForPrediction(location: location, motionState: motionState)
            let features = sample.toFeatureVector()
            let prediction = correctionModel.predict(rawLocation: location, features: features)

            return MLCorrectedLocation(
                rawLocation: location,
                correctedCoordinate: prediction.correctedCoordinate,
                confidence: prediction.confidence,
                wasMLCorrected: prediction.confidence > 0.5,
                predictedError: prediction.predictedError,
                modelVersion: correctionModel.modelInfo.version
            )
        } else {
            // Return raw location if model not trained
            return MLCorrectedLocation(
                rawLocation: location,
                correctedCoordinate: location.coordinate,
                confidence: 0.3,
                wasMLCorrected: false,
                predictedError: location.horizontalAccuracy,
                modelVersion: "untrained"
            )
        }
    }

    /// Manually trigger model training
    func trainModel() async -> TrainingResult {
        guard !isTraining else {
            return TrainingResult(
                success: false,
                finalLoss: 0,
                finalAccuracy: 0,
                epochsCompleted: 0,
                error: "Training already in progress"
            )
        }

        guard dataQuality.minimumForTraining else {
            return TrainingResult(
                success: false,
                finalLoss: 0,
                finalAccuracy: 0,
                epochsCompleted: 0,
                error: "Insufficient training data"
            )
        }

        isTraining = true
        trainingProgress = 0

        let samples = dataCollector.getTrainingData()

        // Train on background thread
        let result = await Task.detached { [correctionModel] in
            return correctionModel.train(
                samples: samples,
                epochs: 100,
                learningRate: 0.001
            ) { progress, accuracy in
                Task { @MainActor in
                    self.trainingProgress = progress
                    self.modelAccuracy = accuracy
                }
            }
        }.value

        isTraining = false
        samplesSinceLastTrain = 0

        if result.success {
            isModelTrained = true
            modelAccuracy = result.finalAccuracy
            lastTrainingDate = Date()
            averageImprovement = calculateAverageImprovement()
        }

        updateState()
        return result
    }

    /// User corrects their location (provides ground truth)
    func userCorrectedLocation(to coordinate: CLLocationCoordinate2D) {
        dataCollector.recordUserCorrection(
            actualLatitude: coordinate.latitude,
            actualLongitude: coordinate.longitude
        )
        updateState()
    }

    /// User arrived at a known place
    func userArrivedAtPlace(_ place: LearnedPlace) {
        dataCollector.recordPlaceArrival(place: place)
        updateState()
    }

    /// Reset the ML system (delete model and data)
    func resetAll() {
        dataCollector.clearAllData()
        correctionModel.resetModel()
        isModelTrained = false
        modelAccuracy = 0
        samplesSinceLastTrain = 0
        lastTrainingDate = nil
        averageImprovement = 0
        updateState()
    }

    /// Get current model info
    func getModelInfo() -> ModelStatus {
        return ModelStatus(
            isTrained: isModelTrained,
            version: correctionModel.modelInfo.version,
            trainedDate: correctionModel.modelInfo.trainedDate,
            accuracy: correctionModel.modelInfo.accuracy,
            averageError: correctionModel.modelInfo.averageError,
            samplesUsed: correctionModel.modelInfo.samplesUsed,
            dataQuality: dataQuality,
            totalSamples: totalSamples,
            groundTruthSamples: samplesWithGroundTruth
        )
    }

    // MARK: - Private Methods

    private func setupBindings() {
        // Observe data collector changes
        dataCollector.$totalSamplesCollected
            .assign(to: &$totalSamples)

        dataCollector.$samplesWithGroundTruth
            .assign(to: &$samplesWithGroundTruth)

        dataCollector.$collectionQuality
            .assign(to: &$dataQuality)
    }

    private func updateState() {
        isModelTrained = correctionModel.modelInfo.trainedDate != nil
        modelAccuracy = correctionModel.modelInfo.accuracy
        lastTrainingDate = correctionModel.modelInfo.trainedDate
    }

    private func trainModelInBackground() async {
        _ = await trainModel()
    }

    private func createSampleForPrediction(location: CLLocation, motionState: MotionState) -> LocationTrainingSample {
        // Create a minimal sample for prediction (no ground truth needed)
        let context = SampleContext.empty  // Use empty context for quick prediction
        return LocationTrainingSample(
            rawLocation: location,
            motionState: motionState,
            context: context,
            groundTruth: nil
        )
    }

    private func calculateAverageImprovement() -> Double {
        let samples = dataCollector.getTrainingData()
        guard !samples.isEmpty else { return 0 }

        var totalRawError: Double = 0
        var totalMLError: Double = 0
        var count = 0

        for sample in samples.prefix(100) {  // Use last 100 for speed
            guard let gtLat = sample.groundTruthLatitude,
                  let gtLon = sample.groundTruthLongitude else { continue }

            let gtLoc = CLLocation(latitude: gtLat, longitude: gtLon)
            let rawLoc = CLLocation(latitude: sample.rawLatitude, longitude: sample.rawLongitude)

            let features = sample.toFeatureVector()
            let prediction = correctionModel.predict(rawLocation: rawLoc, features: features)
            let mlLoc = CLLocation(latitude: prediction.correctedLatitude, longitude: prediction.correctedLongitude)

            totalRawError += rawLoc.distance(from: gtLoc)
            totalMLError += mlLoc.distance(from: gtLoc)
            count += 1
        }

        guard count > 0 else { return 0 }

        let avgRaw = totalRawError / Double(count)
        let avgML = totalMLError / Double(count)

        return max(0, avgRaw - avgML)  // Improvement in meters
    }
}

// MARK: - Supporting Types

struct MLCorrectedLocation {
    let rawLocation: CLLocation
    let correctedCoordinate: CLLocationCoordinate2D
    let confidence: Double
    let wasMLCorrected: Bool
    let predictedError: Double
    let modelVersion: String

    var correctedLocation: CLLocation {
        CLLocation(
            latitude: correctedCoordinate.latitude,
            longitude: correctedCoordinate.longitude
        )
    }

    var improvementMeters: Double {
        let rawCoord = rawLocation.coordinate
        let raw = CLLocation(latitude: rawCoord.latitude, longitude: rawCoord.longitude)
        return raw.distance(from: correctedLocation)
    }
}

struct ModelStatus {
    let isTrained: Bool
    let version: String
    let trainedDate: Date?
    let accuracy: Double
    let averageError: Double
    let samplesUsed: Int
    let dataQuality: DataQuality
    let totalSamples: Int
    let groundTruthSamples: Int

    var readyForTraining: Bool {
        groundTruthSamples >= 100
    }

    var needsRetraining: Bool {
        guard let trained = trainedDate else { return true }
        let daysSinceTrained = Date().timeIntervalSince(trained) / 86400
        return daysSinceTrained > 7 || (totalSamples - samplesUsed) > 500
    }
}
