import Foundation
import CoreLocation
import Combine

/// Service for tracking and storing location history
@MainActor
class LocationHistoryService: ObservableObject {

    static let shared = LocationHistoryService()

    // MARK: - Published State

    @Published private(set) var todayPoints: [LocationHistoryPoint] = []
    @Published private(set) var currentVisit: LocationVisit?
    @Published private(set) var todayVisits: [LocationVisit] = []
    @Published private(set) var todaySummary: DailyLocationSummary?

    // MARK: - Configuration

    private let minimumDistanceForNewPoint: Double = 50  // meters
    private let stationaryThreshold: TimeInterval = 300   // 5 min = visit
    private let maxPointsPerDay: Int = 2000
    private let historyRetentionDays: Int = 30

    // MARK: - State

    private var lastRecordedLocation: CLLocation?
    private var lastMovementTime: Date?
    private var allHistory: [Date: [LocationHistoryPoint]] = [:]
    private var allVisits: [Date: [LocationVisit]] = [:]

    // MARK: - Storage Keys

    private let historyKeyPrefix = "location.history."
    private let visitsKeyPrefix = "location.visits."

    // MARK: - Initialization

    private init() {
        loadTodayData()
    }

    // MARK: - Public API

    /// Record a new location point
    func recordLocation(_ location: CLLocation, address: String? = nil, placeCategory: HistoryPlaceCategory? = nil) {
        // Check if we should record this point
        if let last = lastRecordedLocation {
            let distance = location.distance(from: last)
            if distance < minimumDistanceForNewPoint {
                // Too close, but check if we've been stationary
                checkForVisit(at: location)
                return
            }
        }

        // Create history point
        let point = LocationHistoryPoint(
            location: location,
            address: address,
            placeCategory: placeCategory
        )

        // Add to today's points
        todayPoints.append(point)
        if todayPoints.count > maxPointsPerDay {
            todayPoints.removeFirst()
        }

        // Update visit tracking
        if currentVisit != nil {
            // We were at a place, now we're moving
            endCurrentVisit(at: location)
        }

        lastRecordedLocation = location
        lastMovementTime = Date()

        // Periodic save
        if todayPoints.count % 50 == 0 {
            saveTodayData()
            updateTodaySummary()
        }
    }

    /// Get history for a specific date
    func getHistory(for date: Date) -> [LocationHistoryPoint] {
        let key = dateKey(for: date)

        if Calendar.current.isDateInToday(date) {
            return todayPoints
        }

        if let cached = allHistory[date] {
            return cached
        }

        // Load from storage
        if let data = UserDefaults.standard.data(forKey: historyKeyPrefix + key),
           let points = try? JSONDecoder().decode([LocationHistoryPoint].self, from: data) {
            allHistory[date] = points
            return points
        }

        return []
    }

    /// Get visits for a specific date
    func getVisits(for date: Date) -> [LocationVisit] {
        let key = dateKey(for: date)

        if Calendar.current.isDateInToday(date) {
            return todayVisits
        }

        if let cached = allVisits[date] {
            return cached
        }

        // Load from storage
        if let data = UserDefaults.standard.data(forKey: visitsKeyPrefix + key),
           let visits = try? JSONDecoder().decode([LocationVisit].self, from: data) {
            allVisits[date] = visits
            return visits
        }

        return []
    }

    /// Get history for a date range
    func getHistory(from startDate: Date, to endDate: Date) -> [LocationHistoryPoint] {
        var allPoints: [LocationHistoryPoint] = []

        var current = startDate
        while current <= endDate {
            allPoints.append(contentsOf: getHistory(for: current))
            current = Calendar.current.date(byAdding: .day, value: 1, to: current) ?? endDate
        }

        return allPoints.sorted { $0.timestamp < $1.timestamp }
    }

    /// Get daily summaries for past week
    func getWeekSummaries() -> [DailyLocationSummary] {
        var summaries: [DailyLocationSummary] = []

        for daysAgo in 0..<7 {
            guard let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date()) else {
                continue
            }

            let points = getHistory(for: date)
            let visits = getVisits(for: date)

            let summary = createSummary(for: date, points: points, visits: visits)
            summaries.append(summary)
        }

