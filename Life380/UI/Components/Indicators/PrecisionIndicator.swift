import SwiftUI
import MapKit

// MARK: - Confidence Ring

/// Displays a ring around a location dot showing accuracy radius
struct ConfidenceRing: View {
    let confidence: LocationConfidence
    let radiusMeters: Double
    let isStale: Bool

    var ringColor: Color {
        if isStale {
            return .gray.opacity(0.4)
        }
        switch confidence {
        case .excellent:
            return .green.opacity(0.35)
        case .high:
            return .blue.opacity(0.3)
        case .medium:
            return .teal.opacity(0.25)
        case .low:
            return .orange.opacity(0.25)
        case .approximate:
            return .red.opacity(0.2)
        }
    }

    var strokeColor: Color {
        if isStale {
            return .gray.opacity(0.6)
        }
        switch confidence {
        case .excellent:
            return .green.opacity(0.7)
        case .high:
            return .blue.opacity(0.6)
        case .medium:
            return .teal.opacity(0.5)
        case .low:
            return .orange.opacity(0.5)
        case .approximate:
            return .red.opacity(0.4)
        }
    }

    var body: some View {
        Circle()
            .fill(ringColor)
            .overlay(
                Circle()
                    .strokeBorder(strokeColor, lineWidth: 2)
            )
    }
}

// MARK: - Precision Badge

/// Small badge showing location precision status
struct PrecisionBadge: View {
    let confidence: LocationConfidence
    let source: LocationSource
    let isStale: Bool
    var compact: Bool = false
    var showAccuracy: Bool = false
    var accuracy: Double? = nil

    var backgroundColor: Color {
        if isStale {
            return .gray
        }
        switch confidence {
        case .excellent:
            return .green
        case .high:
            return .blue
        case .medium:
            return .teal
        case .low:
            return .orange
        case .approximate:
            return .red
        }
    }

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: source.icon)
                .font(.system(size: compact ? 10 : 12, weight: .semibold))

            if !compact {
                if isStale {
                    Text("Updating...")
                        .font(.system(size: 11, weight: .medium))
                } else if showAccuracy, let acc = accuracy {
                    Text("±\(Int(acc))m")
                        .font(.system(size: 11, weight: .medium))
                } else {
                    Text(confidence.displayName)
                        .font(.system(size: 11, weight: .medium))
                }
            }
        }
        .foregroundColor(.white)
        .padding(.horizontal, compact ? 6 : 10)
        .padding(.vertical, compact ? 4 : 6)
        .background(
            Capsule()
                .fill(backgroundColor)
        )
        .animation(.easeInOut(duration: 0.2), value: confidence)
        .animation(.easeInOut(duration: 0.2), value: isStale)
    }
}

// MARK: - Confidence Score Bar

/// Visual bar showing location confidence as a score
struct ConfidenceScoreBar: View {
    let confidence: LocationConfidence
    let isStale: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Signal Quality")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Spacer()
                Text(confidence.displayName)
                    .font(.caption2.bold())
                    .foregroundColor(isStale ? .gray : confidenceColor)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // Background
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.gray.opacity(0.2))

                    // Filled portion
                    RoundedRectangle(cornerRadius: 3)
                        .fill(isStale ? Color.gray : confidenceColor)
                        .frame(width: geo.size.width * CGFloat(confidence.score) / 100)
                }
            }
            .frame(height: 6)
        }
    }

    var confidenceColor: Color {
        switch confidence {
        case .excellent: return .green
        case .high: return .blue
        case .medium: return .teal
        case .low: return .orange
        case .approximate: return .red
        }
    }
}

// MARK: - Signal Strength Indicator

/// Shows location signal strength like WiFi bars
struct SignalStrengthIndicator: View {
    let confidence: LocationConfidence
    let isStale: Bool

    private var activeBars: Int {
        switch confidence {
        case .excellent: return 4
        case .high: return 3
        case .medium: return 2
        case .low: return 1
        case .approximate: return 0
        }
    }

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<4) { index in
                RoundedRectangle(cornerRadius: 1)
                    .fill(index < activeBars && !isStale ? barColor : Color.gray.opacity(0.3))
                    .frame(width: 4, height: CGFloat(6 + index * 4))
            }
        }
    }

    var barColor: Color {
        switch confidence {
        case .excellent: return .green
        case .high: return .blue
        case .medium: return .teal
        case .low: return .orange
        case .approximate: return .red
        }
    }
}

// MARK: - Precision Dot

/// Location marker with integrated confidence visualization
struct PrecisionDot: View {
    let location: PrecisionLocation
    var showRing: Bool = true
    var dotSize: CGFloat = 20
    var pulsing: Bool = false

    @State private var isPulsing = false

    var dotColor: Color {
        if location.isStale {
            return .gray
        }
        switch location.confidence {
        case .excellent:
            return .green
        case .high:
            return .blue
        case .medium:
            return .teal
        case .low:
            return .orange
        case .approximate:
            return .red
        }
    }

