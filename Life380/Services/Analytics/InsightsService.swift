import Foundation
import CoreLocation
import FirebaseFirestore
import FirebaseAuth
import os.log

private let logger = Logger(subsystem: "com.life380.app", category: "Insights")

/// Service for collecting, aggregating, and managing location insights
@MainActor
class InsightsService: ObservableObject {
    static let shared = InsightsService()

    private let db = Firestore.firestore()

    // MARK: - Published State

    @Published var isTrackingEnabled: Bool = false
    @Published var currentDwellRecord: DwellTimeRecord?
    @Published var todaysSummary: DailyDwellSummary?
    @Published var weeklySummary: WeeklySummary?
    @Published var commuteStats: [CommuteStats] = []
    @Published var recentTravelRecords: [TravelRecord] = []
    @Published var weeklyActivities: [DailyActivity] = []

    // MARK: - Local Storage

    private var localEvents: [LocationEvent] = []
    private var activeDwellRecords: [String: DwellTimeRecord] = [:] // placeId -> record
    private var travelStartTime: Date?
    private var travelStartLocation: CLLocationCoordinate2D?
    private var lastKnownPlaceId: String?

    // MARK: - Configuration

    private let maxLocalEvents = 1000
    private let aggregationInterval: TimeInterval = 3600 // 1 hour
    private var lastAggregationTime: Date?

