import Foundation
import CoreLocation
import CoreMotion

/// Predicts user's motion state and future movement patterns
/// Uses location history and device motion to determine if user is stationary, walking, driving, etc.
class MotionPredictor {

    // MARK: - State

    private(set) var currentState: MotionState = .unknown
    private(set) var confidence: Double = 0.5
    private(set) var predictedState: MotionState = .unknown
    private(set) var stateHistory: [(state: MotionState, timestamp: Date)] = []

    private var recentSamples: [MotionSample] = []
    private let maxSamples = 30

    // MARK: - Thresholds

    private struct Thresholds {
        // Speed thresholds (m/s)
        static let stationarySpeed: Double = 0.5      // < 0.5 m/s = stationary
        static let walkingSpeed: Double = 2.0         // < 2 m/s = walking
        static let runningSpeed: Double = 4.0         // < 4 m/s = running
        static let cyclingSpeed: Double = 8.0         // < 8 m/s = cycling
        // Above 8 m/s = driving

        // Acceleration variance for activity detection
        static let stationaryVariance: Double = 0.1
        static let walkingVariance: Double = 1.0
    }

    // MARK: - Core Motion

    private let motionManager = CMMotionActivityManager()
    private let motionQueue = OperationQueue()
    private var usesCoreMotion = false

    // MARK: - Initialization

    init() {
        // Try to use Core Motion if available
        if CMMotionActivityManager.isActivityAvailable() {
            startCoreMotionUpdates()
        }
    }

    deinit {
        motionManager.stopActivityUpdates()
    }

    // MARK: - Public API

    /// Add a location sample for analysis
    func addSample(_ sample: LocationSample) {
        let motionSample = MotionSample(
            speed: sample.speed,
            course: sample.course,
            timestamp: sample.timestamp
        )

        recentSamples.append(motionSample)
        if recentSamples.count > maxSamples {
            recentSamples.removeFirst()
        }

        // Only analyze from location if Core Motion isn't working
        if !usesCoreMotion {
            analyzeMotionFromLocation()
        }
    }

    /// Analyze a batch of samples (for historical analysis)
    func analyze(_ samples: [LocationSample]) {
        guard samples.count >= 3 else { return }

        for sample in samples {
            addSample(sample)
        }
    }

    /// Predict future motion state
    func predictFutureState(in seconds: TimeInterval) -> MotionState {
        // Simple prediction: assume current state continues
        // More sophisticated: look at historical patterns for time of day
        return currentState
    }

    /// Get time until predicted state change
    func timeUntilStateChange() -> TimeInterval? {
        // Analyze recent state changes to predict next one
        guard stateHistory.count >= 3 else { return nil }

        // Find average duration of current state
        var durations: [TimeInterval] = []
        var lastChange: Date?

        for (state, timestamp) in stateHistory {
            if state == currentState {
                if let last = lastChange {
                    durations.append(timestamp.timeIntervalSince(last))
                }
                lastChange = timestamp
            }
        }

        guard !durations.isEmpty else { return nil }

        let avgDuration = durations.reduce(0, +) / Double(durations.count)
        let currentDuration = Date().timeIntervalSince(stateHistory.last?.timestamp ?? Date())

        return max(0, avgDuration - currentDuration)
    }

    // MARK: - Private Methods

    private func startCoreMotionUpdates() {
        motionManager.startActivityUpdates(to: motionQueue) { [weak self] activity in
            guard let activity = activity else { return }
            DispatchQueue.main.async {
                self?.processCoreMotionActivity(activity)
            }
        }
        usesCoreMotion = true
    }

    private func processCoreMotionActivity(_ activity: CMMotionActivity) {
        let previousState = currentState

        if activity.stationary {
            currentState = .stationary
            confidence = Double(activity.confidence.rawValue) / 2.0
        } else if activity.walking {
            currentState = .walking
            confidence = Double(activity.confidence.rawValue) / 2.0
        } else if activity.running {
            currentState = .running
            confidence = Double(activity.confidence.rawValue) / 2.0
        } else if activity.cycling {
            currentState = .cycling
            confidence = Double(activity.confidence.rawValue) / 2.0
        } else if activity.automotive {
            currentState = .driving
            confidence = Double(activity.confidence.rawValue) / 2.0
        } else {
            currentState = .unknown
            confidence = 0.3
        }

        // Record state change
        if currentState != previousState {
            stateHistory.append((state: currentState, timestamp: Date()))
            if stateHistory.count > 100 {
                stateHistory.removeFirst()
            }
        }
    }

    private func analyzeMotionFromLocation() {
        guard recentSamples.count >= 3 else { return }

        let previousState = currentState

        // Calculate average speed from recent samples
        let speeds = recentSamples.suffix(10).map { $0.speed }
        let avgSpeed = speeds.reduce(0, +) / Double(speeds.count)

        // Calculate speed variance (for detecting walking vs stationary)
        let speedVariance = calculateVariance(speeds)

        // Classify based on speed
        if avgSpeed < Thresholds.stationarySpeed || (avgSpeed < 1.0 && speedVariance < Thresholds.stationaryVariance) {
            currentState = .stationary
            confidence = 0.8
        } else if avgSpeed < Thresholds.walkingSpeed {
            currentState = .walking
            confidence = 0.7
        } else if avgSpeed < Thresholds.runningSpeed {
            currentState = .running
            confidence = 0.6
        } else if avgSpeed < Thresholds.cyclingSpeed {
            currentState = .cycling
            confidence = 0.5
        } else {
            currentState = .driving
            confidence = 0.7
        }

        // Adjust confidence based on consistency
        let recentStates = recentSamples.suffix(5).map { classifySpeed($0.speed) }
        let stateMatches = recentStates.filter { $0 == currentState }.count
        confidence *= Double(stateMatches) / Double(recentStates.count)

        // Record state change
        if currentState != previousState {
            stateHistory.append((state: currentState, timestamp: Date()))
            if stateHistory.count > 100 {
                stateHistory.removeFirst()
            }
        }
    }

    private func classifySpeed(_ speed: Double) -> MotionState {
        if speed < Thresholds.stationarySpeed {
            return .stationary
        } else if speed < Thresholds.walkingSpeed {
            return .walking
        } else if speed < Thresholds.runningSpeed {
            return .running
        } else if speed < Thresholds.cyclingSpeed {
            return .cycling
        } else {
            return .driving
        }
    }

    private func calculateVariance(_ values: [Double]) -> Double {
        guard values.count > 1 else { return 0 }
        let mean = values.reduce(0, +) / Double(values.count)
        let sumSquaredDiff = values.map { pow($0 - mean, 2) }.reduce(0, +)
        return sqrt(sumSquaredDiff / Double(values.count - 1))
    }
}

// MARK: - Supporting Types

private struct MotionSample {
    let speed: Double
    let course: Double
    let timestamp: Date
}
