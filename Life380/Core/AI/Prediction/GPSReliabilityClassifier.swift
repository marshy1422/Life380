import Foundation
import CoreLocation

/// Classifies GPS reliability based on signal characteristics
/// Detects indoor, urban canyon, and other environments where GPS is unreliable
class GPSReliabilityClassifier {

    // MARK: - State

    private(set) var reliability: GPSReliability = .unknown
    private(set) var confidence: Double = 0.5

    private var recentSamples: [ClassificationSample] = []
    private let maxSamples = 20

    // MARK: - Thresholds

    private struct Thresholds {
        // Accuracy thresholds (meters)
        static let excellentAccuracy: Double = 5
        static let goodAccuracy: Double = 15
        static let fairAccuracy: Double = 50
        static let poorAccuracy: Double = 100

        // Variance thresholds (meters)
        static let lowVariance: Double = 10
        static let mediumVariance: Double = 30
        static let highVariance: Double = 100

        // Speed anomaly (m/s) - impossible walking speed suggests GPS jump
        static let impossibleWalkingSpeed: Double = 15  // ~54 km/h
        static let impossibleStationaryJump: Double = 50  // 50m jump while "stationary"
    }

    // MARK: - Public API

    /// Classify the current environment based on GPS characteristics
    func classify(accuracy: Double, speed: Double, recentVariance: Double) -> EnvironmentType {

        // High accuracy, low variance = open sky
        if accuracy < Thresholds.goodAccuracy && recentVariance < Thresholds.lowVariance {
            reliability = accuracy < Thresholds.excellentAccuracy ? .excellent : .good
            return .openSky
        }

        // Good accuracy but some variance = suburban
        if accuracy < Thresholds.fairAccuracy && recentVariance < Thresholds.mediumVariance {
            reliability = .good
            return .suburban
        }

        // High variance with jumps = urban canyon (multipath)
        if recentVariance > Thresholds.highVariance {
            reliability = .fair
            return .urbanCanyon
        }

        // Poor accuracy = likely indoor
        if accuracy > Thresholds.poorAccuracy {
            reliability = .poor
            return .indoor
        }

        // Medium accuracy, high variance = urban canyon
        if accuracy > Thresholds.fairAccuracy && recentVariance > Thresholds.mediumVariance {
            reliability = .fair
            return .urbanCanyon
        }

        reliability = .good
        return .suburban
    }

    /// Update classifier with a new sample
    func updateWithSample(_ sample: LocationSample) {
        let classificationSample = ClassificationSample(
            accuracy: sample.accuracy,
            speed: sample.speed,
            timestamp: sample.timestamp
        )

        recentSamples.append(classificationSample)
        if recentSamples.count > maxSamples {
            recentSamples.removeFirst()
        }

        // Recalculate reliability
        analyzeRecentSamples()
    }

    /// Detect if a GPS jump is likely noise (not real movement)
    func isLikelyGPSJump(
        from previousLocation: CLLocationCoordinate2D,
        to newLocation: CLLocationCoordinate2D,
        timeInterval: TimeInterval,
        reportedSpeed: Double,
        motionState: MotionState
    ) -> Bool {

        let distance = calculateDistance(from: previousLocation, to: newLocation)
        let impliedSpeed = distance / max(timeInterval, 1)

        // Stationary but big jump = GPS noise
        if motionState == .stationary && distance > Thresholds.impossibleStationaryJump {
            return true
        }

        // Walking but impossible speed = GPS noise
        if motionState == .walking && impliedSpeed > Thresholds.impossibleWalkingSpeed {
            return true
        }

        // Huge discrepancy between reported and implied speed
        if reportedSpeed > 0 && impliedSpeed > reportedSpeed * 5 {
            return true
        }

        // Check against recent pattern
        if let variance = calculateRecentVariance(), distance > variance * 3 {
            return true
        }

        return false
    }

    /// Get confidence that current location is accurate
    func getLocationConfidence(accuracy: Double) -> Double {
        // Base confidence from accuracy
        var confidence: Double

        if accuracy < Thresholds.excellentAccuracy {
            confidence = 0.95
        } else if accuracy < Thresholds.goodAccuracy {
            confidence = 0.85
        } else if accuracy < Thresholds.fairAccuracy {
            confidence = 0.7
        } else if accuracy < Thresholds.poorAccuracy {
            confidence = 0.5
        } else {
            confidence = 0.3
        }

        // Adjust for recent reliability
        switch reliability {
        case .excellent:
            confidence *= 1.0
        case .good:
            confidence *= 0.95
        case .fair:
            confidence *= 0.8
        case .poor:
            confidence *= 0.6
        case .unavailable:
            confidence *= 0.3
        case .unknown:
            confidence *= 0.7
        }

        return min(1.0, max(0.1, confidence))
    }

    // MARK: - Private Methods

    private func analyzeRecentSamples() {
        guard recentSamples.count >= 5 else {
            reliability = .unknown
            return
        }

        let accuracies = recentSamples.map { $0.accuracy }
        let avgAccuracy = accuracies.reduce(0, +) / Double(accuracies.count)
        let variance = calculateVariance(accuracies)

        // Classify based on average accuracy and variance
        if avgAccuracy < Thresholds.excellentAccuracy && variance < 5 {
            reliability = .excellent
            confidence = 0.95
        } else if avgAccuracy < Thresholds.goodAccuracy && variance < 15 {
            reliability = .good
            confidence = 0.85
        } else if avgAccuracy < Thresholds.fairAccuracy {
            reliability = .fair
            confidence = 0.7
        } else if avgAccuracy < Thresholds.poorAccuracy {
            reliability = .poor
            confidence = 0.5
        } else {
            reliability = .unavailable
            confidence = 0.3
        }
    }

    private func calculateRecentVariance() -> Double? {
        guard recentSamples.count >= 3 else { return nil }
        let accuracies = recentSamples.suffix(10).map { $0.accuracy }
        return calculateVariance(accuracies)
    }

    private func calculateVariance(_ values: [Double]) -> Double {
        guard values.count > 1 else { return 0 }
        let mean = values.reduce(0, +) / Double(values.count)
        let sumSquaredDiff = values.map { pow($0 - mean, 2) }.reduce(0, +)
        return sqrt(sumSquaredDiff / Double(values.count - 1))
    }

    private func calculateDistance(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
        let loc1 = CLLocation(latitude: from.latitude, longitude: from.longitude)
        let loc2 = CLLocation(latitude: to.latitude, longitude: to.longitude)
        return loc1.distance(from: loc2)
    }
}

// MARK: - Supporting Types

private struct ClassificationSample {
    let accuracy: Double
    let speed: Double
    let timestamp: Date
}
