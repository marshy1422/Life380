import SwiftUI

/// Badge showing ETA to a place
struct ETABadge: View {
    let eta: ETAResult

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: iconName)
                .font(.system(size: 10, weight: .semibold))

            Text(eta.etaText)
                .font(.system(size: 11, weight: .medium))

            if eta.isAlmostThere {
                Text("away")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
        }
        .foregroundColor(textColor)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(backgroundColor)
        )
    }

    private var iconName: String {
        if eta.hasArrived {
            return "checkmark.circle.fill"
        } else if eta.isAlmostThere {
            return "car.fill"
        } else {
            return "clock"
        }
    }

    private var textColor: Color {
        if eta.hasArrived {
            return .white
        } else if eta.isAlmostThere {
            return .white
        } else {
            return .primary
        }
    }

    private var backgroundColor: Color {
        if eta.hasArrived {
            return .green
        } else if eta.isAlmostThere {
            return .blue
        } else {
            return Color(.systemGray5)
        }
    }
}

/// Card showing member's ETA to saved places
struct MemberETACard: View {
    let member: UserProfile
    let etas: [ETAResult]
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                // Member avatar
                Text(member.initials)
                    .font(.headline.bold())
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(member.color)
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(member.displayName)
                        .font(.headline)

                    if let speed = formattedSpeed {
                        HStack(spacing: 4) {
                            Image(systemName: "speedometer")
                                .font(.caption2)
                            Text(speed)
                                .font(.caption)
                        }
                        .foregroundColor(.secondary)
                    }
                }

                Spacer()

                // Battery
                VStack(spacing: 2) {
                    Image(systemName: member.batteryIcon)
                        .foregroundColor(member.batteryColor)
                    Text("\(member.batteryLevel)%")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            }

            Divider()

            // ETAs to places
            if etas.isEmpty {
                Text("No saved places")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                ForEach(etas.prefix(3)) { eta in
                    ETARow(eta: eta)
                }

                if etas.count > 3 {
                    Text("+\(etas.count - 3) more places")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(radius: 8)
    }

    private var formattedSpeed: String? {
        guard member.isPrecise,
              let accuracy = member.horizontalAccuracy,
              accuracy < 50 else { return nil }

        // Speed would come from the location data
        // For now, show accuracy indicator
        return "±\(Int(accuracy))m accuracy"
    }
}

/// Single row showing ETA to a place
struct ETARow: View {
    let eta: ETAResult

    var body: some View {
        HStack(spacing: 12) {
            // Place icon
            Image(systemName: eta.place.icon)
                .font(.system(size: 16))
                .foregroundColor(eta.place.color)
                .frame(width: 32, height: 32)
                .background(eta.place.color.opacity(0.15))
                .clipShape(Circle())

            // Place name and distance
            VStack(alignment: .leading, spacing: 2) {
                Text(eta.place.name)
                    .font(.subheadline.weight(.medium))

                Text(eta.distanceText)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // ETA badge
            ETABadge(eta: eta)
        }
    }
}

/// Compact ETA indicator for map annotations
struct ETAIndicator: View {
    let eta: ETAResult?

    var body: some View {
        if let eta = eta {
            HStack(spacing: 2) {
                if eta.hasArrived {
                    Image(systemName: "checkmark")
                        .font(.system(size: 8, weight: .bold))
                } else {
                    Text(eta.etaText)
                        .font(.system(size: 9, weight: .semibold))
                }
            }
            .foregroundColor(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                Capsule()
                    .fill(eta.isAlmostThere ? Color.blue : Color.gray)
            )
        }
    }
}

// MARK: - Previews

#Preview("ETA Badge") {
    VStack(spacing: 16) {
        ETABadge(eta: ETAResult(
            place: Place.samplePlaces[0],
            eta: 120,
            distance: 500,
            calculationMethod: .speedBased,
            confidence: .medium,
            timestamp: Date()
        ))

        ETABadge(eta: ETAResult(
            place: Place.samplePlaces[0],
            eta: 240,
            distance: 2000,
            calculationMethod: .mapKit,
            confidence: .high,
            timestamp: Date()
        ))

        ETABadge(eta: ETAResult(
            place: Place.samplePlaces[0],
            eta: 30,
            distance: 50,
            calculationMethod: .speedBased,
            confidence: .high,
            timestamp: Date()
        ))
    }
    .padding()
}

#Preview("ETA Row") {
    VStack {
        ETARow(eta: ETAResult(
            place: Place.samplePlaces[0],
            eta: 600,
            distance: 5000,
            calculationMethod: .mapKit,
            confidence: .high,
            timestamp: Date()
        ))

        ETARow(eta: ETAResult(
            place: Place.samplePlaces[1],
            eta: 180,
            distance: 800,
            calculationMethod: .speedBased,
            confidence: .medium,
            timestamp: Date()
        ))
    }
    .padding()
}
