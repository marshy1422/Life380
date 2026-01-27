import Foundation
import FirebaseFirestore
import FirebaseAuth
import CoreLocation
import Combine

@MainActor
class FirestoreService: ObservableObject {
    static let shared = FirestoreService()

    private let db = Firestore.firestore()
    private var listeners: [ListenerRegistration] = []

    // Separate tracking for member-specific and circle-specific listeners to prevent leaks
    private var memberListeners: [String: ListenerRegistration] = [:]
    private var circleMemberListener: ListenerRegistration?
    private var placesListener: ListenerRegistration?
    private var circlesListener: ListenerRegistration?
    private var userProfileListener: ListenerRegistration?

    @Published var currentUserProfile: UserProfile?
    @Published var circleMembers: [UserProfile] = []
    @Published var circles: [FamilyCircle] = []
    @Published var places: [Place] = []
    @Published var currentCircleId: String?
    @Published var errorMessage: String?

    private init() {}

    // MARK: - User Profile

    func createUserProfile(userId: String, email: String, displayName: String) async throws {
        let profile = UserProfile(
            id: userId,
            email: email,
            displayName: displayName,
            photoURL: nil,
            latitude: 0,
            longitude: 0,
            lastUpdated: Date(),
            batteryLevel: 100,
            isLocationSharing: true
        )

        try await db.collection("users").document(userId).setData(profile.dictionary)
    }

    func userProfileExists(userId: String) async throws -> Bool {
        let doc = try await db.collection("users").document(userId).getDocument()
        return doc.exists
    }

    func updateUserLocation(latitude: Double, longitude: Double, batteryLevel: Int, accuracy: Double? = nil, floor: Int? = nil) async {
        guard let userId = Auth.auth().currentUser?.uid else { return }

        var updateData: [String: Any] = [
            "latitude": latitude,
            "longitude": longitude,
            "lastUpdated": FieldValue.serverTimestamp(),
            "batteryLevel": batteryLevel
        ]

        // Include accuracy if available (for precision tracking)
        if let accuracy = accuracy {
            updateData["horizontalAccuracy"] = accuracy
        }

        // Include floor level if available (from barometer)
        if let floor = floor {
            updateData["floor"] = floor
        }

        do {
            try await db.collection("users").document(userId).updateData(updateData)
        } catch {
            print("Error updating location: \(error)")
        }
    }

    func updateUserProfile(displayName: String? = nil, photoURL: String? = nil, isLocationSharing: Bool? = nil) async throws {
        guard let userId = Auth.auth().currentUser?.uid else { return }

        var updates: [String: Any] = [:]
        if let displayName = displayName {
            updates["displayName"] = displayName
        }
        if let photoURL = photoURL {
            updates["photoURL"] = photoURL
        }
        if let isLocationSharing = isLocationSharing {
            updates["isLocationSharing"] = isLocationSharing
        }

        if !updates.isEmpty {
            try await db.collection("users").document(userId).updateData(updates)
        }
    }

