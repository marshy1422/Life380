import Foundation
import CoreLocation
import Combine
import MapKit
import SwiftUI

/// ViewModel for the home/map screen
@MainActor
class HomeViewModel: ObservableObject {
    // MARK: - Published Properties

    @Published var selectedMember: UserProfile?
    @Published var members: [UserProfile] = []
    @Published var places: [Place] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    // Map region - nil until real location is available, avoiding hardcoded fallback coordinates
    @Published var mapRegion: MKCoordinateRegion?
    @Published var hasInitialLocation = false

    // MARK: - State

    var showMemberDetail: Bool {
        selectedMember != nil
    }

    // MARK: - Data Loading

    func loadInitialData() async {
        isLoading = true

        // Data loading will happen through the existing services
        // This ViewModel coordinates the UI state

        isLoading = false
    }

    func refreshMembers() async {
        // Refresh member locations from Firestore
    }

    func refreshPlaces() async {
        // Refresh places from Firestore
    }

    // MARK: - Member Selection

    func selectMember(_ member: UserProfile) {
        selectedMember = member

        // Center map on member if they have a valid location
        centerOnMember(member)
    }

    func clearSelection() {
        selectedMember = nil
    }

    // MARK: - Map Helpers

    func centerOnMember(_ member: UserProfile) {
        guard let coordinate = member.coordinate else { return }
        withAnimation {
            mapRegion = MKCoordinateRegion(
                center: coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            )
        }
    }

    func centerOnCurrentLocation(_ coordinate: CLLocationCoordinate2D) {
        withAnimation {
            mapRegion = MKCoordinateRegion(
                center: coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            )
        }
    }

    func fitAllMembers() {
        let validMembers = members.compactMap { $0.coordinate }
        guard !validMembers.isEmpty else { return }

        let minLat = validMembers.map { $0.latitude }.min() ?? 0
        let maxLat = validMembers.map { $0.latitude }.max() ?? 0
        let minLon = validMembers.map { $0.longitude }.min() ?? 0
        let maxLon = validMembers.map { $0.longitude }.max() ?? 0

        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )

        let span = MKCoordinateSpan(
            latitudeDelta: max((maxLat - minLat) * 1.5, 0.01),
            longitudeDelta: max((maxLon - minLon) * 1.5, 0.01)
        )

        withAnimation {
            mapRegion = MKCoordinateRegion(center: center, span: span)
        }
    }
}
