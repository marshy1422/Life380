import UIKit
import MapKit

// MARK: - Modern Member Annotation View
// Sleek, modern design with speed indicator for driving

/// Custom annotation view for family members with avatar and speed indicator
final class MemberAnnotationView: MKAnnotationView {
    static let reuseIdentifier = "MemberAnnotationView"

    // MARK: - UI Components

    private let outerRingLayer = CAShapeLayer()
    private let containerView = UIView()
    private let avatarImageView = UIImageView()
    private let initialsLabel = UILabel()
    private let statusIndicator = UIView()
    private let pulseLayer = CAShapeLayer()
    private let nameLabel = PaddedLabel()
    private let speedBadge = SpeedBadgeView()

    // MARK: - Configuration

    private var isConfiguredForSelection = false
    private var currentMemberId: String?

    // Size configuration - slightly larger for modern look
    private let normalSize: CGFloat = 48
    private let selectedSize: CGFloat = 60
    private let statusSize: CGFloat = 12
    private let borderWidth: CGFloat = 3

    // MARK: - Initialization

    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        setupViews()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setupViews()
    }

    private func setupViews() {
        canShowCallout = false
        isDraggable = false

        // Pulse layer (behind everything)
        pulseLayer.fillColor = UIColor.clear.cgColor
        layer.insertSublayer(pulseLayer, at: 0)

        // Outer gradient ring
        outerRingLayer.fillColor = UIColor.clear.cgColor
        outerRingLayer.lineWidth = borderWidth
        layer.addSublayer(outerRingLayer)

        // Main container with subtle shadow
        containerView.backgroundColor = .white
        containerView.layer.cornerRadius = normalSize / 2
        containerView.layer.shadowColor = UIColor.black.cgColor
        containerView.layer.shadowOffset = CGSize(width: 0, height: 2)
        containerView.layer.shadowRadius = 6
        containerView.layer.shadowOpacity = 0.15
        addSubview(containerView)

        // Avatar image
        avatarImageView.contentMode = .scaleAspectFill
        avatarImageView.clipsToBounds = true
        avatarImageView.isHidden = true
        containerView.addSubview(avatarImageView)

        // Initials label
        initialsLabel.textAlignment = .center
        initialsLabel.font = .systemFont(ofSize: 18, weight: .semibold)
        initialsLabel.textColor = .white
        containerView.addSubview(initialsLabel)

        // Status indicator - small ring style
        statusIndicator.layer.cornerRadius = statusSize / 2
        statusIndicator.layer.borderWidth = 2.5
        statusIndicator.layer.borderColor = UIColor.white.cgColor
        addSubview(statusIndicator)

        // Name label - modern pill shape
        nameLabel.font = .systemFont(ofSize: 11, weight: .semibold)
        nameLabel.textColor = .white
        nameLabel.backgroundColor = UIColor.black.withAlphaComponent(0.75)
        nameLabel.layer.cornerRadius = 10
        nameLabel.layer.masksToBounds = true
        nameLabel.textAlignment = .center
        nameLabel.isHidden = true
        addSubview(nameLabel)

        // Speed badge - only visible when driving
        speedBadge.isHidden = true
        addSubview(speedBadge)

        // Set initial frame
        frame = CGRect(x: 0, y: 0, width: normalSize, height: normalSize)
        centerOffset = CGPoint(x: 0, y: -normalSize / 2)
    }

    // MARK: - Configuration

    func configure(with member: UserProfile, isSelected: Bool) {
        let needsFullUpdate = currentMemberId != member.id
        currentMemberId = member.id

        let size = isSelected ? selectedSize : normalSize
        updateSize(size, animated: !needsFullUpdate && isConfiguredForSelection != isSelected)
        isConfiguredForSelection = isSelected

        configureAvatar(member: member, size: size)
        configureRing(member: member, size: size)
        configureStatus(member: member, size: size)
        configureName(member: member, isSelected: isSelected, size: size)
        configureSpeed(member: member, size: size)

        if isSelected && !member.isStale {
            startPulseAnimation(color: member.memberColor)
        } else {
            stopPulseAnimation()
        }
    }

    private func configureAvatar(member: UserProfile, size: CGFloat) {
        let padding: CGFloat = borderWidth + 2
        let innerSize = size - (padding * 2)

        containerView.frame = CGRect(x: padding, y: padding, width: innerSize, height: innerSize)
        containerView.layer.cornerRadius = innerSize / 2

        let avatarInset: CGFloat = 2
        let avatarSize = innerSize - (avatarInset * 2)
        avatarImageView.frame = CGRect(x: avatarInset, y: avatarInset, width: avatarSize, height: avatarSize)
        avatarImageView.layer.cornerRadius = avatarSize / 2

        initialsLabel.frame = containerView.bounds

        // Background is member's color
        containerView.backgroundColor = member.memberColor

        if let photoURL = member.photoURL, !photoURL.isEmpty {
            loadImage(from: photoURL)
            avatarImageView.isHidden = false
            initialsLabel.isHidden = true
        } else {
            avatarImageView.isHidden = true
            initialsLabel.isHidden = false
            initialsLabel.text = member.initials
            initialsLabel.font = .systemFont(ofSize: isConfiguredForSelection ? 22 : 18, weight: .semibold)
        }
    }

    private func configureRing(member: UserProfile, size: CGFloat) {
        let ringRect = CGRect(x: borderWidth / 2, y: borderWidth / 2,
                              width: size - borderWidth, height: size - borderWidth)
        outerRingLayer.path = UIBezierPath(ovalIn: ringRect).cgPath

        // Ring color based on status
        if member.isStale {
            outerRingLayer.strokeColor = UIColor.systemGray.withAlphaComponent(0.6).cgColor
        } else if member.isDriving {
            outerRingLayer.strokeColor = UIColor.systemBlue.cgColor
        } else {
            outerRingLayer.strokeColor = member.memberColor.withAlphaComponent(0.8).cgColor
        }
    }

    private func configureStatus(member: UserProfile, size: CGFloat) {
        // Position at bottom-right of the avatar
        let statusX = size - statusSize - 2
        let statusY = size - statusSize - 2
        statusIndicator.frame = CGRect(x: statusX, y: statusY, width: statusSize, height: statusSize)

        // Color based on status
        if member.isStale {
            statusIndicator.backgroundColor = .systemGray
        } else if member.isLocationSharing {
            statusIndicator.backgroundColor = .systemGreen
        } else {
            statusIndicator.backgroundColor = .systemOrange
        }
    }

    private func configureName(member: UserProfile, isSelected: Bool, size: CGFloat) {
        nameLabel.isHidden = !isSelected
        guard isSelected else { return }

        nameLabel.text = member.displayName
        nameLabel.sizeToFit()

        let labelWidth = nameLabel.bounds.width + 16
        let labelHeight: CGFloat = 20

        nameLabel.frame = CGRect(
            x: (size / 2) - (labelWidth / 2) + (borderWidth + 2),
            y: size + 6,
            width: labelWidth,
            height: labelHeight
        )
    }

    private func configureSpeed(member: UserProfile, size: CGFloat) {
        // Only show speed when driving (in km/h for Australia)
        guard member.isDriving, let speedKMH = member.speedKMH, speedKMH > 5 else {
            speedBadge.isHidden = true
            return
        }

        speedBadge.isHidden = false
        speedBadge.configure(speed: speedKMH)

        // Position above the avatar
        let badgeWidth: CGFloat = speedBadge.intrinsicWidth
        let badgeHeight: CGFloat = 20
        speedBadge.frame = CGRect(
            x: (size / 2) - (badgeWidth / 2) + (borderWidth + 2),
            y: -badgeHeight - 4,
            width: badgeWidth,
            height: badgeHeight
        )
    }

    private func updateSize(_ size: CGFloat, animated: Bool) {
        let totalWidth = size + (borderWidth * 2) + 4
        let totalHeight = size + 60 // Extra for name label
        let newFrame = CGRect(x: 0, y: 0, width: totalWidth, height: totalHeight)
        centerOffset = CGPoint(x: 0, y: -(size + borderWidth * 2) / 2)

        if animated {
            UIView.animate(withDuration: 0.25, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.5) {
                self.frame = newFrame
            }
        } else {
            frame = newFrame
        }
    }

    // MARK: - Image Loading

    private func loadImage(from urlString: String) {
        guard let url = URL(string: urlString) else { return }

        URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            guard let data = data, let image = UIImage(data: data) else { return }
            DispatchQueue.main.async {
                self?.avatarImageView.image = image
            }
        }.resume()
    }

    // MARK: - Pulse Animation

    private func startPulseAnimation(color: UIColor) {
        let size = isConfiguredForSelection ? selectedSize : normalSize
        let pulseSize = size * 2

        let centerX = (size + (borderWidth * 2) + 4) / 2
        let centerY = (size + (borderWidth * 2)) / 2

        let path = UIBezierPath(
            ovalIn: CGRect(
                x: centerX - pulseSize / 2,
                y: centerY - pulseSize / 2,
                width: pulseSize,
                height: pulseSize
            )
        )
        pulseLayer.path = path.cgPath
        pulseLayer.fillColor = color.withAlphaComponent(0.25).cgColor

        let scaleAnimation = CABasicAnimation(keyPath: "transform.scale")
        scaleAnimation.fromValue = 0.5
        scaleAnimation.toValue = 1.2

        let opacityAnimation = CABasicAnimation(keyPath: "opacity")
        opacityAnimation.fromValue = 0.7
        opacityAnimation.toValue = 0

        let group = CAAnimationGroup()
        group.animations = [scaleAnimation, opacityAnimation]
        group.duration = 1.8
        group.repeatCount = .infinity
        group.timingFunction = CAMediaTimingFunction(name: .easeOut)

        pulseLayer.add(group, forKey: "pulse")
        pulseLayer.isHidden = false
    }

    private func stopPulseAnimation() {
        pulseLayer.removeAllAnimations()
        pulseLayer.isHidden = true
    }

    // MARK: - Reuse

    override func prepareForReuse() {
        super.prepareForReuse()
        stopPulseAnimation()
        avatarImageView.image = nil
        currentMemberId = nil
        isConfiguredForSelection = false
        nameLabel.isHidden = true
        speedBadge.isHidden = true
    }
}

