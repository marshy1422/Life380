import Foundation
import CoreLocation
import CoreMotion
import Combine
import UIKit

/// Collects and manages training data for the location ML model
/// Handles data persistence, quality filtering, and ground truth collection
@MainActor
class LocationDataCollector: ObservableObject {

    static let shared = LocationDataCollector()

    // MARK: - Published State

    @Published private(set) var totalSamplesCollected: Int = 0
    @Published private(set) var samplesWithGroundTruth: Int = 0
    @Published private(set) var isCollecting: Bool = false
    @Published private(set) var collectionQuality: DataQuality = .insufficient

    // MARK: - Data Storage

    private var samples: [LocationTrainingSample] = []
    private var recentSamples: [CLLocation] = []  // Last 10 for context
    private let maxSamples = 50000  // ~2 weeks of data
    private let maxRecentSamples = 10

    // MARK: - Context Tracking

    private var lastSampleTime: Date?
    private var lastLocation: CLLocation?
    private let motionManager = CMMotionActivityManager()
    private var currentMotionState: MotionState = .unknown
    private var accelerometerMagnitude: Double?

    // MARK: - Persistence

    private let userDefaults = UserDefaults.standard
    private let samplesKey = "ml.trainingSamples"
    private let statsKey = "ml.collectionStats"

    // MARK: - Dependencies

    private var autoPlaceLearner: AutoPlaceLearner?

    // MARK: - Initialization

    private init() {
        loadSamples()
        startMotionTracking()
        updateStats()
    }

    // MARK: - Public API

    /// Start collecting training data
    func startCollecting() {
        isCollecting = true
        AppLogger.log("Started ML data collection", level: .info)
    }

    /// Stop collecting training data
    func stopCollecting() {
        isCollecting = false
        saveSamples()
        AppLogger.log("Stopped ML data collection", level: .info)
    }

    /// Set the place learner for context
    func setPlaceLearner(_ learner: AutoPlaceLearner) {
        self.autoPlaceLearner = learner
    }

    /// Record a new location sample
    func recordSample(location: CLLocation, motionState: MotionState? = nil) {
        guard isCollecting else { return }

        // Filter out invalid locations
        guard location.horizontalAccuracy >= 0,
              location.horizontalAccuracy < 1000 else {
            return
        }

        // Build context from recent history
        let context = buildContext(for: location)

        // Determine if we have ground truth
        let groundTruth = determineGroundTruth(for: location, context: context)

        // Create sample
        let sample = LocationTrainingSample(
            rawLocation: location,
            motionState: motionState ?? currentMotionState,
            context: context,
            groundTruth: groundTruth
        )

        // Add to collection
        addSample(sample)

        // Update recent samples for context
        recentSamples.append(location)
        if recentSamples.count > maxRecentSamples {
            recentSamples.removeFirst()
        }

        lastSampleTime = location.timestamp
        lastLocation = location
    }

    /// User manually corrects their location (high-value ground truth)
    func recordUserCorrection(actualLatitude: Double, actualLongitude: Double) {
        guard let lastLoc = lastLocation else { return }

        let groundTruth = GroundTruth(
            latitude: actualLatitude,
            longitude: actualLongitude,
            source: .userCorrection,
            rawLocation: lastLoc
        )

        // Update the most recent sample with ground truth
        if var lastSample = samples.last {
            lastSample.groundTruthLatitude = actualLatitude
            lastSample.groundTruthLongitude = actualLongitude
            lastSample.groundTruthSource = .userCorrection
            lastSample.errorDistance = groundTruth.errorDistance
            lastSample.wasAccurate = groundTruth.errorDistance < 20

            samples[samples.count - 1] = lastSample
            samplesWithGroundTruth += 1
            saveSamples()

            AppLogger.log("Recorded user correction: \(groundTruth.errorDistance)m error", level: .info)
        }
    }

    /// User arrived at a known place (implicit ground truth)
    func recordPlaceArrival(place: LearnedPlace) {
        guard let lastLoc = lastLocation else { return }

        let groundTruth = GroundTruth(
            latitude: place.coordinate.latitude,
            longitude: place.coordinate.longitude,
            source: .knownPlace,
            rawLocation: lastLoc
        )

        // Find recent samples that were near this place and update them
        let threshold: Double = 150  // meters
        var updatedCount = 0

        for i in stride(from: samples.count - 1, through: max(0, samples.count - 20), by: -1) {
            var sample = samples[i]
            let sampleLoc = CLLocation(latitude: sample.rawLatitude, longitude: sample.rawLongitude)
            let placeLoc = CLLocation(latitude: place.coordinate.latitude, longitude: place.coordinate.longitude)

            if sampleLoc.distance(from: placeLoc) < threshold && sample.groundTruthSource == .none {
                sample.groundTruthLatitude = place.coordinate.latitude
                sample.groundTruthLongitude = place.coordinate.longitude
                sample.groundTruthSource = .knownPlace
                sample.errorDistance = sampleLoc.distance(from: placeLoc)
                sample.wasAccurate = sample.errorDistance! < 20

                samples[i] = sample
                updatedCount += 1
            }
        }

        if updatedCount > 0 {
            samplesWithGroundTruth += updatedCount
            saveSamples()
            AppLogger.log("Updated \(updatedCount) samples with place arrival ground truth", level: .debug)
        }
    }

