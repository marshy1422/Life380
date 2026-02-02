import Foundation
import CoreLocation
import Combine

/// Automatically learns user's frequently visited places using clustering algorithms
/// Identifies home, work, and other routine locations without manual setup
@MainActor
class AutoPlaceLearner: ObservableObject {

    // MARK: - Published State

    @Published private(set) var places: [LearnedPlace] = []
    @Published private(set) var isAtKnownPlace = false
    @Published private(set) var currentPlace: LearnedPlace?

    // MARK: - Configuration

    private let minStationaryDuration: TimeInterval = 15 * 60  // 15 minutes to consider "stationary"
    private let clusterRadius: Double = 100  // meters - locations within this are same place
    private let minVisitsForPlace: Int = 3   // Need 3+ visits to confirm a place
    private let proximityThreshold: Double = 150  // meters - "at" a place if within this

    // MARK: - Private State

    private var stationaryPeriods: [StationaryPeriod] = []
    private var currentStationaryStart: Date?
    private var lastLocation: LocationSample?
    private var movementThreshold: Double = 30  // meters - movement less than this = stationary

    private let userDefaults = UserDefaults.standard
    private let placesKey = "ai.learnedPlaces"
    private let periodsKey = "ai.stationaryPeriods"

    // MARK: - Initialization

    init() {
        loadPlaces()
        loadStationaryPeriods()
    }

    // MARK: - Public API

    /// Process a location sample to detect stationary periods
    func processSample(_ sample: LocationSample) async {
        defer { lastLocation = sample }

        // Check if still stationary
        if let last = lastLocation {
            let distance = calculateDistance(from: last.coordinate, to: sample.coordinate)

            if distance < movementThreshold {
                // Still stationary
                if currentStationaryStart == nil {
                    currentStationaryStart = last.timestamp
                }
            } else {
                // Started moving - end stationary period
                if let start = currentStationaryStart {
                    let duration = sample.timestamp.timeIntervalSince(start)

                    if duration >= minStationaryDuration {
                        // Valid stationary period - record it
                        let period = createStationaryPeriod(
                            start: start,
                            end: sample.timestamp,
                            location: last.coordinate
                        )
                        stationaryPeriods.append(period)

                        // Periodically run clustering
                        if stationaryPeriods.count % 5 == 0 {
                            await clusterPlaces()
                        }
                    }
                }
                currentStationaryStart = nil
            }
        }

        // Check if at a known place
        updateCurrentPlace(at: sample.coordinate)
    }

    /// Analyze historical data to find places
    func analyzeHistory(_ history: [LocationSample]) async {
        guard history.count > 10 else { return }

        // Find all stationary periods in history
        var periods: [StationaryPeriod] = []
        var stationaryStart: Date?
        var stationaryLocation: CLLocationCoordinate2D?

        for i in 1..<history.count {
            let prev = history[i-1]
            let curr = history[i]
            let distance = calculateDistance(from: prev.coordinate, to: curr.coordinate)

            if distance < movementThreshold {
                if stationaryStart == nil {
                    stationaryStart = prev.timestamp
                    stationaryLocation = prev.coordinate
                }
            } else {
                if let start = stationaryStart, let location = stationaryLocation {
                    let duration = curr.timestamp.timeIntervalSince(start)
                    if duration >= minStationaryDuration {
                        let period = createStationaryPeriod(
                            start: start,
                            end: curr.timestamp,
                            location: location
                        )
                        periods.append(period)
                    }
                }
                stationaryStart = nil
                stationaryLocation = nil
            }
        }

        stationaryPeriods = periods
        await clusterPlaces()
    }

    /// Find a known place near a coordinate
    func findPlace(near coordinate: CLLocationCoordinate2D) -> LearnedPlace? {
        return places.first { place in
            calculateDistance(from: place.coordinate, to: coordinate) < proximityThreshold
        }
    }

    /// Confirm a place with a user-provided name
    func confirmPlace(_ place: LearnedPlace, name: String) {
        guard let index = places.firstIndex(where: { $0.id == place.id }) else { return }

        var updated = places[index]
        updated.name = name
        updated.isConfirmed = true
        updated.confidence = min(1.0, updated.confidence + 0.2)

        places[index] = updated
        savePlaces()
    }

    /// Delete a place
    func deletePlace(_ place: LearnedPlace) {
        places.removeAll { $0.id == place.id }
        savePlaces()
    }

    /// Load places from storage
    func loadPlaces() {
        if let data = userDefaults.data(forKey: placesKey),
           let loaded = try? JSONDecoder().decode([LearnedPlace].self, from: data) {
            places = loaded
        }
    }