    var body: some View {
        ZStack {
            // Confidence ring (if enabled)
            if showRing {
                ConfidenceRing(
                    confidence: location.confidence,
                    radiusMeters: location.confidenceRadius,
                    isStale: location.isStale
                )
                .frame(width: ringSize, height: ringSize)
            }

            // Pulsing effect for active tracking
            if pulsing && !location.isStale {
                Circle()
                    .fill(dotColor.opacity(0.3))
                    .frame(width: dotSize * 2, height: dotSize * 2)
                    .scaleEffect(isPulsing ? 1.5 : 1.0)
                    .opacity(isPulsing ? 0 : 0.5)
                    .animation(
                        .easeOut(duration: 1.5).repeatForever(autoreverses: false),
                        value: isPulsing
                    )
            }

            // Main dot
            Circle()
                .fill(dotColor)
                .frame(width: dotSize, height: dotSize)
                .overlay(
                    Circle()
                        .strokeBorder(.white, lineWidth: 3)
                )
                .shadow(color: dotColor.opacity(0.4), radius: 4, x: 0, y: 2)
        }
        .onAppear {
            if pulsing {
                isPulsing = true
            }
        }
    }

    private var ringSize: CGFloat {
        // Scale ring based on accuracy (clamped for UI)
        let scale = min(max(location.horizontalAccuracy / 10, 2), 8)
        return dotSize * scale
    }
}

// MARK: - Location Info Card

/// Detailed card showing all precision metadata
struct PrecisionInfoCard: View {
    let location: PrecisionLocation

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with confidence
            HStack {
                PrecisionBadge(
                    confidence: location.confidence,
                    source: location.source,
                    isStale: location.isStale
                )

                Spacer()

                Text(location.accuracyDescription)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary)
            }

            Divider()

            // Details grid
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 8) {
                InfoRow(label: "Accuracy", value: "\(Int(location.horizontalAccuracy))m")
                InfoRow(label: "Source", value: location.source.rawValue.capitalized)

                if let speed = location.speed, speed > 0 {
                    InfoRow(label: "Speed", value: String(format: "%.1f m/s", speed))
                }

                if let course = location.course, course >= 0 {
                    InfoRow(label: "Heading", value: "\(Int(course))°")
                }

                if let floor = location.floor {
                    InfoRow(label: "Floor", value: floorDisplayName(floor))
                }

                InfoRow(label: "Updated", value: timeAgo(location.timestamp))
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        )
    }

    private func timeAgo(_ date: Date) -> String {
        let seconds = Int(Date().timeIntervalSince(date))
        if seconds < 5 {
            return "Just now"
        } else if seconds < 60 {
            return "\(seconds)s ago"
        } else if seconds < 3600 {
            return "\(seconds / 60)m ago"
        } else {
            return "\(seconds / 3600)h ago"
        }
    }

    private func floorDisplayName(_ floor: Int) -> String {
        if floor == 0 {
            return "Ground"
        } else if floor > 0 {
            return "Floor \(floor)"
        } else {
            return "B\(abs(floor))"
        }
    }
}

// MARK: - Floor Badge

/// Badge showing current floor level
struct FloorBadge: View {
    let floor: Int

    var displayName: String {
        if floor == 0 {
            return "Ground"
        } else if floor > 0 {
            return "F\(floor)"
        } else {
            return "B\(abs(floor))"
        }
    }

    var icon: String {
        if floor > 0 {
            return "arrow.up"
        } else if floor < 0 {
            return "arrow.down"
        } else {
            return "building.2"
        }
    }

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
            Text(displayName)
                .font(.system(size: 11, weight: .medium))
        }
        .foregroundColor(.white)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(Color.purple)
        )
    }
}

// MARK: - Info Row Helper

private struct InfoRow: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
            Text(value)
                .font(.system(size: 14, weight: .medium))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Map Annotation

/// Map annotation view with precision indicator
struct PrecisionMapAnnotation: View {
    let location: PrecisionLocation
    let memberName: String?
    let memberColor: Color

    var body: some View {
        VStack(spacing: 4) {
            // Name label (if provided)
            if let name = memberName {
                Text(name)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(memberColor)
                    )
            }

            // Precision dot
            PrecisionDot(
                location: location,
                showRing: true,
                dotSize: 16,
                pulsing: !location.isStale
            )
        }
    }
}

// MARK: - Previews

#Preview("Precision Badge") {
    VStack(spacing: 16) {
        PrecisionBadge(confidence: .high, source: .gnss, isStale: false)
        PrecisionBadge(confidence: .medium, source: .fused, isStale: false)
        PrecisionBadge(confidence: .low, source: .wifi, isStale: false)
        PrecisionBadge(confidence: .approximate, source: .cellular, isStale: false)
        PrecisionBadge(confidence: .high, source: .gnss, isStale: true)
    }
    .padding()
}

#Preview("Precision Dot") {
    let location = PrecisionLocation(
        latitude: 37.7749,
        longitude: -122.4194,
        horizontalAccuracy: 15,
        source: .fused
    )

    PrecisionDot(location: location, showRing: true, pulsing: true)
        .frame(width: 200, height: 200)
}

#Preview("Info Card") {
    let location = PrecisionLocation(
        latitude: 37.7749,
        longitude: -122.4194,
        altitude: 10,
        horizontalAccuracy: 12,
        verticalAccuracy: 8,
        course: 180,
        speed: 1.5,
        source: .gnss,
        floor: 2
    )

    PrecisionInfoCard(location: location)
        .padding()
}
