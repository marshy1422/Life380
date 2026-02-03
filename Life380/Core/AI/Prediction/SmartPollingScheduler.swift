import Foundation
import CoreLocation

/// AI-driven scheduler that determines optimal location polling intervals
/// Balances accuracy needs with battery conservation
class SmartPollingScheduler {

    // MARK: - Configuration

    struct Config {
        // Base intervals (seconds)
        static let minInterval: TimeInterval = 3        // Never poll faster than 3s
        static let maxInterval: TimeInterval = 300      // Never wait longer than 5 min
        static let stationaryInterval: TimeInterval = 120  // 2 min when not moving
        static let movingInterval: TimeInterval = 10    // 10s when moving

        // Battery thresholds
        static let lowBatteryThreshold: Double = 0.20   // Below 20% = aggressive saving
        static let criticalBatteryThreshold: Double = 0.10  // Below 10% = minimal polling
    }

    // MARK: - State

    private var lastCalculatedInterval: TimeInterval = 30
    private var intervalHistory: [TimeInterval] = []
    private let maxHistorySize = 20

    // MARK: - Public API

    /// Calculate optimal polling interval based on current context
    func calculateOptimalInterval(
        motionState: MotionState,
        environment: EnvironmentType,
        atKnownPlace: Bool,
        batteryLevel: Double
    ) -> TimeInterval {

        var interval = baseInterval(for: motionState)

        // Adjust for environment
        interval *= environmentMultiplier(environment)

        // Adjust for known place
        if atKnownPlace {
            interval *= 1.5  // Less frequent at known places
        }

        // Adjust for battery level
        interval *= batteryMultiplier(batteryLevel)

        // Clamp to valid range
        interval = max(Config.minInterval, min(Config.maxInterval, interval))

        // Smooth changes (don't jump dramatically)
        interval = smoothInterval(interval)

        lastCalculatedInterval = interval
        return interval
    }

    /// Predict when the next location update will be valuable
    func predictNextValueableUpdateTime(
        currentLocation: CLLocationCoordinate2D,
        velocity: Double,  // m/s
        heading: Double
    ) -> Date {

        // If stationary, next valuable update is when we expect movement
        if velocity < 0.5 {
            return Date().addingTimeInterval(Config.stationaryInterval)
        }

        // If moving, calculate when we'll have moved significantly
        let significantDistance: Double = 50  // meters
        let timeToSignificantMove = significantDistance / max(velocity, 0.5)

        let interval = min(timeToSignificantMove, Config.maxInterval)
        return Date().addingTimeInterval(interval)
    }

    /// Get recommended accuracy level based on context
    func recommendedAccuracy(
        motionState: MotionState,
        batteryLevel: Double
    ) -> AIAccuracyLevel {

        // Critical battery = lowest accuracy
        if batteryLevel < Config.criticalBatteryThreshold {
            return .coarse
        }

        // Low battery = reduced accuracy
        if batteryLevel < Config.lowBatteryThreshold {
            return motionState == .driving ? .medium : .coarse
        }

        // Normal battery - base on motion
        switch motionState {
        case .stationary:
            return .coarse
        case .walking, .running:
            return .medium
        case .cycling:
            return .high
        case .driving:
            return .high
        case .unknown:
            return .medium
        }
    }

    /// Determine if we should skip this polling cycle
    func shouldSkipPoll(
        timeSinceLastUpdate: TimeInterval,
        motionState: MotionState,
        atKnownPlace: Bool
    ) -> Bool {

        let optimalInterval = lastCalculatedInterval

        // Always poll if it's been too long
        if timeSinceLastUpdate > Config.maxInterval {
            return false
        }

        // Skip if stationary at known place and recently updated
        if motionState == .stationary && atKnownPlace && timeSinceLastUpdate < optimalInterval {
            return true
        }

        return false
    }

    // MARK: - Private Methods

    private func baseInterval(for motionState: MotionState) -> TimeInterval {
        switch motionState {
        case .stationary:
            return 60  // 1 minute when still
        case .walking:
            return 15  // 15 seconds when walking
        case .running:
            return 8   // 8 seconds when running
        case .cycling:
            return 6   // 6 seconds when cycling
        case .driving:
            return 5   // 5 seconds when driving
        case .unknown:
            return 20  // 20 seconds default
        }
    }

    private func environmentMultiplier(_ environment: EnvironmentType) -> Double {
        switch environment {
        case .openSky:
            return 1.0  // GPS reliable, normal polling
        case .suburban:
            return 1.0
        case .urbanCanyon:
            return 0.8  // Poll more often, GPS less reliable
        case .indoor:
            return 1.5  // GPS unreliable, poll less (save battery)
        case .underground:
            return 2.0  // No GPS, minimal polling
        case .unknown:
            return 1.0
        }
    }

    private func batteryMultiplier(_ level: Double) -> Double {
        if level < Config.criticalBatteryThreshold {
            return 3.0  // Triple intervals at critical battery
        } else if level < Config.lowBatteryThreshold {
            return 2.0  // Double intervals at low battery
        } else if level < 0.5 {
            return 1.3  // Slightly increase intervals below 50%
        }
        return 1.0
    }

    private func smoothInterval(_ newInterval: TimeInterval) -> TimeInterval {
        intervalHistory.append(newInterval)
        if intervalHistory.count > maxHistorySize {
            intervalHistory.removeFirst()
        }

        // Use exponential moving average
        let alpha = 0.3
        var smoothed = intervalHistory.first ?? newInterval

        for interval in intervalHistory.dropFirst() {
            smoothed = alpha * interval + (1 - alpha) * smoothed
        }

        return smoothed
    }
}

// MARK: - Supporting Types

enum AIAccuracyLevel {
    case coarse      // ~100m - battery friendly
    case medium      // ~30m - balanced
    case high        // ~10m - precise
    case best        // Best available - battery intensive

    var clAccuracy: CLLocationAccuracy {
        switch self {
        case .coarse:
            return kCLLocationAccuracyHundredMeters
        case .medium:
            return kCLLocationAccuracyNearestTenMeters
        case .high:
            return kCLLocationAccuracyBest
        case .best:
            return kCLLocationAccuracyBestForNavigation
        }
    }

    var displayName: String {
        switch self {
        case .coarse: return "Battery Saver"
        case .medium: return "Balanced"
        case .high: return "High Accuracy"
        case .best: return "Maximum Accuracy"
        }
    }
}
