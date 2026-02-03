import Foundation
import CoreLocation
import CoreMotion
import Combine
import UIKit

/// Central AI service that orchestrates all machine learning features for location intelligence
/// This is the main entry point for AI-enhanced location tracking
@MainActor
class LocationIntelligenceService: ObservableObject {

    static let shared = LocationIntelligenceService()

    // MARK: - Published State

    @Published private(set) var isLearning = false
    @Published private(set) var learningProgress: Double = 0.0  // 0-1, full learning after ~14 days
    @Published private(set) var learnedPlacesCount = 0
    @Published private(set) var currentEnvironment: EnvironmentType = .unknown
    @Published private(set) var gpsReliability: GPSReliability = .unknown
    @Published private(set) var aiConfidence: Double = 0.5

    // MARK: - Sub-Systems

    let autoPlaceLearner: AutoPlaceLearner
    let smartScheduler: SmartPollingScheduler
    let gpsClassifier: GPSReliabilityClassifier
    let motionPredictor: MotionPredictor

    // MARK: - Private

    private var locationHistory: [LocationSample] = []
    private var cancellables = Set<AnyCancellable>()
    private let maxHistorySize = 10000  // ~1 week of data at moderate polling
    private let userDefaults = UserDefaults.standard

    // MARK: - Keys

    private enum Keys {
        static let firstLaunchDate = "ai.firstLaunchDate"
        static let totalSamplesCollected = "ai.totalSamplesCollected"
        static let modelVersion = "ai.modelVersion"
    }

    // MARK: - Initialization

    private init() {
        self.autoPlaceLearner = AutoPlaceLearner()
        self.smartScheduler = SmartPollingScheduler()
        self.gpsClassifier = GPSReliabilityClassifier()
        self.motionPredictor = MotionPredictor()

        loadState()
        setupBindings()

        // Record first launch for learning progress
        if userDefaults.object(forKey: Keys.firstLaunchDate) == nil {
            userDefaults.set(Date(), forKey: Keys.firstLaunchDate)
        }

        updateLearningProgress()
    }

    // MARK: - Public API

    /// Process a new location update through the AI pipeline
    func processLocation(_ location: CLLocation, motionState: MotionState = .unknown) {
        let sample = LocationSample(
            coordinate: location.coordinate,
            accuracy: location.horizontalAccuracy,
            altitude: location.altitude,
            speed: location.speed,
            course: location.course,
            timestamp: location.timestamp,
            motionState: motionState
        )

        // Add to history
        locationHistory.append(sample)
        if locationHistory.count > maxHistorySize {
            locationHistory.removeFirst(locationHistory.count - maxHistorySize)
        }

        // Update sample count
        let totalSamples = userDefaults.integer(forKey: Keys.totalSamplesCollected) + 1
        userDefaults.set(totalSamples, forKey: Keys.totalSamplesCollected)

        // Process through AI subsystems
        Task {
            await processWithAI(sample)
        }
    }

    /// Get AI-corrected location (if confidence is high enough)
    func getCorrectedLocation(for rawLocation: CLLocation) -> CorrectedLocation {
        let environment = gpsClassifier.classify(
            accuracy: rawLocation.horizontalAccuracy,
            speed: rawLocation.speed,
            recentVariance: calculateRecentVariance()
        )

        currentEnvironment = environment
        gpsReliability = gpsClassifier.reliability

        // For now, return raw location with metadata
        // Full correction model will be trained over time
        let correction = calculateBasicCorrection(rawLocation)

        return CorrectedLocation(
            coordinate: correction.coordinate,
            originalCoordinate: rawLocation.coordinate,
            confidence: correction.confidence,
            environment: environment,
            gpsReliability: gpsReliability,
            wasAICorrected: correction.wasCorrected
        )
    }

    /// Get optimal polling interval based on current context
    func getOptimalPollingInterval() -> TimeInterval {
        return smartScheduler.calculateOptimalInterval(
            motionState: motionPredictor.currentState,
            environment: currentEnvironment,
            atKnownPlace: autoPlaceLearner.isAtKnownPlace,
            batteryLevel: getBatteryLevel()
        )
    }

    /// Check if user is at a learned place
    func checkKnownPlace(at coordinate: CLLocationCoordinate2D) -> LearnedPlace? {
        return autoPlaceLearner.findPlace(near: coordinate)
    }

    /// Get all learned places
    func getLearnedPlaces() -> [LearnedPlace] {
        return autoPlaceLearner.places
    }

