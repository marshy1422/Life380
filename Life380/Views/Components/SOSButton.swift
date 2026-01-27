import SwiftUI
import CoreLocation
import os.log

private let logger = Logger(subsystem: "com.life380.app", category: "SOSButton")

/// SOS Emergency Button - Hold for 3 seconds to trigger
struct SOSButton: View {
    @ObservedObject var locationManager: PrecisionLocationManager
    @StateObject private var sosService = SOSService.shared

    @State private var isHolding: Bool = false
    @State private var holdProgress: CGFloat = 0
    @State private var showConfirmation: Bool = false
    @State private var showError: Bool = false
    @State private var errorMessage: String = ""

    private let holdDuration: TimeInterval = 3.0
    @State private var holdTimer: Timer?

    var body: some View {
        VStack(spacing: 12) {
            if sosService.isSOSActive {
                activeSOSView
            } else {
                sosButtonView
            }
        }
        .alert("SOS Sent", isPresented: $showConfirmation) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Your emergency alert has been sent to your circle members.")
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }

    // MARK: - Active SOS View

    @State private var isPulsing: Bool = false

    private var activeSOSView: some View {
        VStack(spacing: 8) {
            ZStack {
                // Pulsing background
                Circle()
                    .fill(Color.red.opacity(0.3))
                    .frame(width: 120, height: 120)
                    .scaleEffect(isPulsing ? 1.3 : 1.0)
                    .opacity(isPulsing ? 0 : 0.5)

                HStack(spacing: 8) {
                    Image(systemName: "sos")
                        .font(.title2.bold())
                    Text("SOS ACTIVE")
                        .font(.headline.bold())
                }
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(Color.red)
                .cornerRadius(25)
                .shadow(color: .red.opacity(0.5), radius: isPulsing ? 12 : 8)
            }
            .onAppear {
                withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: false)) {
                    isPulsing = true
                }
            }

            Button(action: cancelSOS) {
                Text("Cancel SOS")
                    .font(.subheadline)
                    .foregroundColor(.red)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color(.systemBackground))
                    .cornerRadius(15)
                    .overlay(
                        RoundedRectangle(cornerRadius: 15)
                            .stroke(Color.red, lineWidth: 1)
                    )
            }
            .disabled(sosService.isSending)
        }
        .animation(.spring(response: 0.3), value: sosService.isSOSActive)
    }

    // MARK: - SOS Button View

    private var sosButtonView: some View {
        ZStack {
            // Progress ring
            Circle()
                .stroke(Color.red.opacity(0.3), lineWidth: 4)
                .frame(width: 70, height: 70)

            Circle()
                .trim(from: 0, to: holdProgress)
                .stroke(Color.red, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .frame(width: 70, height: 70)
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 0.1), value: holdProgress)

            // Button
            Button(action: { }) {
                VStack(spacing: 2) {
                    Image(systemName: "sos")
                        .font(.system(size: 24, weight: .bold))
                    Text("HOLD")
                        .font(.system(size: 10, weight: .medium))
                }
                .foregroundColor(.white)
                .frame(width: 60, height: 60)
                .background(
                    Circle()
                        .fill(isHolding ? Color.red.opacity(0.8) : Color.red)
                )
                .shadow(color: .red.opacity(isHolding ? 0.6 : 0.3), radius: isHolding ? 12 : 6)
            }
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        if !isHolding {
                            startHold()
                        }
                    }
                    .onEnded { _ in
                        cancelHold()
                    }
            )
            .disabled(sosService.isSending)
        }
        .scaleEffect(isHolding ? 1.1 : 1.0)
        .animation(.spring(response: 0.3), value: isHolding)
    }

    // MARK: - Hold Logic

    private func startHold() {
        isHolding = true
        holdProgress = 0

        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
        impactFeedback.impactOccurred()

        // Start progress animation
        let startTime = Date()
        holdTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { timer in
            let elapsed = Date().timeIntervalSince(startTime)
            holdProgress = min(CGFloat(elapsed / holdDuration), 1.0)

            if elapsed >= holdDuration {
                timer.invalidate()
                triggerSOS()
            }
        }

        logger.debug("SOS hold started")
    }

    private func cancelHold() {
        holdTimer?.invalidate()
        holdTimer = nil
        isHolding = false
        holdProgress = 0

        logger.debug("SOS hold cancelled")
    }

    private func triggerSOS() {
        holdTimer?.invalidate()
        holdTimer = nil
        isHolding = false
        holdProgress = 0

        // Success haptic
        let notificationFeedback = UINotificationFeedbackGenerator()
        notificationFeedback.notificationOccurred(.warning)

        Task {
            do {
                guard let location = locationManager.currentLocation else {
                    errorMessage = "Could not determine your location"
                    showError = true
                    return
                }

                let batteryLevel = getBatteryLevel()

                try await sosService.triggerSOS(
                    location: location.coordinate,
                    batteryLevel: batteryLevel,
                    message: nil
                )

                showConfirmation = true
                logger.notice("SOS triggered successfully")

            } catch {
                errorMessage = error.localizedDescription
                showError = true
                logger.error("Failed to trigger SOS: \(error.localizedDescription)")
            }
        }
    }

    private func cancelSOS() {
        Task {
            do {
                try await sosService.cancelSOS()
                logger.info("SOS cancelled by user")
            } catch {
                errorMessage = "Failed to cancel SOS: \(error.localizedDescription)"
                showError = true
            }
        }
    }

    private func getBatteryLevel() -> Int {
        UIDevice.current.isBatteryMonitoringEnabled = true
        let level = UIDevice.current.batteryLevel
        return level < 0 ? 100 : Int(level * 100)
    }
}