    /// Save places to storage
    func savePlaces() {
        if let data = try? JSONEncoder().encode(places) {
            userDefaults.set(data, forKey: placesKey)
        }
    }

    // MARK: - Private Methods

    private func loadStationaryPeriods() {
        if let data = userDefaults.data(forKey: periodsKey),
           let loaded = try? JSONDecoder().decode([StationaryPeriod].self, from: data) {
            stationaryPeriods = loaded
        }
    }

    private func saveStationaryPeriods() {
        // Keep last 500 periods
        let toSave = Array(stationaryPeriods.suffix(500))
        if let data = try? JSONEncoder().encode(toSave) {
            userDefaults.set(data, forKey: periodsKey)
        }
    }

    private func createStationaryPeriod(start: Date, end: Date, location: CLLocationCoordinate2D) -> StationaryPeriod {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: start)
        let dayOfWeek = calendar.component(.weekday, from: start)
        let isWeekend = dayOfWeek == 1 || dayOfWeek == 7

        return StationaryPeriod(
            id: UUID(),
            coordinate: location,
            startTime: start,
            endTime: end,
            hourOfDay: hour,
            dayOfWeek: dayOfWeek,
            isWeekend: isWeekend
        )
    }

    /// DBSCAN-inspired clustering to find places
    private func clusterPlaces() async {
        guard stationaryPeriods.count >= minVisitsForPlace else { return }

        var clusters: [[StationaryPeriod]] = []
        var visited = Set<UUID>()

        for period in stationaryPeriods {
            guard !visited.contains(period.id) else { continue }

            // Find all periods near this one
            var cluster = [period]
            visited.insert(period.id)

            for other in stationaryPeriods where !visited.contains(other.id) {
                let distance = calculateDistance(from: period.coordinate, to: other.coordinate)
                if distance < clusterRadius {
                    cluster.append(other)
                    visited.insert(other.id)
                }
            }

            if cluster.count >= minVisitsForPlace {
                clusters.append(cluster)
            }
        }

        // Convert clusters to learned places
        var newPlaces: [LearnedPlace] = []

        for cluster in clusters {
            let place = createPlaceFromCluster(cluster)

            // Check if this matches an existing confirmed place
            if let existing = places.first(where: {
                $0.isConfirmed && calculateDistance(from: $0.coordinate, to: place.coordinate) < clusterRadius
            }) {
                // Update existing place with new data
                var updated = existing
                updated.visitCount = cluster.count
                updated.lastVisit = cluster.map { $0.endTime }.max() ?? Date()
                updated.typicalSchedule = analyzeSchedule(cluster)
                updated.confidence = min(1.0, Double(cluster.count) / 10.0)
                newPlaces.append(updated)
            } else {
                newPlaces.append(place)
            }
        }

        // Merge with existing confirmed places not in new data
        for existing in places where existing.isConfirmed {
            if !newPlaces.contains(where: {
                calculateDistance(from: $0.coordinate, to: existing.coordinate) < clusterRadius
            }) {
                newPlaces.append(existing)
            }
        }

        places = newPlaces.sorted { $0.visitCount > $1.visitCount }
        savePlaces()
        saveStationaryPeriods()
    }

    private func createPlaceFromCluster(_ cluster: [StationaryPeriod]) -> LearnedPlace {
        // Calculate centroid
        let avgLat = cluster.map { $0.coordinate.latitude }.reduce(0, +) / Double(cluster.count)
        let avgLon = cluster.map { $0.coordinate.longitude }.reduce(0, +) / Double(cluster.count)

        let coordinate = CLLocationCoordinate2D(latitude: avgLat, longitude: avgLon)
        let schedule = analyzeSchedule(cluster)
        let placeType = inferPlaceType(schedule: schedule, cluster: cluster)

        return LearnedPlace(
            id: UUID(),
            coordinate: coordinate,
            name: nil,
            inferredType: placeType,
            visitCount: cluster.count,
            firstVisit: cluster.map { $0.startTime }.min() ?? Date(),
            lastVisit: cluster.map { $0.endTime }.max() ?? Date(),
            typicalSchedule: schedule,
            averageStayDuration: cluster.map { $0.duration }.reduce(0, +) / Double(cluster.count),
            confidence: min(1.0, Double(cluster.count) / 10.0),
            isConfirmed: false
        )
    }

    private func analyzeSchedule(_ periods: [StationaryPeriod]) -> PlaceSchedule {
        let weekdayHours = periods.filter { !$0.isWeekend }.map { $0.hourOfDay }
        let weekendHours = periods.filter { $0.isWeekend }.map { $0.hourOfDay }

        let weekdayVisits = periods.filter { !$0.isWeekend }.count
        let weekendVisits = periods.filter { $0.isWeekend }.count

        // Find most common arrival hour
        let arrivalHour = mostCommon(weekdayHours) ?? mostCommon(weekendHours) ?? 12

        // Check for overnight stays
        let hasOvernightStays = periods.contains { period in
            let startHour = Calendar.current.component(.hour, from: period.startTime)
            let endHour = Calendar.current.component(.hour, from: period.endTime)
            return (startHour >= 20 || startHour <= 6) && (endHour >= 20 || endHour <= 8)
        }

        return PlaceSchedule(
            typicalArrivalHour: arrivalHour,
            weekdayVisits: weekdayVisits,
            weekendVisits: weekendVisits,
            hasOvernightStays: hasOvernightStays,
            mostCommonDays: findMostCommonDays(periods)
        )
    }

    private func inferPlaceType(schedule: PlaceSchedule, cluster: [StationaryPeriod]) -> PlaceType {
        // Home: overnight stays, every day
        if schedule.hasOvernightStays && schedule.weekdayVisits >= 5 {
            return .home
        }

        // Work: weekday visits during business hours
        let businessHourVisits = cluster.filter {
            !$0.isWeekend && $0.hourOfDay >= 8 && $0.hourOfDay <= 18
        }
        if businessHourVisits.count >= 5 && schedule.weekendVisits < schedule.weekdayVisits / 2 {
            return .work
        }

        // School: similar to work but different time detection could be added
        if schedule.weekdayVisits >= 5 && cluster.first(where: { $0.hourOfDay >= 7 && $0.hourOfDay <= 15 }) != nil {
            // Could be school - but we'll call it work for now
            return .work
        }

        // Gym: short visits, consistent times
        let avgDuration = cluster.map { $0.duration }.reduce(0, +) / Double(cluster.count)
        if avgDuration < 2 * 60 * 60 && avgDuration > 30 * 60 {  // 30min - 2hr
            return .gym
        }

        // Frequent: visited often but doesn't fit other patterns
        if cluster.count >= 5 {
            return .frequent
        }

        return .other
    }

    private func mostCommon(_ array: [Int]) -> Int? {
        guard !array.isEmpty else { return nil }
        var counts: [Int: Int] = [:]
        for item in array {
            counts[item, default: 0] += 1
        }
        return counts.max(by: { $0.value < $1.value })?.key
    }

    private func findMostCommonDays(_ periods: [StationaryPeriod]) -> [Int] {
        var dayCounts: [Int: Int] = [:]
        for period in periods {
            dayCounts[period.dayOfWeek, default: 0] += 1
        }
        return dayCounts.sorted { $0.value > $1.value }.prefix(3).map { $0.key }
    }

    private func updateCurrentPlace(at coordinate: CLLocationCoordinate2D) {
        if let place = findPlace(near: coordinate) {
            currentPlace = place
            isAtKnownPlace = true
        } else {
            currentPlace = nil
            isAtKnownPlace = false
        }
    }

    private func calculateDistance(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
        let loc1 = CLLocation(latitude: from.latitude, longitude: from.longitude)
        let loc2 = CLLocation(latitude: to.latitude, longitude: to.longitude)
        return loc1.distance(from: loc2)
    }
}

