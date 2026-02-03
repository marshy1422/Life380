import Foundation
import CoreLocation
import CoreMotion

/// A single training sample for the location ML model
/// Contains input features and ground truth for supervised learning
struct LocationTrainingSample: Codable, Identifiable {
    let id: UUID
    let timestamp: Date

    // MARK: - Raw Input Data

    /// Raw GPS reading
    let rawLatitude: Double
    let rawLongitude: Double
    let rawAccuracy: Double
    let altitude: Double?
    let verticalAccuracy: Double?
    let speed: Double
    let course: Double

    // MARK: - Context Features

    /// Time-based features
    let hourOfDay: Int          // 0-23
    let dayOfWeek: Int          // 1-7 (Sun-Sat)
    let isWeekend: Bool
    let minuteOfHour: Int       // 0-59

    /// Motion features
    let motionState: String     // stationary, walking, driving, etc.
    let accelerometerMagnitude: Double?
    let isStationary: Bool

    /// Historical features (from recent samples)
    let recentSpeedVariance: Double
    let recentLocationVariance: Double  // meters
    let timeSinceLastSample: Double     // seconds
    let distanceFromLastSample: Double  // meters
    let samplesInLast5Minutes: Int

    /// Environment features
    let batteryLevel: Double
    let isCharging: Bool
    let isLowPowerMode: Bool

    /// Place context
    let isAtKnownPlace: Bool
    let distanceToNearestKnownPlace: Double?
    let knownPlaceType: String?  // home, work, etc.

    // MARK: - Ground Truth (for training)

    /// The actual/corrected location (user-provided or high-confidence)
    var groundTruthLatitude: Double?
    var groundTruthLongitude: Double?
    var groundTruthSource: GroundTruthSource

    /// Quality metrics
    var wasAccurate: Bool?  // Did raw GPS match ground truth within threshold?
    var errorDistance: Double?  // Distance between raw and ground truth

    // MARK: - Initialization

    init(
        rawLocation: CLLocation,
        motionState: MotionState,
        context: SampleContext,
        groundTruth: GroundTruth? = nil
    ) {
        self.id = UUID()
        self.timestamp = rawLocation.timestamp

        // Raw GPS
        self.rawLatitude = rawLocation.coordinate.latitude
        self.rawLongitude = rawLocation.coordinate.longitude
        self.rawAccuracy = rawLocation.horizontalAccuracy
        self.altitude = rawLocation.altitude
        self.verticalAccuracy = rawLocation.verticalAccuracy >= 0 ? rawLocation.verticalAccuracy : nil
        self.speed = max(0, rawLocation.speed)
        self.course = rawLocation.course >= 0 ? rawLocation.course : 0

        // Time features
        let calendar = Calendar.current
        self.hourOfDay = calendar.component(.hour, from: rawLocation.timestamp)
        self.dayOfWeek = calendar.component(.weekday, from: rawLocation.timestamp)
        self.isWeekend = self.dayOfWeek == 1 || self.dayOfWeek == 7
        self.minuteOfHour = calendar.component(.minute, from: rawLocation.timestamp)

        // Motion
        self.motionState = motionState.rawValue
        self.accelerometerMagnitude = context.accelerometerMagnitude
        self.isStationary = motionState == .stationary

        // Historical
        self.recentSpeedVariance = context.recentSpeedVariance
        self.recentLocationVariance = context.recentLocationVariance
        self.timeSinceLastSample = context.timeSinceLastSample
        self.distanceFromLastSample = context.distanceFromLastSample
        self.samplesInLast5Minutes = context.samplesInLast5Minutes

        // Environment
        self.batteryLevel = context.batteryLevel
        self.isCharging = context.isCharging
        self.isLowPowerMode = context.isLowPowerMode

        // Place context
        self.isAtKnownPlace = context.isAtKnownPlace
        self.distanceToNearestKnownPlace = context.distanceToNearestKnownPlace
        self.knownPlaceType = context.knownPlaceType

        // Ground truth
        if let gt = groundTruth {
            self.groundTruthLatitude = gt.latitude
            self.groundTruthLongitude = gt.longitude
            self.groundTruthSource = gt.source
            self.wasAccurate = gt.errorDistance < 20  // Within 20m = accurate
            self.errorDistance = gt.errorDistance
        } else {
            self.groundTruthLatitude = nil
            self.groundTruthLongitude = nil
            self.groundTruthSource = .none
            self.wasAccurate = nil
            self.errorDistance = nil
        }
    }

