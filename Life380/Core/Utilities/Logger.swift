import Foundation
import os.log

/// Log levels for logging
enum LogLevel: Int, Comparable {
    case debug = 0
    case info = 1
    case warning = 2
    case error = 3

    static func < (lhs: LogLevel, rhs: LogLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

/// Centralized logging utility for the app
enum Logger {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.life380"

    private static let general = OSLog(subsystem: subsystem, category: "general")
    private static let location = OSLog(subsystem: subsystem, category: "location")
    private static let network = OSLog(subsystem: subsystem, category: "network")
    private static let auth = OSLog(subsystem: subsystem, category: "auth")

    // MARK: - Log Categories

    enum Category {
        case general
        case location
        case network
        case auth

        var osLog: OSLog {
            switch self {
            case .general: return Logger.general
            case .location: return Logger.location
            case .network: return Logger.network
            case .auth: return Logger.auth
            }
        }
    }

    // MARK: - Logging Methods

    /// Logs a message at the specified level
    static func log(
        _ message: String,
        level: LogLevel = .info,
        category: Category = .general,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        #if DEBUG
        let fileName = (file as NSString).lastPathComponent
        let logMessage = "[\(fileName):\(line)] \(function) - \(message)"

        switch level {
        case .debug:
            os_log(.debug, log: category.osLog, "%{public}@", logMessage)
        case .info:
            os_log(.info, log: category.osLog, "%{public}@", logMessage)
        case .warning:
            os_log(.default, log: category.osLog, "WARNING: %{public}@", logMessage)
        case .error:
            os_log(.error, log: category.osLog, "ERROR: %{public}@", logMessage)
        }
        #endif
    }

    /// Logs a debug message
    static func debug(_ message: String, category: Category = .general) {
        log(message, level: .debug, category: category)
    }

    /// Logs an info message
    static func info(_ message: String, category: Category = .general) {
        log(message, level: .info, category: category)
    }

    /// Logs a warning message
    static func warning(_ message: String, category: Category = .general) {
        log(message, level: .warning, category: category)
    }

    /// Logs an error message
    static func error(_ message: String, category: Category = .general) {
        log(message, level: .error, category: category)
    }

    /// Logs an error with the error object
    static func error(_ error: Error, message: String? = nil, category: Category = .general) {
        let errorMessage = message.map { "\($0): \(error.localizedDescription)" } ?? error.localizedDescription
        log(errorMessage, level: .error, category: category)
    }

    // MARK: - Performance Logging

    /// Measures the execution time of a closure
    @discardableResult
    static func measure<T>(_ label: String, category: Category = .general, block: () throws -> T) rethrows -> T {
        let start = CFAbsoluteTimeGetCurrent()
        let result = try block()
        let duration = CFAbsoluteTimeGetCurrent() - start
        debug("\(label) took \(String(format: "%.3f", duration))s", category: category)
        return result
    }

    /// Measures the execution time of an async closure
    @discardableResult
    static func measureAsync<T>(_ label: String, category: Category = .general, block: () async throws -> T) async rethrows -> T {
        let start = CFAbsoluteTimeGetCurrent()
        let result = try await block()
        let duration = CFAbsoluteTimeGetCurrent() - start
        debug("\(label) took \(String(format: "%.3f", duration))s", category: category)
        return result
    }
}
