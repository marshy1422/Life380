import Foundation

extension String {
    // MARK: - Validation

    /// Whether the string is a valid email address
    var isValidEmail: Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let predicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return predicate.evaluate(with: self)
    }

    /// Whether the string meets minimum password requirements
    var isValidPassword: Bool {
        count >= 8
    }

    /// Whether the string is a valid invite code (6 characters alphanumeric)
    var isValidInviteCode: Bool {
        let trimmed = trimmingCharacters(in: .whitespaces)
        return trimmed.count == 6 &&
               trimmed.allSatisfy { $0.isLetter || $0.isNumber }
    }

    // MARK: - Initials

    /// Returns initials from a name (e.g., "John Doe" -> "JD")
    var initials: String {
        let components = split(separator: " ")
        if components.count >= 2 {
            return String(components[0].prefix(1) + components[1].prefix(1)).uppercased()
        }
        return String(prefix(2)).uppercased()
    }

    // MARK: - Formatting

    /// Trims whitespace and newlines
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Capitalizes the first letter only
    var capitalizedFirst: String {
        guard let first = first else { return self }
        return first.uppercased() + dropFirst()
    }

    // MARK: - Masking

    /// Masks an email address for privacy (e.g., "j***@example.com")
    var maskedEmail: String {
        guard let atIndex = firstIndex(of: "@") else { return self }
        let username = String(prefix(upTo: atIndex))
        let domain = String(suffix(from: atIndex))

        if username.count <= 2 {
            return username + "***" + domain
        }

        let visiblePart = String(username.prefix(1))
        return visiblePart + String(repeating: "*", count: min(username.count - 1, 5)) + domain
    }

    // MARK: - Phone Number

    /// Formats a phone number for display (basic formatting)
    var formattedPhoneNumber: String {
        let digits = filter { $0.isNumber }
        guard digits.count == 10 else { return self }

        let areaCode = String(digits.prefix(3))
        let middle = String(digits.dropFirst(3).prefix(3))
        let last = String(digits.suffix(4))

        return "(\(areaCode)) \(middle)-\(last)"
    }

    // MARK: - Empty Check

    /// Whether the string is empty or contains only whitespace
    var isBlank: Bool {
        trimmed.isEmpty
    }

    /// Returns nil if the string is blank, otherwise returns self
    var nilIfBlank: String? {
        isBlank ? nil : self
    }
}