    func listenToUserProfile() {
        guard let userId = Auth.auth().currentUser?.uid else { return }

        // Remove previous listener to prevent leaks
        userProfileListener?.remove()

        userProfileListener = db.collection("users").document(userId)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let data = snapshot?.data() else { return }
                self?.currentUserProfile = UserProfile(dictionary: data)
            }
    }

    // MARK: - Circles

    func createCircle(name: String) async throws -> String {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "Auth", code: -1, userInfo: [NSLocalizedDescriptionKey: "Not authenticated"])
        }

        let circleRef = db.collection("circles").document()
        let circle = FamilyCircle(
            id: circleRef.documentID,
            name: name,
            createdBy: userId,
            memberIds: [userId],
            inviteCode: generateInviteCode(),
            createdAt: Date()
        )

        try await circleRef.setData(circle.dictionary)

        // Add circle reference to user
        try await db.collection("users").document(userId).updateData([
            "circleIds": FieldValue.arrayUnion([circleRef.documentID])
        ])

        return circleRef.documentID
    }

    func joinCircle(inviteCode: String) async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "Auth", code: -1, userInfo: [NSLocalizedDescriptionKey: "Not authenticated"])
        }

        let snapshot = try await db.collection("circles")
            .whereField("inviteCode", isEqualTo: inviteCode.uppercased())
            .getDocuments()

        guard let circleDoc = snapshot.documents.first else {
            throw NSError(domain: "Circle", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid invite code"])
        }

        // Add user to circle
        try await circleDoc.reference.updateData([
            "memberIds": FieldValue.arrayUnion([userId])
        ])

        // Add circle to user
        try await db.collection("users").document(userId).updateData([
            "circleIds": FieldValue.arrayUnion([circleDoc.documentID])
        ])
    }

    func leaveCircle(circleId: String) async throws {
        guard let userId = Auth.auth().currentUser?.uid else { return }

        // Remove user from circle
        try await db.collection("circles").document(circleId).updateData([
            "memberIds": FieldValue.arrayRemove([userId])
        ])

        // Remove circle from user
        try await db.collection("users").document(userId).updateData([
            "circleIds": FieldValue.arrayRemove([circleId])
        ])
    }

    func listenToCircles() {
        guard let userId = Auth.auth().currentUser?.uid else { return }

        // Remove previous listener to prevent leaks
        circlesListener?.remove()

        circlesListener = db.collection("circles")
            .whereField("memberIds", arrayContains: userId)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                guard let documents = snapshot?.documents else { return }

                let newCircles = documents.compactMap { FamilyCircle(dictionary: $0.data()) }
                self.circles = newCircles

                // Set current circle if not set or if current circle no longer exists
                if self.currentCircleId == nil || !newCircles.contains(where: { $0.id == self.currentCircleId }) {
                    if let firstCircle = newCircles.first {
                        self.switchCircle(to: firstCircle.id)
                    }
                }
            }
    }

    func listenToCircleMembers(circleId: String) {
        // Remove previous listener to prevent leaks
        circleMemberListener?.remove()

        circleMemberListener = db.collection("circles").document(circleId)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let data = snapshot?.data(),
                      let memberIds = data["memberIds"] as? [String] else { return }

                Task {
                    await self?.fetchAndListenToMembers(memberIds: memberIds)
                }
            }
    }

    private func fetchAndListenToMembers(memberIds: [String]) async {
        let memberIdSet = Set(memberIds)

        // Remove listeners for members no longer in the circle
        for (memberId, listener) in memberListeners {
            if !memberIdSet.contains(memberId) {
                listener.remove()
                memberListeners.removeValue(forKey: memberId)
            }
        }

        // Remove stale members from the array
        circleMembers.removeAll { !memberIdSet.contains($0.id) }

        // Add listeners only for new members (not already tracked)
        for memberId in memberIds {
            guard memberListeners[memberId] == nil else { continue }

            let listener = db.collection("users").document(memberId)
                .addSnapshotListener { [weak self] snapshot, error in
                    guard let self = self,
                          let data = snapshot?.data(),
                          let profile = UserProfile(dictionary: data) else { return }

                    if let index = self.circleMembers.firstIndex(where: { $0.id == profile.id }) {
                        self.circleMembers[index] = profile
                    } else {
                        self.circleMembers.append(profile)
                    }
                }

            memberListeners[memberId] = listener
        }
    }

    // MARK: - Places

    func addPlace(_ place: Place, circleId: String) async throws {
        let placeRef = db.collection("circles").document(circleId).collection("places").document()
        var placeData = place.dictionary
        placeData["id"] = placeRef.documentID
        try await placeRef.setData(placeData)
    }

    func listenToPlaces(circleId: String) {
        // Remove previous listener to prevent leaks
        placesListener?.remove()

        placesListener = db.collection("circles").document(circleId).collection("places")
            .addSnapshotListener { [weak self] snapshot, error in
                guard let documents = snapshot?.documents else { return }
                self?.places = documents.compactMap { Place(dictionary: $0.data()) }
            }
    }

    func deletePlace(placeId: String, circleId: String) async throws {
        try await db.collection("circles").document(circleId).collection("places").document(placeId).delete()
    }

    // MARK: - Account Deletion (Required by App Store)

    func deleteUserData(userId: String) async throws {
        // Get user's circles
        let userDoc = try await db.collection("users").document(userId).getDocument()
        if let circleIds = userDoc.data()?["circleIds"] as? [String] {
            // Remove user from all circles
            for circleId in circleIds {
                try await db.collection("circles").document(circleId).updateData([
                    "memberIds": FieldValue.arrayRemove([userId])
                ])
            }
        }

        // Delete user's places in all circles
        let circlesSnapshot = try await db.collection("circles")
            .whereField("createdBy", isEqualTo: userId)
            .getDocuments()

        for circleDoc in circlesSnapshot.documents {
            // If user created the circle and is the only member, delete the circle
            if let memberIds = circleDoc.data()["memberIds"] as? [String],
               memberIds.count <= 1 {
                // Delete all places in the circle
                let placesSnapshot = try await circleDoc.reference.collection("places").getDocuments()
                for placeDoc in placesSnapshot.documents {
                    try await placeDoc.reference.delete()
                }
                // Delete the circle
                try await circleDoc.reference.delete()
            }
        }

        // Delete user profile
        try await db.collection("users").document(userId).delete()
    }

    // MARK: - Helpers

    private func generateInviteCode() -> String {
        let characters = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
        return String((0..<6).map { _ in characters.randomElement()! })
    }

    func removeAllListeners() {
        // Remove all tracked listeners
        listeners.forEach { $0.remove() }
        listeners.removeAll()

        // Remove specific listeners
        userProfileListener?.remove()
        userProfileListener = nil

        circlesListener?.remove()
        circlesListener = nil

        circleMemberListener?.remove()
        circleMemberListener = nil

        placesListener?.remove()
        placesListener = nil

        // Remove all member-specific listeners
        memberListeners.values.forEach { $0.remove() }
        memberListeners.removeAll()

        // Clear data
        circleMembers.removeAll()
        circles.removeAll()
        places.removeAll()
        currentCircleId = nil
        currentUserProfile = nil
    }

    func switchCircle(to circleId: String) {
        // Clear stale data before switching
        circleMembers.removeAll()
        places.removeAll()

        // Remove member-specific listeners from old circle
        memberListeners.values.forEach { $0.remove() }
        memberListeners.removeAll()

        currentCircleId = circleId
        listenToCircleMembers(circleId: circleId)
        listenToPlaces(circleId: circleId)
    }
}
