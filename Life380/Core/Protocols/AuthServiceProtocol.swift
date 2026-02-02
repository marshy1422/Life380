import Foundation
import CoreLocation

/// Protocol defining authentication service capabilities
@MainActor
protocol AuthServiceProtocol: AnyObject, ObservableObject {
    // MARK: - State

    var isAuthenticated: Bool { get }
    var isLoading: Bool { get }
    var errorMessage: String? { get }
    var currentUserId: String? { get }

    // MARK: - Email Authentication

    func signUp(email: String, password: String, displayName: String, location: CLLocationCoordinate2D?, accuracy: Double?) async
    func signIn(email: String, password: String) async
    func signOut()
    func resetPassword(email: String) async

    // MARK: - Account Management

    func deleteAccount() async -> Bool
    func reauthenticate(email: String, password: String) async -> Bool
}

/// Protocol for biometric authentication
protocol BiometricAuthServiceProtocol: AnyObject {
    // MARK: - Availability

    var isBiometricAvailable: Bool { get }
    var biometricType: BiometricType { get }

    // MARK: - Authentication

    func authenticate(reason: String) async -> Bool
}

/// Types of biometric authentication
enum BiometricType {
    case none
    case touchID
    case faceID

    var displayName: String {
        switch self {
        case .none: return "None"
        case .touchID: return "Touch ID"
        case .faceID: return "Face ID"
        }
    }

    var iconName: String {
        switch self {
        case .none: return "lock"
        case .touchID: return "touchid"
        case .faceID: return "faceid"
        }
    }
}
