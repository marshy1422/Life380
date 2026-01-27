import Foundation
import CoreLocation

// MARK: - Dwell Time Insights (Option A)

/// Represents time spent at a specific place
struct DwellTimeRecord: Identifiable, Codable {
    let id: String
    let placeId: String
    let placeName: String
    let date: Date
    let entryTime: Date
    let exitTime: Date?
    var duration: TimeInterval {
        (exitTime ?? Date()).timeIntervalSince(entryTime)
    }

    init(id: String = UUID().uuidString,
         placeId: String,
         placeName: String,
         date: Date = Date(),
         entryTime: Date,
         exitTime: Date? = nil) {
        self.id = id
        self.placeId = placeId
        self.placeName = placeName
        self.date = date
        self.entryTime = entryTime
        self.exitTime = exitTime
    }
}

/// Daily summary of dwell times at all places
struct DailyDwellSummary: Identifiable, Codable {
    let id: String
    let userId: String
    let date: Date
    var placeDurations: [String: TimeInterval] // placeId -> total seconds
    var placeNames: [String: String] // placeId -> name

    var totalTrackedTime: TimeInterval {
        placeDurations.values.reduce(0, +)
    }

    init(id: String = UUID().uuidString,
         userId: String,
         date: Date,
         placeDurations: [String: TimeInterval] = [:],
         placeNames: [String: String] = [:]) {
        self.id = id
        self.userId = userId
        self.date = date
        self.placeDurations = placeDurations
        self.placeNames = placeNames
    }

    var dictionary: [String: Any] {
        [
            "id": id,
            "userId": userId,
            "date": date,
            "placeDurations": placeDurations,
            "placeNames": placeNames
        ]
    }
}

// MARK: - Travel Insights (Option B)

/// Represents a single trip between two places
struct TravelRecord: Identifiable, Codable {
    let id: String
    let userId: String
    let fromPlaceId: String?
    let fromPlaceName: String?
    let toPlaceId: String?
    let toPlaceName: String?
    let startTime: Date
    let endTime: Date
    let distance: Double // meters
    let averageSpeed: Double // m/s

    var duration: TimeInterval {
        endTime.timeIntervalSince(startTime)
    }

    var durationMinutes: Int {
        Int(duration / 60)
    }

    init(id: String = UUID().uuidString,
         userId: String,
         fromPlaceId: String? = nil,
         fromPlaceName: String? = nil,
         toPlaceId: String? = nil,
         toPlaceName: String? = nil,
         startTime: Date,
         endTime: Date,
         distance: Double,
         averageSpeed: Double) {
        self.id = id
        self.userId = userId
        self.fromPlaceId = fromPlaceId
        self.fromPlaceName = fromPlaceName
        self.toPlaceId = toPlaceId
        self.toPlaceName = toPlaceName
        self.startTime = startTime
        self.endTime = endTime
        self.distance = distance
        self.averageSpeed = averageSpeed
    }
}

/// Aggregated commute statistics for a route
struct CommuteStats: Identifiable, Codable {
    let id: String
    let fromPlaceId: String
    let fromPlaceName: String
    let toPlaceId: String
    let toPlaceName: String
    var tripCount: Int
    var totalDuration: TimeInterval
    var shortestDuration: TimeInterval
    var longestDuration: TimeInterval
    var totalDistance: Double

    var averageDuration: TimeInterval {
        tripCount > 0 ? totalDuration / Double(tripCount) : 0
    }

    var averageDistance: Double {
        tripCount > 0 ? totalDistance / Double(tripCount) : 0
    }

    var averageDurationMinutes: Int {
        Int(averageDuration / 60)
    }

    init(id: String = UUID().uuidString,
         fromPlaceId: String,
         fromPlaceName: String,
         toPlaceId: String,
         toPlaceName: String,
         tripCount: Int = 0,
         totalDuration: TimeInterval = 0,
         shortestDuration: TimeInterval = .infinity,
         longestDuration: TimeInterval = 0,
         totalDistance: Double = 0) {
        self.id = id
        self.fromPlaceId = fromPlaceId
        self.fromPlaceName = fromPlaceName
        self.toPlaceId = toPlaceId
        self.toPlaceName = toPlaceName
        self.tripCount = tripCount
        self.totalDuration = totalDuration
        self.shortestDuration = shortestDuration
        self.longestDuration = longestDuration
        self.totalDistance = totalDistance
    }