    // MARK: - Feature Vector

    /// Convert to normalized feature vector for ML model
    func toFeatureVector() -> [Double] {
        var features: [Double] = []

        // Accuracy (normalized 0-1, where 1 = best)
        features.append(min(1.0, 10.0 / max(rawAccuracy, 1)))

        // Speed (normalized, cap at 50 m/s)
        features.append(min(1.0, speed / 50.0))

        // Course (normalized to 0-1)
        features.append(course / 360.0)

        // Time features (cyclical encoding)
        features.append(sin(2 * .pi * Double(hourOfDay) / 24.0))
        features.append(cos(2 * .pi * Double(hourOfDay) / 24.0))
        features.append(sin(2 * .pi * Double(dayOfWeek) / 7.0))
        features.append(cos(2 * .pi * Double(dayOfWeek) / 7.0))
        features.append(isWeekend ? 1.0 : 0.0)

        // Motion (one-hot encoded)
        features.append(motionState == "stationary" ? 1.0 : 0.0)
        features.append(motionState == "walking" ? 1.0 : 0.0)
        features.append(motionState == "running" ? 1.0 : 0.0)
        features.append(motionState == "driving" ? 1.0 : 0.0)
        features.append(isStationary ? 1.0 : 0.0)

        // Variance features (normalized)
        features.append(min(1.0, recentSpeedVariance / 10.0))
        features.append(min(1.0, recentLocationVariance / 100.0))

        // Temporal features
        features.append(min(1.0, timeSinceLastSample / 300.0))  // Cap at 5 min
        features.append(min(1.0, distanceFromLastSample / 500.0))  // Cap at 500m
        features.append(min(1.0, Double(samplesInLast5Minutes) / 30.0))

        // Environment
        features.append(batteryLevel)
        features.append(isCharging ? 1.0 : 0.0)
        features.append(isLowPowerMode ? 1.0 : 0.0)

        // Place context
        features.append(isAtKnownPlace ? 1.0 : 0.0)
        if let dist = distanceToNearestKnownPlace {
            features.append(min(1.0, dist / 1000.0))
        } else {
            features.append(1.0)  // Far from known places
        }

        return features
    }

    /// Number of features in the vector
    static var featureCount: Int { 23 }
}

// MARK: - Supporting Types

struct SampleContext {
    var accelerometerMagnitude: Double?
    var recentSpeedVariance: Double
    var recentLocationVariance: Double
    var timeSinceLastSample: Double
    var distanceFromLastSample: Double
    var samplesInLast5Minutes: Int
    var batteryLevel: Double
    var isCharging: Bool
    var isLowPowerMode: Bool
    var isAtKnownPlace: Bool
    var distanceToNearestKnownPlace: Double?
    var knownPlaceType: String?

    static var empty: SampleContext {
        SampleContext(
            accelerometerMagnitude: nil,
            recentSpeedVariance: 0,
            recentLocationVariance: 0,
            timeSinceLastSample: 0,
            distanceFromLastSample: 0,
            samplesInLast5Minutes: 0,
            batteryLevel: 1.0,
            isCharging: false,
            isLowPowerMode: false,
            isAtKnownPlace: false,
            distanceToNearestKnownPlace: nil,
            knownPlaceType: nil
        )
    }
}

struct GroundTruth {
    let latitude: Double
    let longitude: Double
    let source: GroundTruthSource
    let errorDistance: Double  // Distance from raw GPS

    init(latitude: Double, longitude: Double, source: GroundTruthSource, rawLocation: CLLocation) {
        self.latitude = latitude
        self.longitude = longitude
        self.source = source

        let gtLocation = CLLocation(latitude: latitude, longitude: longitude)
        self.errorDistance = rawLocation.distance(from: gtLocation)
    }
}

enum GroundTruthSource: String, Codable {
    case userCorrection       // User explicitly corrected location
    case knownPlace          // User arrived at a known place
    case highConfidenceGPS   // GPS accuracy < 5m
    case stationaryAverage   // Average of stationary readings
    case none                // No ground truth available
}
