import Foundation
import Combine

/// ViewModel for the circle list view
@MainActor
class CircleListViewModel: ObservableObject {
    // MARK: - Published Properties

    @Published var circles: [FamilyCircle] = []
    @Published var selectedCircle: FamilyCircle?
    @Published var members: [UserProfile] = []

    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showError = false

    @Published var showCreateCircle = false
    @Published var showJoinCircle = false
    @Published var showInviteToCircle = false

    // MARK: - Dependencies

    private let circleService: CircleService
    private let firestoreService: FirestoreService
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    init(circleService: CircleService = .shared, firestoreService: FirestoreService = .shared) {
        self.circleService = circleService
        self.firestoreService = firestoreService

        setupBindings()
    }

    private func setupBindings() {
        circleService.$circles
            .assign(to: &$circles)

        circleService.$selectedCircle
            .assign(to: &$selectedCircle)

        circleService.$errorMessage
            .compactMap { $0 }
            .sink { [weak self] error in
                self?.errorMessage = error
                self?.showError = true
            }
            .store(in: &cancellables)
    }

    // MARK: - Actions

    func loadCircles(for userId: String) async {
        isLoading = true
        defer { isLoading = false }

        do {
            try await circleService.fetchCircles(for: userId)
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    func selectCircle(_ circle: FamilyCircle) {
        selectedCircle = circle
        circleService.selectedCircle = circle

        Task {
            await loadMembers(for: circle.id)
        }
    }

    func loadMembers(for circleId: String) async {
        do {
            members = try await circleService.fetchMembers(for: circleId)
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    func leaveCircle(_ circleId: String, userId: String) async {
        do {
            try await circleService.leaveCircle(circleId, userId: userId)
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    func deleteCircle(_ circleId: String, userId: String) async {
        do {
            try await circleService.deleteCircle(circleId, by: userId)
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    func removeMember(_ memberId: String, from circleId: String, by userId: String) async {
        do {
            try await circleService.removeMember(memberId, from: circleId, by: userId)
            await loadMembers(for: circleId)
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    // MARK: - Helpers

    func clearError() {
        errorMessage = nil
        showError = false
    }

    func isAdmin(userId: String, for circle: FamilyCircle?) -> Bool {
        circle?.createdBy == userId
    }
}