// MARK: - Circle SOS Alert Banner

/// Shows when someone in your circle has triggered an SOS
struct SOSAlertBanner: View {
    let alert: SOSAlert
    let onTap: () -> Void
    let onDismiss: () -> Void

    @State private var isPulsing: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                // Pulsing SOS icon
                ZStack {
                    Circle()
                        .fill(Color.red.opacity(0.3))
                        .frame(width: 50, height: 50)
                        .scaleEffect(isPulsing ? 1.2 : 1.0)

                    Image(systemName: "sos")
                        .font(.title2.bold())
                        .foregroundColor(.white)
                        .frame(width: 40, height: 40)
                        .background(Color.red)
                        .clipShape(Circle())
                }
                .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: isPulsing)

                VStack(alignment: .leading, spacing: 4) {
                    Text("\(alert.userName) needs help!")
                        .font(.headline)
                        .foregroundColor(.white)

                    Text(timeAgo(from: alert.timestamp))
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                }

                Spacer()

                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .foregroundColor(.white.opacity(0.7))
                        .padding(8)
                }
            }
            .padding()
            .background(Color.red)
            .onTapGesture(perform: onTap)
        }
        .cornerRadius(12)
        .shadow(color: .red.opacity(0.4), radius: 8, y: 4)
        .onAppear {
            isPulsing = true
        }
    }

    private func timeAgo(from date: Date) -> String {
        let interval = Date().timeIntervalSince(date)

        if interval < 60 {
            return "Just now"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "\(minutes) min ago"
        } else {
            let hours = Int(interval / 3600)
            return "\(hours) hour\(hours == 1 ? "" : "s") ago"
        }
    }
}

// MARK: - Compact SOS Button for Toolbar

struct CompactSOSButton: View {
    @ObservedObject var locationManager: PrecisionLocationManager
    @State private var showSOSSheet: Bool = false

    var body: some View {
        Button(action: { showSOSSheet = true }) {
            Image(systemName: "sos")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 32, height: 32)
                .background(Color.red)
                .clipShape(Circle())
        }
        .sheet(isPresented: $showSOSSheet) {
            SOSSheetView(locationManager: locationManager)
        }
    }
}

// MARK: - SOS Sheet View

struct SOSSheetView: View {
    @ObservedObject var locationManager: PrecisionLocationManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                Spacer()

                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.red)

                    Text("Emergency SOS")
                        .font(.title.bold())

                    Text("Hold the button for 3 seconds to send an emergency alert to all your circle members.")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }

                SOSButton(locationManager: locationManager)
                    .padding(.vertical, 32)

                Text("Your location will be shared with your circle")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

#Preview {
    VStack(spacing: 32) {
        SOSButton(locationManager: PrecisionLocationManager())

        SOSAlertBanner(
            alert: SOSAlert(
                userId: "123",
                userName: "John",
                latitude: 37.7749,
                longitude: -122.4194,
                batteryLevel: 45
            ),
            onTap: { },
            onDismiss: { }
        )
        .padding()
    }
}
