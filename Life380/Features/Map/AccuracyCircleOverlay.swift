import MapKit
import UIKit

// MARK: - Accuracy Circle Overlay
// Dynamic accuracy visualization with confidence-based styling

/// Custom overlay for displaying location accuracy radius
final class DynamicAccuracyCircleOverlay: MKCircle {

    // MARK: - Properties

    let memberId: String
    let confidence: LocationConfidence
    let memberColor: UIColor

    // Animation state
    var isAnimating: Bool = false
    var pulseScale: CGFloat = 1.0

    // MARK: - Initialization

    private override init() {
        self.memberId = ""
        self.confidence = .medium
        self.memberColor = .systemBlue
        super.init()
    }

    /// Creates an accuracy circle for a member
    static func create(
        center: CLLocationCoordinate2D,
        accuracy: Double,
        memberId: String,
        memberColor: UIColor
    ) -> DynamicAccuracyCircleOverlay {

        // Clamp accuracy for visual display
        let displayRadius = min(max(accuracy, 5), 500)

        let overlay = DynamicAccuracyCircleOverlay(
            center: center,
            radius: displayRadius
        )

        return overlay
    }

    private init(center: CLLocationCoordinate2D, radius: CLLocationDistance) {
        self.memberId = ""
        self.confidence = LocationConfidence(horizontalAccuracy: radius)
        self.memberColor = .systemBlue
        super.init()
    }
}

// MARK: - Accuracy Circle Renderer

/// Custom renderer with gradient fill and pulsing animation
final class AccuracyCircleRenderer: MKCircleRenderer {

    private let confidence: LocationConfidence
    private let memberColor: UIColor
    private var displayLink: CADisplayLink?
    private var pulsePhase: CGFloat = 0

    // Configuration
    var enablePulse: Bool = true
    var pulseSpeed: CGFloat = 1.5

    init(circle: MKCircle, confidence: LocationConfidence, memberColor: UIColor) {
        self.confidence = confidence
        self.memberColor = memberColor
        super.init(circle: circle)

        configureStyling()
    }

    private func configureStyling() {
        // Base styling based on confidence
        let baseColor = confidence.uiColor

        fillColor = baseColor.withAlphaComponent(fillOpacity)
        strokeColor = baseColor.withAlphaComponent(strokeOpacity)
        lineWidth = strokeWidth
    }

    // MARK: - Confidence-Based Styling

    private var fillOpacity: CGFloat {
        switch confidence {
        case .excellent: return 0.08
        case .high: return 0.10
        case .medium: return 0.12
        case .low: return 0.15
        case .approximate: return 0.18
        }
    }

    private var strokeOpacity: CGFloat {
        switch confidence {
        case .excellent: return 0.4
        case .high: return 0.45
        case .medium: return 0.5
        case .low: return 0.55
        case .approximate: return 0.6
        }
    }

    private var strokeWidth: CGFloat {
        switch confidence {
        case .excellent: return 1.0
        case .high: return 1.5
        case .medium: return 2.0
        case .low: return 2.5
        case .approximate: return 3.0
        }
    }

    // MARK: - Custom Drawing with Gradient

    override func draw(_ mapRect: MKMapRect, zoomScale: MKZoomScale, in context: CGContext) {
        let circleRect = rect(for: overlay.boundingMapRect)

        // Draw radial gradient fill
        drawRadialGradient(in: context, rect: circleRect)

        // Draw stroke with dashed pattern for low confidence
        drawStroke(in: context, rect: circleRect, zoomScale: zoomScale)
    }

    private func drawRadialGradient(in context: CGContext, rect: CGRect) {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2

        guard let gradient = createGradient() else { return }

        context.saveGState()

        // Clip to circle
        let path = CGPath(ellipseIn: rect, transform: nil)
        context.addPath(path)
        context.clip()

        // Draw gradient
        context.drawRadialGradient(
            gradient,
            startCenter: center,
            startRadius: 0,
            endCenter: center,
            endRadius: radius,
            options: [.drawsAfterEndLocation]
        )

        context.restoreGState()
    }

