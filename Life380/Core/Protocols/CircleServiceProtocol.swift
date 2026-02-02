import Foundation
import Combine

/// Protocol defining circle management capabilities
@MainActor
protocol CircleServiceProtocol: AnyObject, ObservableObject {
    // MARK: - State

    var circles: [FamilyCircle] { get }
    var selectedCircle: FamilyCircle? { get set }
    var isLoading: Bool { get }
    var errorMessage: String? { get }

    // MARK: - Circle CRUD

    func createCircle(name: String) async throws -> FamilyCircle
    func fetchCircles(for userId: String) async throws
    func deleteCircle(_ circleId: String) async throws
    func renameCircle(_ circleId: String, newName: String) async throws

    // MARK: - Membership

    func joinCircle(inviteCode: String, userId: String) async throws
    func leaveCircle(_ circleId: String, userId: String) async throws
    func removeMember(_ userId: String, from circleId: String) async throws

    // MARK: - Members

    func fetchMembers(for circleId: String) async throws -> [UserProfile]
}

/// Protocol for circle invitation management
@MainActor
protocol InviteServiceProtocol: AnyObject, ObservableObject {
    // MARK: - Invite Generation

    func generateInviteCode() -> String
    func createInvite(for circle: FamilyCircle, by userId: String, userName: String) async throws -> CircleInvite

    // MARK: - Invite Validation

    func validateInviteCode(_ code: String) async throws -> CircleInvite?
    func useInvite(_ inviteId: String, by userId: String) async throws

    // MARK: - Invite Management

    func getActiveInvites(for circleId: String) async throws -> [CircleInvite]
    func deactivateInvite(_ inviteId: String) async throws
}