    /// Get training data for model training
    func getTrainingData() -> [LocationTrainingSample] {
        // Return only samples with ground truth for supervised learning
        return samples.filter { $0.groundTruthSource != .none }
    }

    /// Get all samples (for unsupervised analysis)
    func getAllSamples() -> [LocationTrainingSample] {
        return samples
    }

    /// Clear all collected data
    func clearAllData() {
        samples.removeAll()
        recentSamples.removeAll()
        totalSamplesCollected = 0
        samplesWithGroundTruth = 0
        collectionQuality = .insufficient
        saveSamples()
        AppLogger.log("Cleared all ML training data", level: .info)
    }

    /// Export samples for analysis (debug)
    func exportToJSON() -> Data? {
        return try? JSONEncoder().encode(samples)
    }

    // MARK: - Private Methods

    private func addSample(_ sample: LocationTrainingSample) {
        samples.append(sample)
        totalSamplesCollected += 1

        if sample.groundTruthSource != .none {
            samplesWithGroundTruth += 1
        }

        // Enforce max size
        if samples.count > maxSamples {
            // Remove oldest samples without ground truth first
            let samplesToRemove = samples.count - maxSamples
            var removed = 0

            samples = samples.filter { sample in
                if removed < samplesToRemove && sample.groundTruthSource == .none {
                    removed += 1
                    return false
                }
                return true
            }

            // If still over, remove oldest
            if samples.count > maxSamples {
                samples.removeFirst(samples.count - maxSamples)
            }
        }

        // Periodic save
        if totalSamplesCollected % 100 == 0 {
            saveSamples()
            updateStats()
        }
    }

    private func buildContext(for location: CLLocation) -> SampleContext {
        var context = SampleContext.empty

        // Accelerometer
        context.accelerometerMagnitude = accelerometerMagnitude

        // Recent variance calculations
        if recentSamples.count >= 3 {
            let speeds = recentSamples.compactMap { $0.speed >= 0 ? $0.speed : nil }
            if speeds.count >= 2 {
                let mean = speeds.reduce(0, +) / Double(speeds.count)
                context.recentSpeedVariance = speeds.map { pow($0 - mean, 2) }.reduce(0, +) / Double(speeds.count)
            }

            // Location variance (average distance from centroid)
            let lats = recentSamples.map { $0.coordinate.latitude }
            let lons = recentSamples.map { $0.coordinate.longitude }
            let centroidLat = lats.reduce(0, +) / Double(lats.count)
            let centroidLon = lons.reduce(0, +) / Double(lons.count)
            let centroid = CLLocation(latitude: centroidLat, longitude: centroidLon)

            var totalDist = 0.0
            for sample in recentSamples {
                totalDist += sample.distance(from: centroid)
            }
            context.recentLocationVariance = totalDist / Double(recentSamples.count)
        }

        // Time since last sample
        if let lastTime = lastSampleTime {
            context.timeSinceLastSample = location.timestamp.timeIntervalSince(lastTime)
        }

        // Distance from last sample
        if let lastLoc = lastLocation {
            context.distanceFromLastSample = location.distance(from: lastLoc)
        }

        // Samples in last 5 minutes
        let fiveMinutesAgo = location.timestamp.addingTimeInterval(-300)
        context.samplesInLast5Minutes = recentSamples.filter { $0.timestamp > fiveMinutesAgo }.count

        // Battery
        UIDevice.current.isBatteryMonitoringEnabled = true
        context.batteryLevel = Double(UIDevice.current.batteryLevel)
        context.isCharging = UIDevice.current.batteryState == .charging || UIDevice.current.batteryState == .full
        context.isLowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled

        // Place context
        if let placeLearner = autoPlaceLearner {
            if let nearestPlace = placeLearner.findPlace(near: location.coordinate) {
                context.isAtKnownPlace = true
                let placeLoc = CLLocation(latitude: nearestPlace.coordinate.latitude,
                                          longitude: nearestPlace.coordinate.longitude)
                context.distanceToNearestKnownPlace = location.distance(from: placeLoc)
                context.knownPlaceType = nearestPlace.inferredType.rawValue
            }
        }

        return context
    }