    /// Manually confirm a learned place (improves accuracy)
    func confirmPlace(_ place: LearnedPlace, withName name: String) {
        autoPlaceLearner.confirmPlace(place, name: name)
    }

    /// Delete a learned place
    func deletePlace(_ place: LearnedPlace) {
        autoPlaceLearner.deletePlace(place)
    }

    /// Force re-analysis of location history
    func reanalyzeHistory() {
        Task {
            isLearning = true
            await autoPlaceLearner.analyzeHistory(locationHistory)
            learnedPlacesCount = autoPlaceLearner.places.count
            isLearning = false
        }
    }

    // MARK: - Private Methods

    private func setupBindings() {
        // Update learned places count when it changes
        autoPlaceLearner.$places
            .map { $0.count }
            .assign(to: &$learnedPlacesCount)

        // Update motion predictor from recent history
        Timer.publish(every: 30, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.updateMotionPrediction()
            }
            .store(in: &cancellables)
    }

    private func loadState() {
        // Load location history from persistent storage
        if let data = userDefaults.data(forKey: "ai.locationHistory"),
           let history = try? JSONDecoder().decode([LocationSample].self, from: data) {
            locationHistory = history
        }

        // Load learned places
        autoPlaceLearner.loadPlaces()
    }

    private func saveState() {
        // Save location history (keep last 1000 for persistence)
        let historyToSave = Array(locationHistory.suffix(1000))
        if let data = try? JSONEncoder().encode(historyToSave) {
            userDefaults.set(data, forKey: "ai.locationHistory")
        }

        // Save learned places
        autoPlaceLearner.savePlaces()
    }

    private func processWithAI(_ sample: LocationSample) async {
        // 1. Update motion prediction
        motionPredictor.addSample(sample)

        // 2. Check for stationary periods (place learning)
        await autoPlaceLearner.processSample(sample)

        // 3. Update GPS reliability classification
        gpsClassifier.updateWithSample(sample)

        // 4. Periodically save state
        if locationHistory.count % 100 == 0 {
            saveState()
        }

        // 5. Update learning progress
        updateLearningProgress()
    }

    private func calculateBasicCorrection(_ location: CLLocation) -> (coordinate: CLLocationCoordinate2D, confidence: Double, wasCorrected: Bool) {
        // Basic correction: if stationary and GPS is jumping, use centroid
        guard locationHistory.count >= 5 else {
            return (location.coordinate, 0.5, false)
        }

        let recent = Array(locationHistory.suffix(5))
        let variance = calculateVariance(recent)

        // If variance is high but we think user is stationary, use average
        if variance > 20 && motionPredictor.currentState == .stationary {
            let avgLat = recent.map { $0.coordinate.latitude }.reduce(0, +) / Double(recent.count)
            let avgLon = recent.map { $0.coordinate.longitude }.reduce(0, +) / Double(recent.count)

            let corrected = CLLocationCoordinate2D(latitude: avgLat, longitude: avgLon)
            let confidence = min(0.9, 0.5 + (1.0 / variance) * 10)

            return (corrected, confidence, true)
        }

        // No correction needed
        let confidence = min(0.95, max(0.3, 1.0 - (location.horizontalAccuracy / 100)))
        return (location.coordinate, confidence, false)
    }

    private func calculateRecentVariance() -> Double {
        guard locationHistory.count >= 3 else { return 0 }
        return calculateVariance(Array(locationHistory.suffix(10)))
    }

    private func calculateVariance(_ samples: [LocationSample]) -> Double {
        guard samples.count >= 2 else { return 0 }

        let avgLat = samples.map { $0.coordinate.latitude }.reduce(0, +) / Double(samples.count)
        let avgLon = samples.map { $0.coordinate.longitude }.reduce(0, +) / Double(samples.count)

        var totalDistance = 0.0
        for sample in samples {
            let loc1 = CLLocation(latitude: sample.coordinate.latitude, longitude: sample.coordinate.longitude)
            let loc2 = CLLocation(latitude: avgLat, longitude: avgLon)
            totalDistance += loc1.distance(from: loc2)
        }

        return totalDistance / Double(samples.count)
    }

    private func updateMotionPrediction() {
        guard locationHistory.count >= 3 else { return }
        let recent = Array(locationHistory.suffix(10))
        motionPredictor.analyze(recent)
    }