    mutating func addTrip(duration: TimeInterval, distance: Double) {
        tripCount += 1
        totalDuration += duration
        totalDistance += distance
        shortestDuration = min(shortestDuration, duration)
        longestDuration = max(longestDuration, duration)
    }
}

// MARK: - Activity Summary (Option C)

/// Weekly activity summary for a user
struct WeeklySummary: Identifiable, Codable {
    let id: String
    let userId: String
    let weekStartDate: Date
    let weekEndDate: Date

    // Dwell time totals
    var totalHomeTime: TimeInterval
    var totalWorkTime: TimeInterval
    var totalOtherPlacesTime: TimeInterval
    var placeBreakdown: [String: TimeInterval] // placeName -> duration

    // Travel totals
    var totalTravelTime: TimeInterval
    var totalDistance: Double
    var tripCount: Int
    var averageCommuteTime: TimeInterval

    // Patterns
    var mostVisitedPlace: String?
    var longestStayPlace: String?
    var longestStayDuration: TimeInterval?
    var busiestDay: String? // Day of week

    // Anomalies
    var unusualPatterns: [String]

    init(id: String = UUID().uuidString,
         userId: String,
         weekStartDate: Date,
         weekEndDate: Date) {
        self.id = id
        self.userId = userId
        self.weekStartDate = weekStartDate
        self.weekEndDate = weekEndDate
        self.totalHomeTime = 0
        self.totalWorkTime = 0
        self.totalOtherPlacesTime = 0
        self.placeBreakdown = [:]
        self.totalTravelTime = 0
        self.totalDistance = 0
        self.tripCount = 0
        self.averageCommuteTime = 0
        self.mostVisitedPlace = nil
        self.longestStayPlace = nil
        self.longestStayDuration = nil
        self.busiestDay = nil
        self.unusualPatterns = []
    }

    var dictionary: [String: Any] {
        var dict: [String: Any] = [
            "id": id,
            "userId": userId,
            "weekStartDate": weekStartDate,
            "weekEndDate": weekEndDate,
            "totalHomeTime": totalHomeTime,
            "totalWorkTime": totalWorkTime,
            "totalOtherPlacesTime": totalOtherPlacesTime,
            "placeBreakdown": placeBreakdown,
            "totalTravelTime": totalTravelTime,
            "totalDistance": totalDistance,
            "tripCount": tripCount,
            "averageCommuteTime": averageCommuteTime,
            "unusualPatterns": unusualPatterns
        ]
        if let mostVisited = mostVisitedPlace {
            dict["mostVisitedPlace"] = mostVisited
        }
        if let busiest = busiestDay {
            dict["busiestDay"] = busiest
        }
        return dict
    }
}

// MARK: - Location Event (for local tracking)

/// Raw location event stored locally before aggregation
struct LocationEvent: Identifiable, Codable {
    let id: String
    let timestamp: Date
    let latitude: Double
    let longitude: Double
    let placeId: String?
    let placeName: String?
    let eventType: LocationEventType

    enum LocationEventType: String, Codable {
        case entry
        case exit
        case update
    }

    init(id: String = UUID().uuidString,
         timestamp: Date = Date(),
         latitude: Double,
         longitude: Double,
         placeId: String? = nil,
         placeName: String? = nil,
         eventType: LocationEventType) {
        self.id = id
        self.timestamp = timestamp
        self.latitude = latitude
        self.longitude = longitude
        self.placeId = placeId
        self.placeName = placeName
        self.eventType = eventType
    }
}

// MARK: - Insight Display Models

/// For displaying in pie charts
struct DwellTimeSlice: Identifiable {
    let id = UUID()
    let placeName: String
    let placeId: String
    let duration: TimeInterval
    let color: String // Hex color
    let icon: String // SF Symbol

    var percentage: Double = 0
    var hours: Double {
        duration / 3600
    }

    var formattedDuration: String {
        let hours = Int(duration / 3600)
        let minutes = Int((duration.truncatingRemainder(dividingBy: 3600)) / 60)
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }
}

/// Day-by-day activity for charts
struct DailyActivity: Identifiable {
    let id = UUID()
    let date: Date
    let dayOfWeek: String
    let homeHours: Double
    let workHours: Double
    let travelHours: Double
    let otherHours: Double

    var totalHours: Double {
        homeHours + workHours + travelHours + otherHours
    }
}
