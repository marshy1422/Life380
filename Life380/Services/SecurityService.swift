import Foundation
import Security
import CryptoKit
import os.log

private let logger = Logger(subsystem: "com.life380.app", category: "Security")

// MARK: - Certificate Pinning

/// Delegate for certificate pinning on URLSession requests
class CertificatePinningDelegate: NSObject, URLSessionDelegate {
    // SHA256 fingerprints of pinned certificates
    // In production, add your actual certificate fingerprints here
    private let pinnedCertificates: Set<String> = [
        // Firebase/Google certificates (example - replace with actual)
        "E1A0F3D5C8B2A9876543210FEDCBA9876543210FEDCBA9876543210FEDCBA98",
        // Add more certificate hashes as needed
    ]

    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              let serverTrust = challenge.protectionSpace.serverTrust else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }

        // Validate the certificate chain
        var error: CFError?
        let isValid = SecTrustEvaluateWithError(serverTrust, &error)

        guard isValid else {
            logger.error("Certificate validation failed: \(error?.localizedDescription ?? "unknown")")
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }

        // Check if any certificate in the chain matches our pinned certificates
        guard let certificateChain = SecTrustCopyCertificateChain(serverTrust) as? [SecCertificate] else {
            logger.error("Could not get certificate chain")
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }

        for certificate in certificateChain {
            let certificateData = SecCertificateCopyData(certificate) as Data
            let hash = SHA256.hash(data: certificateData)
            let hashString = hash.compactMap { String(format: "%02X", $0) }.joined()

            if pinnedCertificates.contains(hashString) {
                logger.debug("Certificate pinning successful")
                completionHandler(.useCredential, URLCredential(trust: serverTrust))
                return
            }
        }

        // For development, allow all valid certificates
        // In production, you would return .cancelAuthenticationChallenge
        #if DEBUG
        logger.warning("Certificate not pinned - allowing in DEBUG mode")
        completionHandler(.useCredential, URLCredential(trust: serverTrust))
        #else
        logger.error("Certificate pinning failed - no matching certificate found")
        completionHandler(.cancelAuthenticationChallenge, nil)
        #endif
    }
}

// MARK: - Secure Storage

/// Service for securely storing sensitive data
class SecureStorageService {
    static let shared = SecureStorageService()

    private let keychainService = "com.life380.app"

    private init() {}

    // MARK: - Keychain Operations

    /// Store data securely in the keychain
    func store(data: Data, forKey key: String) -> Bool {
        // Delete existing item first
        delete(forKey: key)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]

        let status = SecItemAdd(query as CFDictionary, nil)

        if status != errSecSuccess {
            logger.error("Failed to store item in keychain: \(status)")
            return false
        }

        return true
    }

    /// Retrieve data from the keychain
    func retrieve(forKey key: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        if status == errSecSuccess {
            return result as? Data
        }

        if status != errSecItemNotFound {
            logger.error("Failed to retrieve from keychain: \(status)")
        }

        return nil
    }

    /// Delete data from the keychain
    @discardableResult
    func delete(forKey key: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: key
        ]

        let status = SecItemDelete(query as CFDictionary)

        return status == errSecSuccess || status == errSecItemNotFound
    }

    // MARK: - Convenience Methods

    func storeString(_ string: String, forKey key: String) -> Bool {
        guard let data = string.data(using: .utf8) else { return false }
        return store(data: data, forKey: key)
    }

    func retrieveString(forKey key: String) -> String? {
        guard let data = retrieve(forKey: key) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}

// MARK: - Location Cache Encryption

/// Encrypted storage for location data
class EncryptedLocationCache {
    static let shared = EncryptedLocationCache()

    private let cacheKey = "encrypted_location_cache"
    private var encryptionKey: SymmetricKey?

    private init() {
        encryptionKey = loadOrCreateEncryptionKey()
    }

    // MARK: - Key Management