// MARK: - Supporting Types

struct StationaryPeriod: Codable, Identifiable {
    let id: UUID
    let coordinate: CLLocationCoordinate2D
    let startTime: Date
    let endTime: Date
    let hourOfDay: Int
    let dayOfWeek: Int
    let isWeekend: Bool

    var duration: TimeInterval {
        endTime.timeIntervalSince(startTime)
    }

    enum CodingKeys: String, CodingKey {
        case id, latitude, longitude, startTime, endTime, hourOfDay, dayOfWeek, isWeekend
    }

    init(id: UUID, coordinate: CLLocationCoordinate2D, startTime: Date, endTime: Date,
         hourOfDay: Int, dayOfWeek: Int, isWeekend: Bool) {
        self.id = id
        self.coordinate = coordinate
        self.startTime = startTime
        self.endTime = endTime
        self.hourOfDay = hourOfDay
        self.dayOfWeek = dayOfWeek
        self.isWeekend = isWeekend
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        let lat = try container.decode(Double.self, forKey: .latitude)
        let lon = try container.decode(Double.self, forKey: .longitude)
        coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
        startTime = try container.decode(Date.self, forKey: .startTime)
        endTime = try container.decode(Date.self, forKey: .endTime)
        hourOfDay = try container.decode(Int.self, forKey: .hourOfDay)
        dayOfWeek = try container.decode(Int.self, forKey: .dayOfWeek)
        isWeekend = try container.decode(Bool.self, forKey: .isWeekend)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(coordinate.latitude, forKey: .latitude)
        try container.encode(coordinate.longitude, forKey: .longitude)
        try container.encode(startTime, forKey: .startTime)
        try container.encode(endTime, forKey: .endTime)
        try container.encode(hourOfDay, forKey: .hourOfDay)
        try container.encode(dayOfWeek, forKey: .dayOfWeek)
        try container.encode(isWeekend, forKey: .isWeekend)
    }
}

