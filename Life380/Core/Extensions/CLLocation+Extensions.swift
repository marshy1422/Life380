import CoreLocation

extension CLLocationCoordinate2D {
    // MARK: - Validation

    /// Whether the coordinate is valid (not null island and within bounds)
    var isValid: Bool {
        // Check for "Null Island" (0,0)
        if latitude == 0 && longitude == 0 {
            return false
        }

        // Check valid ranges
        return latitude >= -90 && latitude <= 90 &&
               longitude >= -180 && longitude <= 180
    }

    // MARK: - Distance

    /// Calculates distance to another coordinate in meters
    func distance(to other: CLLocationCoordinate2D) -> CLLocationDistance {
        let from = CLLocation(latitude: latitude, longitude: longitude)
        let to = CLLocation(latitude: other.latitude, longitude: other.longitude)
        return from.distance(from: to)
    }

    /// Formatted distance string to another coordinate
    func formattedDistance(to other: CLLocationCoordinate2D) -> String {
        let meters = distance(to: other)
        return meters.formattedDistance
    }
}

extension CLLocationDistance {
    // MARK: - Formatting

    /// Formats distance for display (e.g., "1.2 km" or "500 m")
    var formattedDistance: String {
        if self >= 1000 {
            let km = self / 1000
            if km >= 10 {
                return String(format: "%.0f km", km)
            }
            return String(format: "%.1f km", km)
        } else {
            return String(format: "%.0f m", self)
        }
    }

    /// Formats distance in miles
    var formattedMiles: String {
        let miles = self / 1609.34
        if miles >= 10 {
            return String(format: "%.0f mi", miles)
        } else if miles >= 0.1 {
            return String(format: "%.1f mi", miles)
        } else {
            let feet = self * 3.28084
            return String(format: "%.0f ft", feet)
        }
    }
}

extension CLLocation {
    // MARK: - Convenience Initializers

    /// Creates a CLLocation from a coordinate
    convenience init(coordinate: CLLocationCoordinate2D) {
        self.init(latitude: coordinate.latitude, longitude: coordinate.longitude)
    }

    // MARK: - Validation

    /// Whether this location has valid accuracy (positive value)
    var hasValidAccuracy: Bool {
        horizontalAccuracy >= 0
    }

    /// Whether this location meets the minimum accuracy threshold (100m)
    var meetsAccuracyThreshold: Bool {
        horizontalAccuracy >= 0 && horizontalAccuracy <= 100
    }

    // MARK: - Staleness

    /// Whether the location is stale (older than 60 seconds)
    var isStale: Bool {
        age > 60
    }

    /// Age of the location in seconds
    var age: TimeInterval {
        -timestamp.timeIntervalSinceNow
    }
}

extension CLLocationAccuracy {
    // MARK: - Display

    /// Formatted accuracy string (e.g., "within 10m")
    var formattedAccuracy: String {
        if self < 0 {
            return "Unknown"
        } else if self < 10 {
            return "within \(Int(self))m"
        } else if self < 100 {
            return "within \(Int(self))m"
        } else if self < 1000 {
            return "within \(Int(self / 10) * 10)m"
        } else {
            return "within \(String(format: "%.1f", self / 1000))km"
        }
    }

    /// Quality descriptor for the accuracy
    var qualityDescription: String {
        switch self {
        case ..<5: return "Excellent"
        case 5..<15: return "Precise"
        case 15..<50: return "Good"
        case 50..<100: return "Fair"
        default: return "Estimated"
        }
    }
}