    private func loadOrCreateEncryptionKey() -> SymmetricKey? {
        let keyIdentifier = "location_cache_key"

        // Try to load existing key from keychain
        if let keyData = SecureStorageService.shared.retrieve(forKey: keyIdentifier) {
            return SymmetricKey(data: keyData)
        }

        // Generate new key
        let newKey = SymmetricKey(size: .bits256)
        let keyData = newKey.withUnsafeBytes { Data($0) }

        if SecureStorageService.shared.store(data: keyData, forKey: keyIdentifier) {
            logger.info("Created new encryption key for location cache")
            return newKey
        }

        logger.error("Failed to store encryption key")
        return nil
    }

    // MARK: - Cache Operations

    /// Encrypt and store location data
    func cacheLocation(_ location: CachedLocation) {
        guard let key = encryptionKey else {
            logger.error("No encryption key available")
            return
        }

        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(location)

            let sealedBox = try AES.GCM.seal(data, using: key)
            guard let combined = sealedBox.combined else {
                logger.error("Failed to create sealed box")
                return
            }

            // Store in UserDefaults (encrypted)
            var cache = loadEncryptedCache()
            cache.append(combined)

            // Keep only last 100 locations
            if cache.count > 100 {
                cache = Array(cache.suffix(100))
            }

            saveEncryptedCache(cache)

        } catch {
            logger.error("Failed to encrypt location: \(error)")
        }
    }

    /// Retrieve and decrypt cached locations
    func getCachedLocations() -> [CachedLocation] {
        guard let key = encryptionKey else {
            logger.error("No encryption key available")
            return []
        }

        var locations: [CachedLocation] = []
        let cache = loadEncryptedCache()

        for encryptedData in cache {
            do {
                let sealedBox = try AES.GCM.SealedBox(combined: encryptedData)
                let decryptedData = try AES.GCM.open(sealedBox, using: key)

                let decoder = JSONDecoder()
                let location = try decoder.decode(CachedLocation.self, from: decryptedData)
                locations.append(location)
            } catch {
                logger.error("Failed to decrypt location: \(error)")
            }
        }

        return locations
    }

    /// Clear all cached locations
    func clearCache() {
        UserDefaults.standard.removeObject(forKey: cacheKey)
        logger.info("Location cache cleared")
    }

    // MARK: - Storage Helpers

    private func loadEncryptedCache() -> [Data] {
        guard let data = UserDefaults.standard.data(forKey: cacheKey),
              let cache = try? JSONDecoder().decode([Data].self, from: data) else {
            return []
        }
        return cache
    }

    private func saveEncryptedCache(_ cache: [Data]) {
        if let data = try? JSONEncoder().encode(cache) {
            UserDefaults.standard.set(data, forKey: cacheKey)
        }
    }
}

// MARK: - Cached Location Model

struct CachedLocation: Codable {
    let latitude: Double
    let longitude: Double
    let accuracy: Double
    let timestamp: Date
    let source: String

    init(latitude: Double, longitude: Double, accuracy: Double, timestamp: Date = Date(), source: String = "unknown") {
        self.latitude = latitude
        self.longitude = longitude
        self.accuracy = accuracy
        self.timestamp = timestamp
        self.source = source
    }
}

// MARK: - API Security

/// Security utilities for API requests
struct APISecurityHelper {
    /// Generate a secure request signature
    static func generateRequestSignature(
        method: String,
        path: String,
        timestamp: Date,
        body: Data? = nil
    ) -> String {
        let timestampString = String(Int(timestamp.timeIntervalSince1970))
        let bodyHash = body.map { SHA256.hash(data: $0).compactMap { String(format: "%02x", $0) }.joined() } ?? ""

        let signatureBase = "\(method)|\(path)|\(timestampString)|\(bodyHash)"
        let signature = SHA256.hash(data: Data(signatureBase.utf8))

        return signature.compactMap { String(format: "%02x", $0) }.joined()
    }

    /// Validate a response timestamp to prevent replay attacks
    static func isTimestampValid(_ timestamp: Date, maxAge: TimeInterval = 300) -> Bool {
        abs(timestamp.timeIntervalSinceNow) < maxAge
    }
}
