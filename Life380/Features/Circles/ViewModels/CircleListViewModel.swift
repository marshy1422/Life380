import Foundation
import Combine

enum CircleListState {
    case loading
    case empty
    case loaded([FamilyCircle])
    case error(String)
}

@MainActor
class CircleListViewModel: ObservableObject {
    // MARK: - Published Properties

    @Published var state: CircleListState = .loading
    @Published var circles: [FamilyCircle] = []
    @Published var membersByCircle: [String: [UserProfile]] = [:]

    // MARK: - Dependencies

    private let firestoreService: FirestoreService
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    init(firestoreService: FirestoreService? = nil) {
        self.firestoreService = firestoreService ?? FirestoreService.shared
    }

    // MARK: - Observers

    func startObserving() {
        state = .loading

        // Observe circles from FirestoreService
        firestoreService.$circles
            .receive(on: DispatchQueue.main)
            .sink { [weak self] circles in
                self?.handleCirclesUpdate(circles)
            }
            .store(in: &cancellables)
    }

    func stopObserving() {
        cancellables.removeAll()
    }

    private func handleCirclesUpdate(_ circles: [FamilyCircle]) {
        self.circles = circles

        if circles.isEmpty {
            state = .empty
        } else {
            state = .loaded(circles)
        }
    }

    // MARK: - Actions

    func retry() {
        startObserving()
    }

    func leaveCircle(_ circle: FamilyCircle) async -> Bool {
        do {
            try await firestoreService.leaveCircle(circleId: circle.id)
            return true
        } catch {
            state = .error(error.localizedDescription)
            return false
        }
    }
}