// MARK: - Speed Badge View

final class SpeedBadgeView: UIView {
    private let iconView = UIImageView()
    private let speedLabel = UILabel()

    var intrinsicWidth: CGFloat {
        speedLabel.sizeToFit()
        return speedLabel.bounds.width + 28 // icon + padding
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }

    private func setupView() {
        backgroundColor = UIColor.systemBlue
        layer.cornerRadius = 10
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOffset = CGSize(width: 0, height: 1)
        layer.shadowRadius = 2
        layer.shadowOpacity = 0.2

        // Car icon
        let config = UIImage.SymbolConfiguration(pointSize: 10, weight: .semibold)
        iconView.image = UIImage(systemName: "car.fill", withConfiguration: config)
        iconView.tintColor = .white
        iconView.contentMode = .scaleAspectFit
        addSubview(iconView)

        // Speed label
        speedLabel.font = .systemFont(ofSize: 11, weight: .bold)
        speedLabel.textColor = .white
        addSubview(speedLabel)
    }

    func configure(speed: Int) {
        speedLabel.text = "\(speed)"
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        iconView.frame = CGRect(x: 6, y: 4, width: 12, height: 12)
        speedLabel.sizeToFit()
        speedLabel.frame = CGRect(x: 20, y: 3, width: speedLabel.bounds.width, height: 14)
    }
}

// MARK: - Padded Label

final class PaddedLabel: UILabel {
    var padding = UIEdgeInsets(top: 4, left: 8, bottom: 4, right: 8)

    override var intrinsicContentSize: CGSize {
        let size = super.intrinsicContentSize
        return CGSize(width: size.width + padding.left + padding.right,
                      height: size.height + padding.top + padding.bottom)
    }

    override func drawText(in rect: CGRect) {
        super.drawText(in: rect.inset(by: padding))
    }
}

// MARK: - UserProfile Extension for Annotation

extension UserProfile {
    var memberColor: UIColor {
        let hash = id.hashValue
        let hue = CGFloat(abs(hash) % 360) / 360.0
        return UIColor(hue: hue, saturation: 0.55, brightness: 0.85, alpha: 1.0)
    }

    var isStale: Bool {
        Date().timeIntervalSince(lastUpdated) > 300 // 5 minutes
    }
}

// MARK: - LocationConfidence UIColor Extension

extension LocationConfidence {
    var uiColor: UIColor {
        switch self {
        case .excellent: return .systemGreen
        case .high: return .systemBlue
        case .medium: return .systemTeal
        case .low: return .systemOrange
        case .approximate: return .systemRed
        }
    }
}