struct LearnedPlace: Codable, Identifiable {
    let id: UUID
    let coordinate: CLLocationCoordinate2D
    var name: String?
    var inferredType: PlaceType
    var visitCount: Int
    var firstVisit: Date
    var lastVisit: Date
    var typicalSchedule: PlaceSchedule
    var averageStayDuration: TimeInterval
    var confidence: Double  // 0-1
    var isConfirmed: Bool

    var displayName: String {
        if let name = name {
            return name
        }
        return inferredType.suggestedName
    }

    enum CodingKeys: String, CodingKey {
        case id, latitude, longitude, name, inferredType, visitCount
        case firstVisit, lastVisit, typicalSchedule, averageStayDuration
        case confidence, isConfirmed
    }

    init(id: UUID, coordinate: CLLocationCoordinate2D, name: String?, inferredType: PlaceType,
         visitCount: Int, firstVisit: Date, lastVisit: Date, typicalSchedule: PlaceSchedule,
         averageStayDuration: TimeInterval, confidence: Double, isConfirmed: Bool) {
        self.id = id
        self.coordinate = coordinate
        self.name = name
        self.inferredType = inferredType
        self.visitCount = visitCount
        self.firstVisit = firstVisit
        self.lastVisit = lastVisit
        self.typicalSchedule = typicalSchedule
        self.averageStayDuration = averageStayDuration
        self.confidence = confidence
        self.isConfirmed = isConfirmed
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        let lat = try container.decode(Double.self, forKey: .latitude)
        let lon = try container.decode(Double.self, forKey: .longitude)
        coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
        name = try container.decodeIfPresent(String.self, forKey: .name)
        inferredType = try container.decode(PlaceType.self, forKey: .inferredType)
        visitCount = try container.decode(Int.self, forKey: .visitCount)
        firstVisit = try container.decode(Date.self, forKey: .firstVisit)
        lastVisit = try container.decode(Date.self, forKey: .lastVisit)
        typicalSchedule = try container.decode(PlaceSchedule.self, forKey: .typicalSchedule)
        averageStayDuration = try container.decode(TimeInterval.self, forKey: .averageStayDuration)
        confidence = try container.decode(Double.self, forKey: .confidence)
        isConfirmed = try container.decode(Bool.self, forKey: .isConfirmed)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(coordinate.latitude, forKey: .latitude)
        try container.encode(coordinate.longitude, forKey: .longitude)
        try container.encodeIfPresent(name, forKey: .name)
        try container.encode(inferredType, forKey: .inferredType)
        try container.encode(visitCount, forKey: .visitCount)
        try container.encode(firstVisit, forKey: .firstVisit)
        try container.encode(lastVisit, forKey: .lastVisit)
        try container.encode(typicalSchedule, forKey: .typicalSchedule)
        try container.encode(averageStayDuration, forKey: .averageStayDuration)
        try container.encode(confidence, forKey: .confidence)
        try container.encode(isConfirmed, forKey: .isConfirmed)
    }
}

enum PlaceType: String, Codable {
    case home
    case work
    case school
    case gym
    case frequent
    case other

    var suggestedName: String {
        switch self {
        case .home: return "Home"
        case .work: return "Work"
        case .school: return "School"
        case .gym: return "Gym"
        case .frequent: return "Frequent Place"
        case .other: return "Place"
        }
    }

    var icon: String {
        switch self {
        case .home: return "house.fill"
        case .work: return "briefcase.fill"
        case .school: return "graduationcap.fill"
        case .gym: return "figure.run"
        case .frequent: return "star.fill"
        case .other: return "mappin"
        }
    }
}

struct PlaceSchedule: Codable {
    var typicalArrivalHour: Int
    var weekdayVisits: Int
    var weekendVisits: Int
    var hasOvernightStays: Bool
    var mostCommonDays: [Int]  // 1=Sunday, 7=Saturday

    var isWeekdayPlace: Bool {
        weekdayVisits > weekendVisits * 2
    }

    var isWeekendPlace: Bool {
        weekendVisits > weekdayVisits * 2
    }
}