    private func createGradient() -> CGGradient? {
        let baseColor = confidence.uiColor

        let colors = [
            baseColor.withAlphaComponent(fillOpacity * 2).cgColor,
            baseColor.withAlphaComponent(fillOpacity).cgColor,
            baseColor.withAlphaComponent(fillOpacity * 0.5).cgColor
        ] as CFArray

        let locations: [CGFloat] = [0.0, 0.6, 1.0]

        return CGGradient(
            colorsSpace: CGColorSpaceCreateDeviceRGB(),
            colors: colors,
            locations: locations
        )
    }

    private func drawStroke(in context: CGContext, rect: CGRect, zoomScale: MKZoomScale) {
        let path = CGPath(ellipseIn: rect, transform: nil)

        guard let stroke = strokeColor else { return }
        context.setStrokeColor(stroke.cgColor)
        context.setLineWidth(lineWidth / zoomScale)

        // Use dashed line for low confidence
        if confidence == .low || confidence == .approximate {
            let dashLength: CGFloat = 8 / zoomScale
            let dashPattern: [CGFloat] = [dashLength, dashLength / 2]
            context.setLineDash(phase: 0, lengths: dashPattern)
        }

        context.addPath(path)
        context.strokePath()
    }

    // MARK: - Pulse Animation

    func startPulseAnimation() {
        guard enablePulse, displayLink == nil else { return }

        displayLink = CADisplayLink(target: self, selector: #selector(updatePulse))
        displayLink?.add(to: .main, forMode: .common)
    }

    func stopPulseAnimation() {
        displayLink?.invalidate()
        displayLink = nil
        pulsePhase = 0
    }

    @objc private func updatePulse() {
        pulsePhase += 0.016 * pulseSpeed // ~60fps

        if pulsePhase > 1.0 {
            pulsePhase = 0
        }

        // Request redraw
        setNeedsDisplay()
    }

    deinit {
        stopPulseAnimation()
    }
}

// MARK: - Multi-Ring Accuracy Overlay

/// Shows multiple rings for detailed accuracy visualization
final class MultiRingAccuracyOverlay: NSObject, MKOverlay {

    let coordinate: CLLocationCoordinate2D
    var boundingMapRect: MKMapRect

    let innerRadius: CLLocationDistance // High confidence
    let middleRadius: CLLocationDistance // Medium confidence
    let outerRadius: CLLocationDistance // Full accuracy

    let memberId: String

    init(
        center: CLLocationCoordinate2D,
        accuracy: CLLocationDistance,
        memberId: String
    ) {
        self.coordinate = center
        self.memberId = memberId

        // Calculate ring radii based on accuracy
        self.innerRadius = accuracy * 0.3
        self.middleRadius = accuracy * 0.6
        self.outerRadius = accuracy

        // Calculate bounding rect
        let outerCircle = MKCircle(center: center, radius: outerRadius)
        self.boundingMapRect = outerCircle.boundingMapRect

        super.init()
    }
}

/// Renderer for multi-ring accuracy visualization
final class MultiRingAccuracyRenderer: MKOverlayRenderer {

    private let multiRingOverlay: MultiRingAccuracyOverlay
    private let memberColor: UIColor

    init(overlay: MultiRingAccuracyOverlay, memberColor: UIColor) {
        self.multiRingOverlay = overlay
        self.memberColor = memberColor
        super.init(overlay: overlay)
    }

    override func draw(_ mapRect: MKMapRect, zoomScale: MKZoomScale, in context: CGContext) {
        let center = point(for: MKMapPoint(multiRingOverlay.coordinate))

        // Draw rings from outer to inner
        drawRing(
            in: context,
            center: center,
            radius: multiRingOverlay.outerRadius,
            zoomScale: zoomScale,
            fillOpacity: 0.05,
            strokeOpacity: 0.3,
            dashPattern: true
        )

        drawRing(
            in: context,
            center: center,
            radius: multiRingOverlay.middleRadius,
            zoomScale: zoomScale,
            fillOpacity: 0.08,
            strokeOpacity: 0.4,
            dashPattern: false
        )

        drawRing(
            in: context,
            center: center,
            radius: multiRingOverlay.innerRadius,
            zoomScale: zoomScale,
            fillOpacity: 0.12,
            strokeOpacity: 0.6,
            dashPattern: false
        )

        // Draw center dot
        drawCenterDot(in: context, center: center, zoomScale: zoomScale)
    }