        return summaries
    }

    /// Clear history older than retention period
    func cleanupOldHistory() {
        let calendar = Calendar.current
        guard let cutoffDate = calendar.date(byAdding: .day, value: -historyRetentionDays, to: Date()) else {
            return
        }

        // Remove old data from UserDefaults
        let defaults = UserDefaults.standard
        let allKeys = defaults.dictionaryRepresentation().keys

        for key in allKeys {
            if key.hasPrefix(historyKeyPrefix) || key.hasPrefix(visitsKeyPrefix) {
                let dateString = key.replacingOccurrences(of: historyKeyPrefix, with: "")
                    .replacingOccurrences(of: visitsKeyPrefix, with: "")

                if let date = parseDate(dateString), date < cutoffDate {
                    defaults.removeObject(forKey: key)
                }
            }
        }
    }

    /// Export history as JSON
    func exportHistory(from startDate: Date, to endDate: Date) -> Data? {
        let points = getHistory(from: startDate, to: endDate)
        return try? JSONEncoder().encode(points)
    }

    // MARK: - Visit Tracking

    private func checkForVisit(at location: CLLocation) {
        guard let lastMove = lastMovementTime else {
            lastMovementTime = Date()
            return
        }

        let stationaryDuration = Date().timeIntervalSince(lastMove)

        if stationaryDuration >= stationaryThreshold && currentVisit == nil {
            // We've been stationary long enough, start a visit
            startVisit(at: location)
        }
    }

    private func startVisit(at location: CLLocation) {
        var visit = LocationVisit(location: location)

        // Try to identify the place
        // In production, would use reverse geocoding
        visit.placeCategory = .unknown

        currentVisit = visit
        todayVisits.append(visit)

        AppLogger.log("Started visit at \(location.coordinate)", level: .debug)
    }

    private func endCurrentVisit(at location: CLLocation) {
        guard var visit = currentVisit else { return }

        visit.departureTime = location.timestamp

        // Update in array
        if let index = todayVisits.firstIndex(where: { $0.id == visit.id }) {
            todayVisits[index] = visit
        }

        currentVisit = nil

        AppLogger.log("Ended visit after \(Int(visit.durationMinutes ?? 0)) minutes", level: .debug)
    }

    // MARK: - Summary

    private func createSummary(for date: Date, points: [LocationHistoryPoint], visits: [LocationVisit]) -> DailyLocationSummary {
        var totalDistance: Double = 0
        var totalTravelTime: Double = 0

        // Guard against empty or single-point arrays to avoid invalid range
        for i in points.indices.dropFirst() {
            let prev = points[i-1]
            let curr = points[i]

            let dist = prev.location.distance(from: curr.location)
            totalDistance += dist

            let time = curr.timestamp.timeIntervalSince(prev.timestamp)
            if time < 3600 {  // Don't count gaps > 1 hour
                totalTravelTime += time
            }
        }

        // Find most visited place
        var placeCounts: [String: Int] = [:]
        for visit in visits {
            let key = visit.placeName ?? visit.placeCategory.rawValue
            placeCounts[key, default: 0] += 1
        }
        let topPlace = placeCounts.max { $0.value < $1.value }?.key

        return DailyLocationSummary(
            id: UUID(),
            date: date,
            totalDistanceMiles: totalDistance / 1609.34,
            totalTravelMinutes: totalTravelTime / 60,
            placesVisited: visits.count,
            topPlace: topPlace,
            travelSegments: max(0, visits.count - 1)
        )
    }

    private func updateTodaySummary() {
        todaySummary = createSummary(for: Date(), points: todayPoints, visits: todayVisits)
    }

    // MARK: - Persistence

    private func loadTodayData() {
        let key = dateKey(for: Date())

        if let data = UserDefaults.standard.data(forKey: historyKeyPrefix + key),
           let points = try? JSONDecoder().decode([LocationHistoryPoint].self, from: data) {
            todayPoints = points
        }

        if let data = UserDefaults.standard.data(forKey: visitsKeyPrefix + key),
           let visits = try? JSONDecoder().decode([LocationVisit].self, from: data) {
            todayVisits = visits
        }

        updateTodaySummary()
    }

    private func saveTodayData() {
        let key = dateKey(for: Date())

        if let data = try? JSONEncoder().encode(todayPoints) {
            UserDefaults.standard.set(data, forKey: historyKeyPrefix + key)
        }

        if let data = try? JSONEncoder().encode(todayVisits) {
            UserDefaults.standard.set(data, forKey: visitsKeyPrefix + key)
        }
    }

    private func dateKey(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private func parseDate(_ string: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: string)
    }

    /// Save when app goes to background
    func saveOnBackground() {
        saveTodayData()
    }
}
