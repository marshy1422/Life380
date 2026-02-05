import Foundation
import FirebaseAnalytics
import FirebaseCrashlytics

/// Centralized analytics service for tracking user behavior and app performance
final class AnalyticsService {
    static let shared = AnalyticsService()

    private init() {}

    // MARK: - User Properties

    /// Set user ID for analytics (call after login)
    func setUserId(_ userId: String) {
        Analytics.setUserID(userId)
        Crashlytics.crashlytics().setUserID(userId)
    }

    /// Clear user ID (call after logout)
    func clearUserId() {
        Analytics.setUserID(nil)
    }

    /// Set custom user property
    func setUserProperty(_ value: String?, forName name: String) {
        Analytics.setUserProperty(value, forName: name)
    }

    // MARK: - Screen Tracking

    /// Track screen view
    func trackScreen(_ screenName: String, screenClass: String? = nil) {
        Analytics.logEvent(AnalyticsEventScreenView, parameters: [
            AnalyticsParameterScreenName: screenName,
            AnalyticsParameterScreenClass: screenClass ?? screenName
        ])
    }

    // MARK: - Authentication Events

    func trackLogin(method: String) {
        Analytics.logEvent(AnalyticsEventLogin, parameters: [
            AnalyticsParameterMethod: method
        ])
    }

    func trackSignUp(method: String) {
        Analytics.logEvent(AnalyticsEventSignUp, parameters: [
            AnalyticsParameterMethod: method
        ])
    }

    func trackLogout() {
        Analytics.logEvent("logout", parameters: nil)
        clearUserId()
    }

    // MARK: - Circle Events

    func trackCircleCreated(circleId: String) {
        Analytics.logEvent("circle_created", parameters: [
            "circle_id": circleId
        ])
    }

    func trackCircleJoined(circleId: String, method: String) {
        Analytics.logEvent("circle_joined", parameters: [
            "circle_id": circleId,
            "method": method  // "invite_code", "qr_code", "deep_link"
        ])
    }

    func trackCircleLeft(circleId: String) {
        Analytics.logEvent("circle_left", parameters: [
            "circle_id": circleId
        ])
    }

    func trackMemberInvited(circleId: String) {
        Analytics.logEvent("member_invited", parameters: [
            "circle_id": circleId
        ])
    }

    // MARK: - Location Events

    func trackLocationSharingToggled(enabled: Bool) {
        Analytics.logEvent("location_sharing_toggled", parameters: [
            "enabled": enabled
        ])
    }

    func trackPlaceCreated(placeId: String, placeType: String) {
        Analytics.logEvent("place_created", parameters: [
            "place_id": placeId,
            "place_type": placeType  // "home", "work", "school", "custom"
        ])
    }

    func trackGeofenceTriggered(placeId: String, eventType: String) {
        Analytics.logEvent("geofence_triggered", parameters: [
            "place_id": placeId,
            "event_type": eventType  // "arrival", "departure"
        ])
    }

    // MARK: - Feature Usage

    func trackSOSActivated() {
        Analytics.logEvent("sos_activated", parameters: nil)
    }

    func trackSOSCancelled() {
        Analytics.logEvent("sos_cancelled", parameters: nil)
    }

    func trackMapViewed() {
        Analytics.logEvent("map_viewed", parameters: nil)
    }

    func trackMemberLocationViewed(memberId: String) {
        Analytics.logEvent("member_location_viewed", parameters: [
            "member_id": memberId
        ])
    }

    func trackETARequested() {
        Analytics.logEvent("eta_requested", parameters: nil)
    }

    // MARK: - Settings Events

    func trackSettingsChanged(setting: String, value: String) {
        Analytics.logEvent("settings_changed", parameters: [
            "setting": setting,
            "value": value
        ])
    }

    // MARK: - Error Tracking

    /// Log non-fatal error to Crashlytics
    func logError(_ error: Error, context: [String: Any]? = nil) {
        var userInfo = context ?? [:]
        userInfo["error_description"] = error.localizedDescription

        Crashlytics.crashlytics().record(error: error, userInfo: userInfo)
    }

    /// Log custom message to Crashlytics
    func log(_ message: String) {
        Crashlytics.crashlytics().log(message)
    }

    /// Set custom key-value for crash reports
    func setCrashlyticsKey(_ key: String, value: Any) {
        Crashlytics.crashlytics().setCustomValue(value, forKey: key)
    }

    // MARK: - Performance Tracking

    func trackAppLaunchTime(_ duration: TimeInterval) {
        Analytics.logEvent("app_launch_time", parameters: [
            "duration_ms": Int(duration * 1000)
        ])
    }

    func trackLocationUpdateLatency(_ latency: TimeInterval) {
        Analytics.logEvent("location_update_latency", parameters: [
            "latency_ms": Int(latency * 1000)
        ])
    }

    // MARK: - Custom Events

    /// Log any custom event
    func logEvent(_ name: String, parameters: [String: Any]? = nil) {
        Analytics.logEvent(name, parameters: parameters)
    }
}