    private func updateLearningProgress() {
        guard let firstLaunch = userDefaults.object(forKey: Keys.firstLaunchDate) as? Date else {
            learningProgress = 0
            return
        }

        let daysSinceFirstLaunch = Date().timeIntervalSince(firstLaunch) / 86400
        let totalSamples = userDefaults.integer(forKey: Keys.totalSamplesCollected)

        // Progress based on time (14 days for full learning) and data (5000 samples)
        let timeProgress = min(1.0, daysSinceFirstLaunch / 14.0)
        let dataProgress = min(1.0, Double(totalSamples) / 5000.0)

        learningProgress = (timeProgress + dataProgress) / 2.0

        // Update AI confidence based on learning progress
        aiConfidence = 0.3 + (learningProgress * 0.6)  // 0.3 to 0.9
    }

    private func getBatteryLevel() -> Double {
        UIDevice.current.isBatteryMonitoringEnabled = true
        return Double(UIDevice.current.batteryLevel)
    }
}

// MARK: - Supporting Types

struct LocationSample: Codable {
    let coordinate: CLLocationCoordinate2D
    let accuracy: Double
    let altitude: Double
    let speed: Double
    let course: Double
    let timestamp: Date
    let motionState: MotionState

    enum CodingKeys: String, CodingKey {
        case latitude, longitude, accuracy, altitude, speed, course, timestamp, motionState
    }

    init(coordinate: CLLocationCoordinate2D, accuracy: Double, altitude: Double,
         speed: Double, course: Double, timestamp: Date, motionState: MotionState) {
        self.coordinate = coordinate
        self.accuracy = accuracy
        self.altitude = altitude
        self.speed = speed
        self.course = course
        self.timestamp = timestamp
        self.motionState = motionState
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let latitude = try container.decode(Double.self, forKey: .latitude)
        let longitude = try container.decode(Double.self, forKey: .longitude)
        self.coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        self.accuracy = try container.decode(Double.self, forKey: .accuracy)
        self.altitude = try container.decode(Double.self, forKey: .altitude)
        self.speed = try container.decode(Double.self, forKey: .speed)
        self.course = try container.decode(Double.self, forKey: .course)
        self.timestamp = try container.decode(Date.self, forKey: .timestamp)
        self.motionState = try container.decode(MotionState.self, forKey: .motionState)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(coordinate.latitude, forKey: .latitude)
        try container.encode(coordinate.longitude, forKey: .longitude)
        try container.encode(accuracy, forKey: .accuracy)
        try container.encode(altitude, forKey: .altitude)
        try container.encode(speed, forKey: .speed)
        try container.encode(course, forKey: .course)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(motionState, forKey: .motionState)
    }
}

struct CorrectedLocation {
    let coordinate: CLLocationCoordinate2D
    let originalCoordinate: CLLocationCoordinate2D
    let confidence: Double  // 0-1
    let environment: EnvironmentType
    let gpsReliability: GPSReliability
    let wasAICorrected: Bool

    var correctionDistance: Double {
        let loc1 = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let loc2 = CLLocation(latitude: originalCoordinate.latitude, longitude: originalCoordinate.longitude)
        return loc1.distance(from: loc2)
    }
}

enum EnvironmentType: String, Codable {
    case openSky       // Clear GPS signal
    case suburban      // Some obstructions
    case urbanCanyon   // Tall buildings, reflections likely
    case indoor        // GPS unreliable
    case underground   // No GPS
    case unknown

    var displayName: String {
        switch self {
        case .openSky: return "Clear signal"
        case .suburban: return "Good signal"
        case .urbanCanyon: return "Urban area"
        case .indoor: return "Indoors"
        case .underground: return "Underground"
        case .unknown: return "Unknown"
        }
    }

    var gpsReliabilityFactor: Double {
        switch self {
        case .openSky: return 1.0
        case .suburban: return 0.85
        case .urbanCanyon: return 0.5
        case .indoor: return 0.2
        case .underground: return 0.0
        case .unknown: return 0.5
        }
    }
}

enum GPSReliability: String, Codable {
    case excellent
    case good
    case fair
    case poor
    case unavailable
    case unknown

    var displayName: String {
        switch self {
        case .excellent: return "Excellent"
        case .good: return "Good"
        case .fair: return "Fair"
        case .poor: return "Poor"
        case .unavailable: return "Unavailable"
        case .unknown: return "Unknown"
        }
    }

    var color: String {
        switch self {
        case .excellent: return "green"
        case .good: return "green"
        case .fair: return "yellow"
        case .poor: return "orange"
        case .unavailable: return "red"
        case .unknown: return "gray"
        }
    }
}

// Extension to make MotionState codable if not already
extension MotionState: Codable {}
