import Foundation

/// App environment configuration
enum AppEnvironment {
    case development
    case staging
    case production

    // MARK: - Current Environment
    static var current: AppEnvironment {
        #if DEBUG
        return .development
        #else
        return .production
        #endif
    }

    // MARK: - Environment Properties
    var name: String {
        switch self {
        case .development: return "Development"
        case .staging: return "Staging"
        case .production: return "Production"
        }
    }

    var isDebugEnabled: Bool {
        switch self {
        case .development, .staging: return true
        case .production: return false
        }
    }

    var logLevel: LogLevel {
        switch self {
        case .development: return .debug
        case .staging: return .info
        case .production: return .error
        }
    }

    var analyticsEnabled: Bool {
        switch self {
        case .development: return false
        case .staging, .production: return true
        }
    }
}

// LogLevel is defined in Core/Utilities/Logger.swift
