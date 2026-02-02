import Foundation

extension Date {
    // MARK: - Relative Time

    /// Returns a human-readable relative time string (e.g., "2 min ago")
    var relativeTimeString: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: self, relativeTo: Date())
    }

    /// Returns a full relative time string (e.g., "2 minutes ago")
    var relativeTimeStringFull: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: self, relativeTo: Date())
    }

    // MARK: - Time Interval Helpers

    /// Whether the date is within the specified seconds from now
    func isWithin(seconds: TimeInterval) -> Bool {
        abs(timeIntervalSinceNow) <= seconds
    }

    /// Whether the date is considered stale (older than 60 seconds)
    var isStale: Bool {
        !isWithin(seconds: 60)
    }

    /// Seconds since this date
    var secondsAgo: TimeInterval {
        -timeIntervalSinceNow
    }

    /// Minutes since this date
    var minutesAgo: Double {
        secondsAgo / 60
    }

    // MARK: - Formatting

    /// Formats the date for display (e.g., "Today at 2:30 PM")
    var displayString: String {
        let calendar = Calendar.current

        if calendar.isDateInToday(self) {
            return "Today at \(timeString)"
        } else if calendar.isDateInYesterday(self) {
            return "Yesterday at \(timeString)"
        } else {
            return "\(shortDateString) at \(timeString)"
        }
    }

    /// Time string (e.g., "2:30 PM")
    var timeString: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: self)
    }

    /// Short date string (e.g., "Jan 15")
    var shortDateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: self)
    }

    /// Full date string (e.g., "January 15, 2024")
    var fullDateString: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        return formatter.string(from: self)
    }

    // MARK: - Date Components

    /// Start of the current day
    var startOfDay: Date {
        Calendar.current.startOfDay(for: self)
    }

    /// End of the current day
    var endOfDay: Date {
        var components = DateComponents()
        components.day = 1
        components.second = -1
        return Calendar.current.date(byAdding: components, to: startOfDay) ?? self
    }

    /// Start of the current week
    var startOfWeek: Date {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: self)
        return calendar.date(from: components) ?? self
    }

    /// Day of week (e.g., "Monday")
    var dayOfWeek: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return formatter.string(from: self)
    }
}

// MARK: - TimeInterval Extensions

extension TimeInterval {
    /// Formatted duration string (e.g., "2h 30m")
    var formattedDuration: String {
        let hours = Int(self / 3600)
        let minutes = Int((self.truncatingRemainder(dividingBy: 3600)) / 60)

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else if minutes > 0 {
            return "\(minutes)m"
        } else {
            return "< 1m"
        }
    }

    /// Formatted duration with seconds (e.g., "2:30:15")
    var formattedDurationWithSeconds: String {
        let hours = Int(self / 3600)
        let minutes = Int((self.truncatingRemainder(dividingBy: 3600)) / 60)
        let seconds = Int(self.truncatingRemainder(dividingBy: 60))

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
}
