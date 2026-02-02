import Foundation
import CoreLocation
import Combine

/// Protocol defining location service capabilities
protocol LocationServiceProtocol: AnyObject {
    // MARK: - Published Properties

    var currentLocation: CLLocation? { get }
    var authorizationStatus: CLAuthorizationStatus { get }
    var isAuthorized: Bool { get }

    // MARK: - Authorization

    func requestWhenInUseAuthorization()
    func requestAlwaysAuthorization()

    // MARK: - Location Updates

    func startUpdatingLocation()
    func stopUpdatingLocation()
    func requestLocation()

    // MARK: - Significant Location Changes

    func startMonitoringSignificantLocationChanges()
    func stopMonitoringSignificantLocationChanges()
}

/// Protocol for high-precision location tracking
protocol PrecisionLocationServiceProtocol: LocationServiceProtocol {
    // MARK: - Precision Properties

    var horizontalAccuracy: Double? { get }
    var verticalAccuracy: Double? { get }
    var floor: Int? { get }

    // MARK: - Precision Configuration

    var desiredAccuracy: CLLocationAccuracy { get set }
    var distanceFilter: CLLocationDistance { get set }

    // MARK: - Activity Type

    var activityType: CLActivityType { get set }
}

/// Protocol for geofence monitoring
protocol GeofenceServiceProtocol: AnyObject {
    // MARK: - Region Monitoring

    func startMonitoring(region: CLRegion)
    func stopMonitoring(region: CLRegion)
    func stopMonitoringAllRegions()

    var monitoredRegions: Set<CLRegion> { get }

    // MARK: - Delegate Callbacks

    var onRegionEntered: ((CLRegion) -> Void)? { get set }
    var onRegionExited: ((CLRegion) -> Void)? { get set }
}
