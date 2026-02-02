import Foundation
import CoreLocation
import Combine
import SwiftUI

// Location accuracy options for battery optimization
enum LocationAccuracyLevel: String, CaseIterable {
    case high = "High"
    case medium = "Medium"
    case low = "Low"

    var clAccuracy: CLLocationAccuracy {
        switch self {
        case .high: return kCLLocationAccuracyBest
        case .medium: return kCLLocationAccuracyHundredMeters
        case .low: return kCLLocationAccuracyKilometer
        }
    }

    var distanceFilter: CLLocationDistance {
        switch self {
        case .high: return 10
        case .medium: return 50
        case .low: return 200
        }
    }
}

class LocationManager: NSObject, ObservableObject {
    private let manager = CLLocationManager()

    @Published var userLocation: CLLocationCoordinate2D?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var locationError: Error?

    // User preference for accuracy (tied to Settings)
    @AppStorage("locationAccuracy") private var accuracySetting: String = "high"

    var accuracy: LocationAccuracyLevel {
        get { LocationAccuracyLevel(rawValue: accuracySetting) ?? .high }
        set {
            accuracySetting = newValue.rawValue
            updateAccuracySettings()
        }
    }

    override init() {
        super.init()
        manager.delegate = self
        updateAccuracySettings()
    }

    private func updateAccuracySettings() {
        manager.desiredAccuracy = accuracy.clAccuracy
        manager.distanceFilter = accuracy.distanceFilter
    }

    func requestPermission() {
        manager.requestWhenInUseAuthorization()
    }

    func requestAlwaysPermission() {
        manager.requestAlwaysAuthorization()
    }

    func startUpdatingLocation() {
        manager.startUpdatingLocation()
    }

    func stopUpdatingLocation() {
        manager.stopUpdatingLocation()
    }

    func startMonitoringSignificantLocationChanges() {
        manager.startMonitoringSignificantLocationChanges()
    }

    // Enable background location updates (call after user grants always permission)
    func enableBackgroundUpdates() {
        manager.allowsBackgroundLocationUpdates = true
        #if os(iOS)
        manager.showsBackgroundLocationIndicator = true
        #endif
    }

    // Switch between foreground and background modes for battery optimization
    func handleAppStateChange(isActive: Bool) {
        if isActive {
            // Foreground: Use accurate tracking based on user preference
            manager.stopMonitoringSignificantLocationChanges()
            updateAccuracySettings()
            manager.startUpdatingLocation()
        } else if authorizationStatus == .authorizedAlways {
            // Background: Use battery-efficient significant changes
            manager.stopUpdatingLocation()
            manager.startMonitoringSignificantLocationChanges()
        }
    }
}

extension LocationManager: CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus

        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            manager.startUpdatingLocation()
            if manager.authorizationStatus == .authorizedAlways {
                enableBackgroundUpdates()
            }
        case .notDetermined:
            requestPermission()
        case .denied, .restricted:
            // Clear error when permission is denied so UI can show appropriate message
            locationError = nil
        @unknown default:
            break
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        // Clear any previous error on successful update
        locationError = nil
        userLocation = location.coordinate
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Publish error so UI can display it
        locationError = error
        #if DEBUG
        print("Location manager failed with error: \(error.localizedDescription)")
        #endif
    }
}
