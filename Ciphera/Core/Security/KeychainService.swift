import Foundation
import Security
import CryptoKit

enum KeychainServiceError: LocalizedError {
    case unexpectedStatus(OSStatus)
    case invalidStoredKey
    case invalidImportedKey

    var errorDescription: String? {
        switch self {
        case .unexpectedStatus(let status): return "Keychain error: \(status)."
        case .invalidStoredKey: return "The stored private key could not be read."
        case .invalidImportedKey: return "That does not look like a valid Ciphera private key."
        }
    }
}

struct KeychainService {
    private static let service = "Ciphera.Keys"

    // MARK: Key agreement identities

    static func agreementPrivateKeyData(for curve: PublicKeyCurve) throws -> Data {
        let account = "agreement.\(curve.rawValue).private.v1"
        if let existing = try read(account: account) { return existing }

        let data: Data
        switch curve {
        case .curve25519: data = Curve25519.KeyAgreement.PrivateKey().rawRepresentation
        case .p256: data = P256.KeyAgreement.PrivateKey().rawRepresentation
        case .p384: data = P384.KeyAgreement.PrivateKey().rawRepresentation
        case .p521: data = P521.KeyAgreement.PrivateKey().rawRepresentation
        }
        try save(data, account: account)
        return data
    }

    static func resetAgreementPrivateKey(for curve: PublicKeyCurve) throws -> Data {
        let account = "agreement.\(curve.rawValue).private.v1"
        try delete(account: account, ignoreMissing: true)
        return try agreementPrivateKeyData(for: curve)
    }

    static func importAgreementPrivateKey(_ data: Data, curve: PublicKeyCurve) throws {
        // Validate before storing.
        do {
            switch curve {
            case .curve25519: _ = try Curve25519.KeyAgreement.PrivateKey(rawRepresentation: data)
            case .p256: _ = try P256.KeyAgreement.PrivateKey(rawRepresentation: data)
            case .p384: _ = try P384.KeyAgreement.PrivateKey(rawRepresentation: data)
            case .p521: _ = try P521.KeyAgreement.PrivateKey(rawRepresentation: data)
            }
        } catch {
            throw KeychainServiceError.invalidImportedKey
        }
        try save(data, account: "agreement.\(curve.rawValue).private.v1")
    }

    // Legacy Curve25519 API used by older views/messages.
    static func recipientPrivateKey() throws -> Curve25519.KeyAgreement.PrivateKey {
        let data = try agreementPrivateKeyData(for: .curve25519)
        do { return try Curve25519.KeyAgreement.PrivateKey(rawRepresentation: data) }
        catch { throw KeychainServiceError.invalidStoredKey }
    }

    static func resetRecipientKeyPair() throws -> Curve25519.KeyAgreement.PrivateKey {
        let data = try resetAgreementPrivateKey(for: .curve25519)
        return try Curve25519.KeyAgreement.PrivateKey(rawRepresentation: data)
    }

    static func exportRecipientPrivateKey() throws -> Data {
        try agreementPrivateKeyData(for: .curve25519)
    }

    @discardableResult
    static func importRecipientPrivateKey(_ data: Data) throws -> Curve25519.KeyAgreement.PrivateKey {
        try importAgreementPrivateKey(data, curve: .curve25519)
        return try Curve25519.KeyAgreement.PrivateKey(rawRepresentation: data)
    }

    // MARK: Signing identities

    static func signingPrivateKeyData(for algorithm: SigningAlgorithm) throws -> Data {
        let account = "signing.\(algorithm.rawValue).private.v1"
        if let existing = try read(account: account) { return existing }

        let data: Data
        switch algorithm {
        case .ed25519: data = Curve25519.Signing.PrivateKey().rawRepresentation
        case .p256: data = P256.Signing.PrivateKey().rawRepresentation
        case .p384: data = P384.Signing.PrivateKey().rawRepresentation
        case .p521: data = P521.Signing.PrivateKey().rawRepresentation
        }
        try save(data, account: account)
        return data
    }

    static func resetSigningPrivateKey(for algorithm: SigningAlgorithm) throws -> Data {
        let account = "signing.\(algorithm.rawValue).private.v1"
        try delete(account: account, ignoreMissing: true)
        return try signingPrivateKeyData(for: algorithm)
    }

    // MARK: Generic storage

    private static func save(_ data: Data, account: String) throws {
        try delete(account: account, ignoreMissing: true)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else { throw KeychainServiceError.unexpectedStatus(status) }
    }

    private static func read(account: String) throws -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data else {
            throw KeychainServiceError.unexpectedStatus(status)
        }
        return data
    }

    private static func delete(account: String, ignoreMissing: Bool = false) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let status = SecItemDelete(query as CFDictionary)
        if status == errSecItemNotFound, ignoreMissing { return }
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainServiceError.unexpectedStatus(status)
        }
    }
}
