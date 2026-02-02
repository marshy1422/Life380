import SwiftUI
import AVFoundation

struct QRScannerView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var scanner = QRScannerModel()

    let onCodeScanned: (String) -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                // Camera preview
                QRScannerPreview(scanner: scanner)
                    .ignoresSafeArea()

                // Overlay with scanning frame
                VStack {
                    Spacer()

                    // Scanning frame
                    ZStack {
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.white, lineWidth: 3)
                            .frame(width: 250, height: 250)

                        // Corner accents
                        ForEach(0..<4, id: \.self) { index in
                            CornerAccent()
                                .rotationEffect(.degrees(Double(index) * 90))
                        }
                    }

                    Spacer()

                    // Instructions
                    VStack(spacing: 12) {
                        Text("Scan QR Code")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)

                        Text("Point your camera at an invite QR code")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .padding(.bottom, 60)
                }

                // Error message
                if let error = scanner.error {
                    VStack {
                        Spacer()
                        Text(error)
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.red.opacity(0.8))
                            .cornerRadius(10)
                            .padding(.bottom, 120)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }

                ToolbarItem(placement: .principal) {
                    Text("Scan Code")
                        .foregroundColor(.white)
                        .fontWeight(.semibold)
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .onAppear {
                scanner.startScanning()
            }
            .onDisappear {
                scanner.stopScanning()
            }
            .onChange(of: scanner.scannedCode) { _, code in
                if let code = code {
                    // Extract invite code from URL if present
                    if let extractedCode = extractInviteCode(from: code) {
                        onCodeScanned(extractedCode)
                        dismiss()
                    }
                }
            }
        }
    }

    private func extractInviteCode(from string: String) -> String? {
        // Check if it's a deep link URL
        if string.starts(with: "life380://join?code=") {
            return String(string.dropFirst("life380://join?code=".count))
        }

        // Check if it's just a 6-character code
        let trimmed = string.trimmingCharacters(in: .whitespaces).uppercased()
        if trimmed.count == 6 {
            return trimmed
        }

        // Try to parse as URL
        if let url = URL(string: string),
           let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
           let code = components.queryItems?.first(where: { $0.name == "code" })?.value {
            return code
        }

        return nil
    }
}

// MARK: - Corner Accent View

struct CornerAccent: View {
    var body: some View {
        Path { path in
            path.move(to: CGPoint(x: -125, y: -105))
            path.addLine(to: CGPoint(x: -125, y: -125))
            path.addLine(to: CGPoint(x: -105, y: -125))
        }
        .stroke(Color.blue, lineWidth: 4)
    }
}

// MARK: - QR Scanner Model

class QRScannerModel: NSObject, ObservableObject {
    @Published var scannedCode: String?
    @Published var error: String?
    @Published var isAuthorized = false

    let captureSession = AVCaptureSession()
    private var isSessionRunning = false

    override init() {
        super.init()
        checkPermission()
    }

    func checkPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            isAuthorized = true
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    self?.isAuthorized = granted
                    if !granted {
                        self?.error = "Camera access is required to scan QR codes"
                    }
                }
            }
        default:
            error = "Camera access denied. Please enable in Settings."
        }
    }

    func startScanning() {
        guard isAuthorized, !isSessionRunning else { return }

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.setupCaptureSession()
        }
    }

    func stopScanning() {
        guard isSessionRunning else { return }

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.captureSession.stopRunning()
            self?.isSessionRunning = false
        }
    }

    private func setupCaptureSession() {
        guard let device = AVCaptureDevice.default(for: .video) else {
            DispatchQueue.main.async {
                self.error = "No camera available"
            }
            return
        }

        do {
            let input = try AVCaptureDeviceInput(device: device)

            if captureSession.canAddInput(input) {
                captureSession.addInput(input)
            }

            let output = AVCaptureMetadataOutput()
            if captureSession.canAddOutput(output) {
                captureSession.addOutput(output)
                output.setMetadataObjectsDelegate(self, queue: .main)
                output.metadataObjectTypes = [.qr]
            }

            captureSession.startRunning()
            isSessionRunning = true
        } catch {
            DispatchQueue.main.async {
                self.error = "Failed to setup camera: \(error.localizedDescription)"
            }
        }
    }
}

// MARK: - AVCaptureMetadataOutputObjectsDelegate

extension QRScannerModel: AVCaptureMetadataOutputObjectsDelegate {
    func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        guard scannedCode == nil else { return }

        if let metadataObject = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
           metadataObject.type == .qr,
           let code = metadataObject.stringValue {
            // Haptic feedback
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)

            scannedCode = code
            stopScanning()
        }
    }
}

// MARK: - Camera Preview

struct QRScannerPreview: UIViewRepresentable {
    let scanner: QRScannerModel

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.backgroundColor = .black

        let previewLayer = AVCaptureVideoPreviewLayer(session: scanner.captureSession)
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.frame = UIScreen.main.bounds
        view.layer.addSublayer(previewLayer)

        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        if let previewLayer = uiView.layer.sublayers?.first as? AVCaptureVideoPreviewLayer {
            previewLayer.frame = UIScreen.main.bounds
        }
    }
}

#Preview {
    QRScannerView { code in
        print("Scanned: \(code)")
    }
}