    private func drawRing(
        in context: CGContext,
        center: CGPoint,
        radius: CLLocationDistance,
        zoomScale: MKZoomScale,
        fillOpacity: CGFloat,
        strokeOpacity: CGFloat,
        dashPattern: Bool
    ) {
        // Convert radius from meters to points
        let radiusInPoints = radiusToPoints(radius, at: multiRingOverlay.coordinate, zoomScale: zoomScale)

        let rect = CGRect(
            x: center.x - radiusInPoints,
            y: center.y - radiusInPoints,
            width: radiusInPoints * 2,
            height: radiusInPoints * 2
        )

        // Fill
        context.setFillColor(memberColor.withAlphaComponent(fillOpacity).cgColor)
        context.fillEllipse(in: rect)

        // Stroke
        context.setStrokeColor(memberColor.withAlphaComponent(strokeOpacity).cgColor)
        context.setLineWidth(1.5 / zoomScale)

        if dashPattern {
            let dashLength: CGFloat = 6 / zoomScale
            context.setLineDash(phase: 0, lengths: [dashLength, dashLength / 2])
        } else {
            context.setLineDash(phase: 0, lengths: [])
        }

        context.strokeEllipse(in: rect)
    }

    private func drawCenterDot(in context: CGContext, center: CGPoint, zoomScale: MKZoomScale) {
        let dotRadius: CGFloat = 4 / zoomScale

        context.setFillColor(memberColor.cgColor)
        context.fillEllipse(in: CGRect(
            x: center.x - dotRadius,
            y: center.y - dotRadius,
            width: dotRadius * 2,
            height: dotRadius * 2
        ))

        // White border
        context.setStrokeColor(UIColor.white.cgColor)
        context.setLineWidth(1.5 / zoomScale)
        context.strokeEllipse(in: CGRect(
            x: center.x - dotRadius,
            y: center.y - dotRadius,
            width: dotRadius * 2,
            height: dotRadius * 2
        ))
    }

    private func radiusToPoints(
        _ meters: CLLocationDistance,
        at coordinate: CLLocationCoordinate2D,
        zoomScale: MKZoomScale
    ) -> CGFloat {
        let metersPerMapPoint = MKMetersPerMapPointAtLatitude(coordinate.latitude)
        let mapPointsRadius = meters / metersPerMapPoint
        return CGFloat(mapPointsRadius) * CGFloat(zoomScale)
    }
}

// MARK: - Animated Accuracy Update

extension MKMapView {

    /// Smoothly updates accuracy circle for a member
    func updateAccuracyCircle(
        for memberId: String,
        center: CLLocationCoordinate2D,
        newAccuracy: CLLocationDistance,
        memberColor: UIColor,
        animated: Bool = true
    ) {
        // Find existing overlay
        let existingOverlay = overlays.first { overlay in
            if let accuracyOverlay = overlay as? DynamicAccuracyCircleOverlay {
                return accuracyOverlay.memberId == memberId
            }
            return false
        }

        if animated, let existing = existingOverlay {
            // Animate transition
            UIView.animate(withDuration: 0.3) {
                self.removeOverlay(existing)
            } completion: { _ in
                let newOverlay = DynamicAccuracyCircleOverlay.create(
                    center: center,
                    accuracy: newAccuracy,
                    memberId: memberId,
                    memberColor: memberColor
                )
                self.addOverlay(newOverlay, level: .aboveLabels)
            }
        } else {
            // Immediate update
            if let existing = existingOverlay {
                removeOverlay(existing)
            }

            let newOverlay = DynamicAccuracyCircleOverlay.create(
                center: center,
                accuracy: newAccuracy,
                memberId: memberId,
                memberColor: memberColor
            )
            addOverlay(newOverlay, level: .aboveLabels)
        }
    }
}