    private func determineGroundTruth(for location: CLLocation, context: SampleContext) -> GroundTruth? {
        // High confidence GPS (accuracy < 5m)
        if location.horizontalAccuracy < 5 {
            return GroundTruth(
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude,
                source: .highConfidenceGPS,
                rawLocation: location
            )
        }

        // Stationary with consistent readings
        if currentMotionState == .stationary && recentSamples.count >= 5 {
            let variance = context.recentLocationVariance
            if variance < 10 {  // Very consistent readings
                // Use centroid as ground truth
                let lats = recentSamples.map { $0.coordinate.latitude }
                let lons = recentSamples.map { $0.coordinate.longitude }
                let centroidLat = lats.reduce(0, +) / Double(lats.count)
                let centroidLon = lons.reduce(0, +) / Double(lons.count)

                return GroundTruth(
                    latitude: centroidLat,
                    longitude: centroidLon,
                    source: .stationaryAverage,
                    rawLocation: location
                )
            }
        }

        // At a known place with high confidence
        if context.isAtKnownPlace, let dist = context.distanceToNearestKnownPlace, dist < 30 {
            if let placeLearner = autoPlaceLearner,
               let place = placeLearner.findPlace(near: location.coordinate),
               place.confidence > 0.8 {
                return GroundTruth(
                    latitude: place.coordinate.latitude,
                    longitude: place.coordinate.longitude,
                    source: .knownPlace,
                    rawLocation: location
                )
            }
        }

        return nil
    }

    private func startMotionTracking() {
        guard CMMotionActivityManager.isActivityAvailable() else { return }

        motionManager.startActivityUpdates(to: .main) { [weak self] activity in
            guard let activity = activity else { return }

            if activity.stationary {
                self?.currentMotionState = .stationary
            } else if activity.walking {
                self?.currentMotionState = .walking
            } else if activity.running {
                self?.currentMotionState = .running
            } else if activity.cycling {
                self?.currentMotionState = .cycling
            } else if activity.automotive {
                self?.currentMotionState = .driving
            } else {
                self?.currentMotionState = .unknown
            }
        }
    }

    private func updateStats() {
        // Calculate data quality
        let gtRatio = totalSamplesCollected > 0
            ? Double(samplesWithGroundTruth) / Double(totalSamplesCollected)
            : 0

        if samplesWithGroundTruth < 100 {
            collectionQuality = .insufficient
        } else if samplesWithGroundTruth < 500 || gtRatio < 0.1 {
            collectionQuality = .minimal
        } else if samplesWithGroundTruth < 2000 || gtRatio < 0.2 {
            collectionQuality = .moderate
        } else if samplesWithGroundTruth < 5000 || gtRatio < 0.3 {
            collectionQuality = .good
        } else {
            collectionQuality = .excellent
        }
    }

    // MARK: - Persistence

    private func loadSamples() {
        if let data = userDefaults.data(forKey: samplesKey),
           let loaded = try? JSONDecoder().decode([LocationTrainingSample].self, from: data) {
            samples = loaded
            totalSamplesCollected = samples.count
            samplesWithGroundTruth = samples.filter { $0.groundTruthSource != .none }.count
        }

        // Load stats
        if let statsData = userDefaults.data(forKey: statsKey),
           let stats = try? JSONDecoder().decode(CollectionStats.self, from: statsData) {
            totalSamplesCollected = stats.totalSamples
        }
    }

    private func saveSamples() {
        // Save samples (keep last 10000 for persistence)
        let samplesToSave = Array(samples.suffix(10000))
        if let data = try? JSONEncoder().encode(samplesToSave) {
            userDefaults.set(data, forKey: samplesKey)
        }

        // Save stats
        let stats = CollectionStats(
            totalSamples: totalSamplesCollected,
            samplesWithGroundTruth: samplesWithGroundTruth,
            lastSaveDate: Date()
        )
        if let statsData = try? JSONEncoder().encode(stats) {
            userDefaults.set(statsData, forKey: statsKey)
        }
    }
}

// MARK: - Supporting Types

enum DataQuality: String {
    case insufficient = "Insufficient"
    case minimal = "Minimal"
    case moderate = "Moderate"
    case good = "Good"
    case excellent = "Excellent"

    var description: String {
        switch self {
        case .insufficient: return "Need more data (< 100 samples)"
        case .minimal: return "Basic training possible"
        case .moderate: return "Decent model accuracy"
        case .good: return "Good model accuracy"
        case .excellent: return "Optimal for training"
        }
    }

    var color: String {
        switch self {
        case .insufficient: return "red"
        case .minimal: return "orange"
        case .moderate: return "yellow"
        case .good: return "green"
        case .excellent: return "blue"
        }
    }

    var minimumForTraining: Bool {
        self != .insufficient
    }
}

private struct CollectionStats: Codable {
    let totalSamples: Int
    let samplesWithGroundTruth: Int
    let lastSaveDate: Date
}
