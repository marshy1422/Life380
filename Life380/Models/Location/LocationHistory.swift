import Foundation
import CoreLocation

/// Place category for history
enum HistoryPlaceCategory: String, Codable, CaseIterable {
    case home
    case work
    case school
    case gym
    case restaurant
    case shopping
    case medical
    case entertainment
    case transport
    case unknown

    var icon: String {
        switch self {
        case .home: return "house.fill"
        case .work: return "building.2.fill"
        case .school: return "graduationcap.fill"
        case .gym: return "figure.run"
        case .restaurant: return "fork.knife"
        case .shopping: return "cart.fill"
        case .medical: return "cross.fill"
        case .entertainment: return "theatermasks.fill"
        case .transport: return "car.fill"
        case .unknown: return "mappin"
        }
    }
}

/// A historical location record
struct LocationHistoryPoint: Identifiable, Codable {
    let id: UUID
    let latitude: Double
    let longitude: Double
    let altitude: Double?
    let horizontalAccuracy: Double
    let timestamp: Date
    let speed: Double?
    let course: Double?
    var address: String?
    var placeCategory: HistoryPlaceCategory?

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var location: CLLocation {
        CLLocation(
            coordinate: coordinate,
            altitude: altitude ?? 0,
            horizontalAccuracy: horizontalAccuracy,
            verticalAccuracy: -1,
            course: course ?? -1,
            speed: speed ?? -1,
            timestamp: timestamp
        )
    }

    init(id: UUID = UUID(), location: CLLocation, address: String? = nil, placeCategory: HistoryPlaceCategory? = nil) {
        self.id = id
        self.latitude = location.coordinate.latitude
        self.longitude = location.coordinate.longitude
        self.altitude = location.altitude
        self.horizontalAccuracy = location.horizontalAccuracy
        self.timestamp = location.timestamp
        self.speed = location.speed >= 0 ? location.speed : nil
        self.course = location.course >= 0 ? location.course : nil
        self.address = address
        self.placeCategory = placeCategory
    }

    init(id: UUID = UUID(), latitude: Double, longitude: Double, altitude: Double? = nil, horizontalAccuracy: Double = 10, timestamp: Date = Date(), speed: Double? = nil, course: Double? = nil, address: String? = nil, placeCategory: HistoryPlaceCategory? = nil) {
        self.id = id
        self.latitude = latitude
        self.longitude = longitude
        self.altitude = altitude
        self.horizontalAccuracy = horizontalAccuracy
        self.timestamp = timestamp
        self.speed = speed
        self.course = course
        self.address = address
        self.placeCategory = placeCategory
    }
}

/// A visit to a place
struct LocationVisit: Identifiable, Codable {
    let id: UUID
    let latitude: Double
    let longitude: Double
    let arrivalTime: Date
    var departureTime: Date?
    let horizontalAccuracy: Double
    var placeName: String?
    var placeCategory: HistoryPlaceCategory

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var duration: TimeInterval? {
        guard let departure = departureTime else { return nil }
        return departure.timeIntervalSince(arrivalTime)
    }

    var durationMinutes: Double? {
        guard let dur = duration else { return nil }
        return dur / 60.0
    }

    init(id: UUID = UUID(), location: CLLocation, placeName: String? = nil, placeCategory: HistoryPlaceCategory = .unknown) {
        self.id = id
        self.latitude = location.coordinate.latitude
        self.longitude = location.coordinate.longitude
        self.arrivalTime = location.timestamp
        self.departureTime = nil
        self.horizontalAccuracy = location.horizontalAccuracy
        self.placeName = placeName
        self.placeCategory = placeCategory
    }

    init(id: UUID = UUID(), latitude: Double, longitude: Double, arrivalTime: Date, departureTime: Date? = nil, horizontalAccuracy: Double = 10, placeName: String? = nil, placeCategory: HistoryPlaceCategory = .unknown) {
        self.id = id
        self.latitude = latitude
        self.longitude = longitude
        self.arrivalTime = arrivalTime
        self.departureTime = departureTime
        self.horizontalAccuracy = horizontalAccuracy
        self.placeName = placeName
        self.placeCategory = placeCategory
    }
}

/// Type alias for backwards compatibility
typealias LocationHistoryVisit = LocationVisit

/// Daily location summary
struct DailyLocationSummary: Identifiable, Codable {
    let id: UUID
    let date: Date
    let totalDistanceMiles: Double
    let totalTravelMinutes: Double
    let placesVisited: Int
    let topPlace: String?
    let travelSegments: Int

    init(id: UUID = UUID(), date: Date, totalDistanceMiles: Double = 0, totalTravelMinutes: Double = 0, placesVisited: Int = 0, topPlace: String? = nil, travelSegments: Int = 0) {
        self.id = id
        self.date = date
        self.totalDistanceMiles = totalDistanceMiles
        self.totalTravelMinutes = totalTravelMinutes
        self.placesVisited = placesVisited
        self.topPlace = topPlace
        self.travelSegments = travelSegments
    }
}

/// Day's location history
struct DayLocationHistory: Identifiable, Codable {
    let id: UUID
    let date: Date
    var points: [LocationHistoryPoint]
    var visits: [LocationVisit]

    init(id: UUID = UUID(), date: Date, points: [LocationHistoryPoint] = [], visits: [LocationVisit] = []) {
        self.id = id
        self.date = date
        self.points = points
        self.visits = visits
    }
}
