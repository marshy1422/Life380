import Foundation
import CoreLocation
import Combine
import SwiftUI

/// ViewModel for places management
@MainActor
class PlacesViewModel: ObservableObject {
    // MARK: - Published Properties

    @Published var places: [Place] = []
    @Published var selectedPlace: Place?

    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showError = false

    @Published var showAddPlace = false
    @Published var showEditPlace = false

    // MARK: - Add Place Form

    @Published var newPlaceName = ""
    @Published var newPlaceAddress = ""
    @Published var newPlaceIcon = "mappin"
    @Published var newPlaceColor = "#007AFF"
    @Published var newPlaceRadius: Double = 100
    @Published var newPlaceNotifications = true
    @Published var newPlaceCoordinate: CLLocationCoordinate2D?

    // MARK: - Dependencies

    private let firestoreService: FirestoreService
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    init(firestoreService: FirestoreService? = nil) {
        self.firestoreService = firestoreService ?? FirestoreService.shared
        setupBindings()
    }

    private func setupBindings() {
        // Listen to places from FirestoreService
        firestoreService.$places
            .receive(on: DispatchQueue.main)
            .assign(to: &$places)
    }

    // MARK: - Data Loading

    func loadPlaces(for circleId: String) {
        firestoreService.listenToPlaces(circleId: circleId)
    }

    // MARK: - Place CRUD

    func addPlace(to circleId: String) async -> Bool {
        guard validateNewPlace() else { return false }
        guard let coordinate = newPlaceCoordinate else {
            errorMessage = "Please select a location"
            showError = true
            return false
        }

        isLoading = true
        defer { isLoading = false }

        let place = Place(
            name: newPlaceName,
            address: newPlaceAddress,
            icon: newPlaceIcon,
            color: Color(hex: newPlaceColor) ?? .blue,
            notificationsEnabled: newPlaceNotifications,
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            radius: newPlaceRadius
        )

        do {
            try await firestoreService.addPlace(place, circleId: circleId)
            resetNewPlaceForm()
            return true
        } catch {
            errorMessage = error.localizedDescription
            showError = true
            return false
        }
    }

    func deletePlace(_ place: Place, from circleId: String) async -> Bool {
        isLoading = true
        defer { isLoading = false }

        do {
            try await firestoreService.deletePlace(placeId: place.id, circleId: circleId)
            return true
        } catch {
            errorMessage = error.localizedDescription
            showError = true
            return false
        }
    }

    // MARK: - Validation

    private func validateNewPlace() -> Bool {
        if newPlaceName.isEmpty {
            errorMessage = "Please enter a place name"
            showError = true
            return false
        }
        return true
    }

    // MARK: - Form Helpers

    func resetNewPlaceForm() {
        newPlaceName = ""
        newPlaceAddress = ""
        newPlaceIcon = "mappin"
        newPlaceColor = "#007AFF"
        newPlaceRadius = 100
        newPlaceNotifications = true
        newPlaceCoordinate = nil
    }

    func prepareEditForm(for place: Place) {
        newPlaceName = place.name
        newPlaceAddress = place.address
        newPlaceIcon = place.icon
        newPlaceColor = place.colorHex
        newPlaceRadius = place.radius
        newPlaceNotifications = place.notificationsEnabled
        newPlaceCoordinate = place.coordinate
        selectedPlace = place
    }

    // MARK: - Error Handling

    func clearError() {
        errorMessage = nil
        showError = false
    }
}

// MARK: - Place Icons

extension PlacesViewModel {
    static let availableIcons = [
        "house.fill",
        "building.2.fill",
        "graduationcap.fill",
        "cart.fill",
        "cross.fill",
        "sportscourt.fill",
        "cup.and.saucer.fill",
        "fork.knife",
        "car.fill",
        "airplane",
        "bus.fill",
        "tram.fill",
        "figure.walk",
        "pawprint.fill",
        "leaf.fill",
        "mappin"
    ]

    static let availableColors = [
        "#007AFF", // Blue
        "#34C759", // Green
        "#FF9500", // Orange
        "#FF3B30", // Red
        "#AF52DE", // Purple
        "#FF2D55", // Pink
        "#5856D6", // Indigo
        "#00C7BE"  // Teal
    ]
}
