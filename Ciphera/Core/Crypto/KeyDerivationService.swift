import Foundation
import CryptoKit
import Security

enum KeyDerivationError: LocalizedError {
    case randomGenerationFailed
    case weakSecret

    var errorDescription: String? {
        switch self {
        case .randomGenerationFailed:
            return "Could not create secure random data."
        case .weakSecret:
            return "Use at least 8 characters for the encryption secret."
        }
    }
}

struct KeyDerivationService {
    static let hkdfSaltLabel = "Ciphera.hkdf.secret.v1"
    static let hkdfInfoLabel = "portable-content-encryption"

    static func randomSalt(byteCount: Int = 32) throws -> Data {
        var bytes = [UInt8](repeating: 0, count: byteCount)
        let status = SecRandomCopyBytes(kSecRandomDefault, byteCount, &bytes)
        guard status == errSecSuccess else {
            throw KeyDerivationError.randomGenerationFailed
        }
        return Data(bytes)
    }

    /// Current learning KDF used by Ciphera secret mode.
    /// secret || salt -> SHA-256 -> HKDF-SHA256 -> 256-bit AEAD key.
    static func personalEncryptionKey(secret: String, salt: Data) throws -> SymmetricKey {
        guard secret.count >= 8 else { throw KeyDerivationError.weakSecret }

        var material = Data(secret.utf8)
        material.append(salt)
        let digest = SHA256.hash(data: material)
        let root = SymmetricKey(data: Data(digest))

        return HKDF<SHA256>.deriveKey(
            inputKeyMaterial: root,
            salt: Data(hkdfSaltLabel.utf8),
            info: Data(hkdfInfoLabel.utf8),
            outputByteCount: 32
        )
    }

    static func legacyPersonalEncryptionKey(secret: String, salt: Data) throws -> SymmetricKey {
        try personalEncryptionKey(secret: secret, salt: salt)
    }
}