    private init() {
        loadTrackingPreference()
        // Defer Firestore access to ensure Firebase is configured first
        // This runs after the app's init() completes
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            Task {
                await self?.loadTodaysSummary()
                await self?.loadRecentTravelRecords()
                await self?.loadCommuteStats()
            }
        }
    }

    // MARK: - Tracking Control

    func enableTracking() {
        isTrackingEnabled = true
        UserDefaults.standard.set(true, forKey: "insightsTrackingEnabled")
        logger.info("Insights tracking enabled")
    }

    func disableTracking() {
        isTrackingEnabled = false
        UserDefaults.standard.set(false, forKey: "insightsTrackingEnabled")
        logger.info("Insights tracking disabled")
    }

    private func loadTrackingPreference() {
        isTrackingEnabled = UserDefaults.standard.bool(forKey: "insightsTrackingEnabled")
    }

    // MARK: - Event Recording

    /// Record when user enters a place (geofence entry)
    func recordPlaceEntry(placeId: String, placeName: String, coordinate: CLLocationCoordinate2D) {
        guard isTrackingEnabled else { return }

        // End any active travel
        if travelStartTime != nil {
            endTravel(toPlaceId: placeId, toPlaceName: placeName, coordinate: coordinate)
        }

        // Create dwell record
        let record = DwellTimeRecord(
            placeId: placeId,
            placeName: placeName,
            entryTime: Date()
        )
        activeDwellRecords[placeId] = record
        currentDwellRecord = record

        // Log event
        let event = LocationEvent(
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            placeId: placeId,
            placeName: placeName,
            eventType: .entry
        )
        addLocalEvent(event)

        lastKnownPlaceId = placeId

        logger.info("📍 Entered \(placeName)")
    }

    /// Record when user exits a place (geofence exit)
    func recordPlaceExit(placeId: String, placeName: String, coordinate: CLLocationCoordinate2D) {
        guard isTrackingEnabled else { return }

        // Complete dwell record
        if var record = activeDwellRecords[placeId] {
            record = DwellTimeRecord(
                id: record.id,
                placeId: record.placeId,
                placeName: record.placeName,
                date: record.date,
                entryTime: record.entryTime,
                exitTime: Date()
            )

            // Add to today's summary
            updateDailySummary(with: record)

            activeDwellRecords.removeValue(forKey: placeId)
            if currentDwellRecord?.placeId == placeId {
                currentDwellRecord = nil
            }
        }

        // Start tracking travel
        startTravel(fromPlaceId: placeId, fromPlaceName: placeName, coordinate: coordinate)

        // Log event
        let event = LocationEvent(
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            placeId: placeId,
            placeName: placeName,
            eventType: .exit
        )
        addLocalEvent(event)

        logger.info("📍 Left \(placeName)")
    }

    // MARK: - Travel Tracking

    private func startTravel(fromPlaceId: String, fromPlaceName: String, coordinate: CLLocationCoordinate2D) {
        travelStartTime = Date()
        travelStartLocation = coordinate
        lastKnownPlaceId = fromPlaceId

        logger.debug("🚗 Started travel from \(fromPlaceName)")
    }

    private func endTravel(toPlaceId: String, toPlaceName: String, coordinate: CLLocationCoordinate2D) {
        guard let startTime = travelStartTime,
              let startLocation = travelStartLocation else { return }

        let endTime = Date()
        let duration = endTime.timeIntervalSince(startTime)

        // Only record if travel was significant (> 2 minutes)
        guard duration > 120 else {
            travelStartTime = nil
            travelStartLocation = nil
            return
        }

        let distance = CLLocation(latitude: startLocation.latitude, longitude: startLocation.longitude)
            .distance(from: CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude))

        let averageSpeed = distance / duration

        // Get from place info
        let fromPlaceId = lastKnownPlaceId
        let fromPlaceName = activeDwellRecords.values.first { $0.placeId == fromPlaceId }?.placeName

        guard let userId = Auth.auth().currentUser?.uid else { return }

        let record = TravelRecord(
            userId: userId,
            fromPlaceId: fromPlaceId,
            fromPlaceName: fromPlaceName,
            toPlaceId: toPlaceId,
            toPlaceName: toPlaceName,
            startTime: startTime,
            endTime: endTime,
            distance: distance,
            averageSpeed: averageSpeed
        )

        recentTravelRecords.insert(record, at: 0)
        if recentTravelRecords.count > 50 {
            recentTravelRecords.removeLast()
        }

        // Update commute stats if both places are known
        if let fromId = fromPlaceId {
            updateCommuteStats(from: fromId, fromName: fromPlaceName ?? "Unknown",
                             to: toPlaceId, toName: toPlaceName,
                             duration: duration, distance: distance)
        }

        travelStartTime = nil
        travelStartLocation = nil

        logger.info("🚗 Completed travel: \(Int(duration/60)) min, \(String(format: "%.1f", distance/1000)) km")
    }

    // MARK: - Aggregation

    private func addLocalEvent(_ event: LocationEvent) {
        localEvents.append(event)

        // Trim if too many events
        if localEvents.count > maxLocalEvents {
            localEvents.removeFirst(localEvents.count - maxLocalEvents)
        }

        // Check if we should aggregate
        if shouldAggregate() {
            Task {
                await aggregateAndUpload()
            }
        }
    }

    private func shouldAggregate() -> Bool {
        guard let lastTime = lastAggregationTime else {
            return localEvents.count >= 10
        }
        return Date().timeIntervalSince(lastTime) >= aggregationInterval
    }

    private func updateDailySummary(with record: DwellTimeRecord) {
        guard let userId = Auth.auth().currentUser?.uid else { return }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        if todaysSummary == nil || !calendar.isDate(todaysSummary?.date ?? Date.distantPast, inSameDayAs: today) {
            todaysSummary = DailyDwellSummary(userId: userId, date: today)
        }

        guard var summary = todaysSummary else { return }
        let currentDuration = summary.placeDurations[record.placeId] ?? 0
        summary.placeDurations[record.placeId] = currentDuration + record.duration
        summary.placeNames[record.placeId] = record.placeName
        todaysSummary = summary
    }

    private func updateCommuteStats(from fromId: String, fromName: String,
                                    to toId: String, toName: String,
                                    duration: TimeInterval, distance: Double) {
        let routeId = "\(fromId)_\(toId)"

        if let index = commuteStats.firstIndex(where: { $0.id == routeId }) {
            commuteStats[index].addTrip(duration: duration, distance: distance)
        } else {
            var newStats = CommuteStats(
                id: routeId,
                fromPlaceId: fromId,
                fromPlaceName: fromName,
                toPlaceId: toId,
                toPlaceName: toName
            )
            newStats.addTrip(duration: duration, distance: distance)
            commuteStats.append(newStats)
        }
    }

    // MARK: - Cloud Sync

    func aggregateAndUpload() async {
        guard let userId = Auth.auth().currentUser?.uid,
              let circleId = FirestoreService.shared.currentCircleId,
              let summary = todaysSummary else { return }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: summary.date)

        do {
            // Upload daily summary
            try await db.collection("circles")
                .document(circleId)
                .collection("insights")
                .document(userId)
                .collection("dailySummaries")
                .document(dateString)
                .setData(summary.dictionary, merge: true)

            // Upload travel records for today
            await uploadTravelRecords(circleId: circleId, userId: userId)

            // Upload commute stats
            await uploadCommuteStats(circleId: circleId, userId: userId)

            lastAggregationTime = Date()
            logger.info("📊 Uploaded daily summary, travel records, and commute stats")
        } catch {
            logger.error("Failed to upload insights: \(error.localizedDescription)")
        }
    }

    private func uploadTravelRecords(circleId: String, userId: String) async {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // Only upload today's travel records
        let todaysRecords = recentTravelRecords.filter { calendar.isDate($0.startTime, inSameDayAs: today) }

        for record in todaysRecords {
            do {
                try await db.collection("circles")
                    .document(circleId)
                    .collection("insights")
                    .document(userId)
                    .collection("travelRecords")
                    .document(record.id)
                    .setData(record.dictionary)
            } catch {
                logger.error("Failed to upload travel record: \(error.localizedDescription)")
            }
        }
    }

    private func uploadCommuteStats(circleId: String, userId: String) async {
        for stats in commuteStats {
            do {
                try await db.collection("circles")
                    .document(circleId)
                    .collection("insights")
                    .document(userId)
                    .collection("commuteStats")
                    .document(stats.id)
                    .setData(stats.dictionary, merge: true)
            } catch {
                logger.error("Failed to upload commute stats: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Load from Firestore

    private func loadTodaysSummary() async {
        guard let userId = Auth.auth().currentUser?.uid,
              let circleId = FirestoreService.shared.currentCircleId else { return }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let todayString = dateFormatter.string(from: Date())

        do {
            let doc = try await db.collection("circles")
                .document(circleId)
                .collection("insights")
                .document(userId)
                .collection("dailySummaries")
                .document(todayString)
                .getDocument()

            if let data = doc.data(),
               let date = (data["date"] as? Timestamp)?.dateValue(),
               let placeDurations = data["placeDurations"] as? [String: Double] {
                let placeNames = data["placeNames"] as? [String: String] ?? [:]

                todaysSummary = DailyDwellSummary(
                    userId: userId,
                    date: date,
                    placeDurations: placeDurations,
                    placeNames: placeNames
                )
                logger.info("📊 Loaded today's summary from Firestore")
            }
        } catch {
            logger.error("Failed to load today's summary: \(error.localizedDescription)")
        }
    }

    private func loadRecentTravelRecords() async {
        guard let userId = Auth.auth().currentUser?.uid,
              let circleId = FirestoreService.shared.currentCircleId else { return }

        let calendar = Calendar.current
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: Date())!

        do {
            let snapshot = try await db.collection("circles")
                .document(circleId)
                .collection("insights")
                .document(userId)
                .collection("travelRecords")
                .whereField("startTime", isGreaterThan: Timestamp(date: weekAgo))
                .order(by: "startTime", descending: true)
                .limit(to: 50)
                .getDocuments()

            var records: [TravelRecord] = []
            for doc in snapshot.documents {
                if let record = TravelRecord(dictionary: doc.data()) {
                    records.append(record)
                }
            }
            recentTravelRecords = records
            logger.info("📊 Loaded \(records.count) travel records from Firestore")
        } catch {
            logger.error("Failed to load travel records: \(error.localizedDescription)")
        }
    }

    private func loadCommuteStats() async {
        guard let userId = Auth.auth().currentUser?.uid,
              let circleId = FirestoreService.shared.currentCircleId else { return }

        do {
            let snapshot = try await db.collection("circles")
                .document(circleId)
                .collection("insights")
                .document(userId)
                .collection("commuteStats")
                .getDocuments()

            var stats: [CommuteStats] = []
            for doc in snapshot.documents {
                if let stat = CommuteStats(dictionary: doc.data()) {
                    stats.append(stat)
                }
            }
            commuteStats = stats
            logger.info("📊 Loaded \(stats.count) commute stats from Firestore")
        } catch {
            logger.error("Failed to load commute stats: \(error.localizedDescription)")
        }
    }

    // MARK: - Data Retrieval

    enum TimeRange: CustomStringConvertible {
        case today
        case week
        case month

        var description: String {
            switch self {
            case .today: return "today"
            case .week: return "week"
            case .month: return "month"
            }
        }
    }

    /// Load insights for a user (self or circle member)
    func loadInsights(for userId: String, timeRange: TimeRange = .week) async {
        guard let circleId = FirestoreService.shared.currentCircleId else { return }

        let calendar = Calendar.current
        let now = Date()

        // Determine date range based on selection
        let startDate: Date
        switch timeRange {
        case .today:
            startDate = calendar.startOfDay(for: now)
        case .week:
            startDate = calendar.date(byAdding: .day, value: -7, to: now)!
        case .month:
            startDate = calendar.date(byAdding: .day, value: -30, to: now)!
        }

        do {
            // Load daily summaries
            let summarySnapshot = try await db.collection("circles")
                .document(circleId)
                .collection("insights")
                .document(userId)
                .collection("dailySummaries")
                .whereField("date", isGreaterThan: Timestamp(date: startDate))
                .order(by: "date", descending: true)
                .getDocuments()

            // Load travel records for the same period
            let travelSnapshot = try await db.collection("circles")
                .document(circleId)
                .collection("insights")
                .document(userId)
                .collection("travelRecords")
                .whereField("startTime", isGreaterThan: Timestamp(date: startDate))
                .order(by: "startTime", descending: true)
                .getDocuments()

            // Group travel records by date
            var travelByDate: [String: [TravelRecord]] = [:]
            let dateFmt = DateFormatter()
            dateFmt.dateFormat = "yyyy-MM-dd"

            for doc in travelSnapshot.documents {
                if let record = TravelRecord(dictionary: doc.data()) {
                    let dateKey = dateFmt.string(from: record.startTime)
                    travelByDate[dateKey, default: []].append(record)
                }
            }

            var activities: [DailyActivity] = []
            let dayFormatter = DateFormatter()
            dayFormatter.dateFormat = "EEE"

            for doc in summarySnapshot.documents {
                let data = doc.data()
                guard let date = (data["date"] as? Timestamp)?.dateValue(),
                      let placeDurations = data["placeDurations"] as? [String: Double] else { continue }

                let placeNames = data["placeNames"] as? [String: String] ?? [:]
                let dateKey = dateFmt.string(from: date)

                var homeHours: Double = 0
                var workHours: Double = 0
                var otherHours: Double = 0

                for (placeId, duration) in placeDurations {
                    let name = placeNames[placeId]?.lowercased() ?? ""
                    let hours = duration / 3600

                    if name.contains("home") {
                        homeHours += hours
                    } else if name.contains("work") || name.contains("office") {
                        workHours += hours
                    } else {
                        otherHours += hours
                    }
                }

                // Calculate travel hours from travel records for this date
                let dayTravelRecords = travelByDate[dateKey] ?? []
                let travelHours = dayTravelRecords.reduce(0.0) { $0 + $1.duration } / 3600

                let activity = DailyActivity(
                    date: date,
                    dayOfWeek: dayFormatter.string(from: date),
                    homeHours: homeHours,
                    workHours: workHours,
                    travelHours: travelHours,
                    otherHours: otherHours
                )
                activities.append(activity)
            }

            weeklyActivities = activities.sorted { $0.date < $1.date }
            logger.info("📊 Loaded \(activities.count) days of insights for \(timeRange)")

        } catch {
            logger.error("Failed to load insights: \(error.localizedDescription)")
        }
    }

    /// Generate weekly summary from daily data
    func generateWeeklySummary() async -> WeeklySummary? {
        guard let userId = Auth.auth().currentUser?.uid else { return nil }

        let calendar = Calendar.current
        let today = Date()
        let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today))!
        let weekEnd = calendar.date(byAdding: .day, value: 6, to: weekStart)!

        var summary = WeeklySummary(userId: userId, weekStartDate: weekStart, weekEndDate: weekEnd)

        // Aggregate from weekly activities
        for activity in weeklyActivities {
            guard activity.date >= weekStart && activity.date <= weekEnd else { continue }

            summary.totalHomeTime += activity.homeHours * 3600
            summary.totalWorkTime += activity.workHours * 3600
            summary.totalOtherPlacesTime += activity.otherHours * 3600
            summary.totalTravelTime += activity.travelHours * 3600
        }

        // Find patterns
        if summary.totalHomeTime > summary.totalWorkTime {
            summary.mostVisitedPlace = "Home"
        } else if summary.totalWorkTime > 0 {
            summary.mostVisitedPlace = "Work"
        }

        // Travel stats from commute data
        summary.tripCount = recentTravelRecords.count
        if !recentTravelRecords.isEmpty {
            summary.totalDistance = recentTravelRecords.reduce(0) { $0 + $1.distance }
            let totalTravelDuration = recentTravelRecords.reduce(0.0) { $0 + $1.duration }
            summary.averageCommuteTime = totalTravelDuration / Double(recentTravelRecords.count)
        }

        weeklySummary = summary
        return summary
    }

    // MARK: - Display Helpers

    /// Get dwell time slices for pie chart
    func getDwellTimeSlices() -> [DwellTimeSlice] {
        guard let summary = todaysSummary else { return [] }

        let placeColors = [
            "home": ("#4CAF50", "house.fill"),
            "work": ("#2196F3", "building.2.fill"),
            "school": ("#FF9800", "book.fill"),
            "gym": ("#9C27B0", "figure.run"),
            "default": ("#607D8B", "mappin.circle.fill")
        ]

        var slices: [DwellTimeSlice] = []
        let total = summary.totalTrackedTime

        for (placeId, duration) in summary.placeDurations {
            let name = summary.placeNames[placeId] ?? "Unknown"
            let nameLower = name.lowercased()

            var colorInfo = placeColors["default"]!
            for (key, info) in placeColors {
                if nameLower.contains(key) {
                    colorInfo = info
                    break
                }
            }

            var slice = DwellTimeSlice(
                placeName: name,
                placeId: placeId,
                duration: duration,
                color: colorInfo.0,
                icon: colorInfo.1
            )
            slice.percentage = total > 0 ? (duration / total) * 100 : 0
            slices.append(slice)
        }

        return slices.sorted { $0.duration > $1.duration }
    }

    // MARK: - Data Management

    func clearLocalData() {
        localEvents.removeAll()
        activeDwellRecords.removeAll()
        recentTravelRecords.removeAll()
        todaysSummary = nil
        weeklySummary = nil
        logger.info("Cleared local insights data")
    }

    func deleteAllInsightsData() async {
        guard let userId = Auth.auth().currentUser?.uid,
              let circleId = FirestoreService.shared.currentCircleId else { return }

        clearLocalData()

        // Delete from Firestore
        do {
            let insightsRef = db.collection("circles")
                .document(circleId)
                .collection("insights")
                .document(userId)

            // Delete subcollections
            let dailyDocs = try await insightsRef.collection("dailySummaries").getDocuments()
            for doc in dailyDocs.documents {
                try await doc.reference.delete()
            }

            let weeklyDocs = try await insightsRef.collection("weeklyReports").getDocuments()
            for doc in weeklyDocs.documents {
                try await doc.reference.delete()
            }

            logger.info("Deleted all insights data from cloud")
        } catch {
            logger.error("Failed to delete insights: \(error.localizedDescription)")
        }
    }

    // MARK: - App Lifecycle

    /// Save data when app goes to background
    func saveOnBackground() async {
        guard isTrackingEnabled else { return }

        logger.info("📊 Saving insights data on background...")

        // Force aggregate and upload any pending data
        await aggregateAndUpload()

        // Save current summary to local storage as backup
        if let summary = todaysSummary,
           let data = try? JSONEncoder().encode(summary) {
            UserDefaults.standard.set(data, forKey: "insights.todaysSummary")
        }

        logger.info("📊 Insights data saved")
    }
}
