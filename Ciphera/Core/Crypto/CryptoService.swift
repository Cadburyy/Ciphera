import Foundation
import CryptoKit

enum CryptoServiceError: LocalizedError {
    case invalidPayload
    case invalidBase64
    case decryptionFailed
    case unsupportedAlgorithm
    case invalidPublicKey
    case wrongRecipient
    case unsupportedKDF
    case invalidPrivateBackup
    case invalidSignature
    case signatureContentRequired
    case fileTooLarge

    var errorDescription: String? {
        switch self {
        case .invalidPayload: return "This does not look like a valid Ciphera message."
        case .invalidBase64: return "The encrypted data contains invalid Base64 data."
        case .decryptionFailed: return "Decryption failed. Check the encrypted data and the secret or recipient key."
        case .unsupportedAlgorithm: return "This Ciphera item uses an unsupported algorithm."
        case .invalidPublicKey: return "The recipient public key is invalid."
        case .wrongRecipient: return "This item was not encrypted for the private key stored on this iPhone."
        case .unsupportedKDF: return "This Ciphera item uses an unsupported key-derivation method."
        case .invalidPrivateBackup: return "This does not look like a valid Ciphera private-key backup."
        case .invalidSignature: return "The signature package is invalid."
        case .signatureContentRequired: return "This older signature does not contain its original content. Enter the content that was originally signed."
        case .fileTooLarge: return "This prototype currently supports files up to 20 MB."
        }
    }
}

enum ProtectionMode: String, Codable, CaseIterable, Identifiable {
    case secret
    case recipient
    var id: String { rawValue }
    var title: String { self == .secret ? "With a Secret" : "For Someone" }
    var subtitle: String {
        self == .secret ? "Anyone with the same secret can decrypt it." : "Only the owner of the matching private key can decrypt it."
    }
}

enum SymmetricCipher: String, Codable, CaseIterable, Identifiable {
    case aes256GCM = "AES-256-GCM"
    case chaCha20Poly1305 = "ChaCha20-Poly1305"
    var id: String { rawValue }
    var title: String { rawValue }
    var shortDescription: String {
        switch self {
        case .aes256GCM: return "Widely used authenticated encryption and a strong default on Apple devices."
        case .chaCha20Poly1305: return "A modern authenticated stream cipher and an alternative to AES."
        }
    }
}

enum PublicKeyCurve: String, Codable, CaseIterable, Identifiable {
    case curve25519 = "Curve25519"
    case p256 = "P-256"
    case p384 = "P-384"
    case p521 = "P-521"
    var id: String { rawValue }
    var title: String { rawValue }
    var shortDescription: String {
        switch self {
        case .curve25519: return "Modern X25519 key agreement and Ciphera's default."
        case .p256: return "NIST P-256 elliptic-curve key agreement."
        case .p384: return "NIST P-384 elliptic-curve key agreement."
        case .p521: return "NIST P-521 elliptic-curve key agreement."
        }
    }
}

enum SigningAlgorithm: String, Codable, CaseIterable, Identifiable {
    case ed25519 = "Ed25519"
    case p256 = "P-256 ECDSA"
    case p384 = "P-384 ECDSA"
    case p521 = "P-521 ECDSA"
    var id: String { rawValue }
    var title: String { rawValue }
}

struct CipheraMessageInfo {
    let mode: ProtectionMode
    let algorithm: SymmetricCipher
}

struct CipheraMessageDetails: Identifiable, Hashable {
    let id = UUID()
    let version: Int
    let mode: ProtectionMode
    let algorithm: SymmetricCipher
    let kdf: String
    let salt: String?
    let nonce: String
    let tag: String
    let ephemeralPublicKey: String?
    let recipientKeyID: String?
    let keyAgreement: PublicKeyCurve?
    var protectionTitle: String { mode == .secret ? "With a Secret" : "For Someone · \((keyAgreement ?? .curve25519).title)" }
}

struct CryptoService {
    private static let prefix = "CP1:"
    private static let publicKeyPrefix = "CP-PUB1:"
    private static let publicKeyV2Prefix = "CP-PUB2:"
    private static let privateKeyPrefix = "CP-PRIV1:"
    private static let protectedPrivateKeyPrefix = "CP-PRIV2:"
    private static let signaturePrefix = "CP-SIG1:"
    private static let fileMagic = "CPFILE1"
    private static let filePrefix = "CPFILE1:"
    private static let currentSecretKDF = "SHA256+HKDF-SHA256-learning-only"

    private struct Payload: Codable {
        let version: Int
        let mode: ProtectionMode
        let algorithm: SymmetricCipher
        let kdf: String?
        let salt: String?
        let keyAgreement: PublicKeyCurve?
        let ephemeralPublicKey: String?
        let recipientKeyID: String?
        let nonce: String
        let ciphertext: String
        let tag: String
    }

    private struct PublicKeyPayload: Codable {
        let version: Int
        let curve: PublicKeyCurve
        let key: String
    }

    private struct PrivateBackupPayload: Codable {
        let version: Int
        let kdf: String
        let salt: String
        let nonce: String
        let ciphertext: String
        let tag: String
    }

    private struct SignaturePayload: Codable {
        let version: Int
        let algorithm: SigningAlgorithm
        let publicKey: String
        let signature: String
        let content: String?
        let autographDrawing: String?
        let createdAt: String?
        let createdUsing: String?
        let signerFingerprint: String?
        let contentSHA256: String?
        let autographSHA256: String?
    }

    private struct SignatureSignedMaterial: Codable {
        let version: Int
        let algorithm: SigningAlgorithm
        let publicKey: String
        let content: String
        let autographDrawing: String?
        let createdAt: String
        let createdUsing: String
        let signerFingerprint: String
        let contentSHA256: String
        let autographSHA256: String?
    }

    private struct SignatureDetailsExport: Codable {
        let format: String
        let version: Int
        let message: String?
        let createdAt: String?
        let createdUsing: String?
        let algorithm: SigningAlgorithm
        let signerFingerprint: String?
        let contentSHA256: String?
        let autographSHA256: String?
        let hasAutograph: Bool
        let publicKey: String
        let digitalSignature: String
        let signedPackage: String
    }

    private struct FilePayload: Codable {
        let magic: String
        let version: Int
        let originalFilename: String
        let contentType: String?
        let mode: ProtectionMode
        let algorithm: SymmetricCipher
        let kdf: String
        let salt: String?
        let keyAgreement: PublicKeyCurve?
        let ephemeralPublicKey: String?
        let recipientKeyID: String?
        let nonce: String
        let ciphertext: String
        let tag: String
    }

    // MARK: Secret text encryption

    static func encryptWithSecret(_ plaintext: String, secret: String, algorithm: SymmetricCipher) throws -> String {
        let salt = try KeyDerivationService.randomSalt()
        let key = try KeyDerivationService.personalEncryptionKey(secret: secret, salt: salt)
        let sealed = try seal(Data(plaintext.utf8), using: key, algorithm: algorithm)
        return try encode(Payload(
            version: 1, mode: .secret, algorithm: algorithm, kdf: currentSecretKDF,
            salt: salt.base64EncodedString(), keyAgreement: nil, ephemeralPublicKey: nil, recipientKeyID: nil,
            nonce: sealed.nonce.base64EncodedString(), ciphertext: sealed.ciphertext.base64EncodedString(), tag: sealed.tag.base64EncodedString()
        ))
    }

    static func decryptWithSecret(_ encryptedText: String, secret: String) throws -> String {
        let payload = try decode(encryptedText)
        guard payload.mode == .secret,
              let saltText = payload.salt,
              let salt = Data(base64Encoded: saltText) else { throw CryptoServiceError.invalidPayload }
        guard payload.kdf == nil || payload.kdf == currentSecretKDF else { throw CryptoServiceError.unsupportedKDF }
        let key = try KeyDerivationService.personalEncryptionKey(secret: secret, salt: salt)
        return try open(payload: payload, using: key)
    }

    // MARK: Recipient text encryption

    static func encryptForRecipient(_ plaintext: String, recipientPublicKeyText: String, algorithm: SymmetricCipher) throws -> String {
        let parsed = try parsePublicKey(recipientPublicKeyText)
        let material = try recipientEncryptionMaterial(for: parsed)
        let sealed = try seal(Data(plaintext.utf8), using: material.key, algorithm: algorithm)
        return try encode(Payload(
            version: 1, mode: .recipient, algorithm: algorithm,
            kdf: "\(parsed.curve.title)+HKDF-SHA256", salt: nil, keyAgreement: parsed.curve,
            ephemeralPublicKey: material.ephemeralPublicKey.base64EncodedString(),
            recipientKeyID: keyID(for: parsed.raw, curve: parsed.curve),
            nonce: sealed.nonce.base64EncodedString(), ciphertext: sealed.ciphertext.base64EncodedString(), tag: sealed.tag.base64EncodedString()
        ))
    }

    static func decryptForMe(_ encryptedText: String) throws -> String {
        let payload = try decode(encryptedText)
        guard payload.mode == .recipient,
              let ephemeralText = payload.ephemeralPublicKey,
              let ephemeralData = Data(base64Encoded: ephemeralText) else { throw CryptoServiceError.invalidPayload }
        let curve = payload.keyAgreement ?? .curve25519
        let privateData = try KeychainService.agreementPrivateKeyData(for: curve)
        let publicData = try publicKeyData(fromPrivateKeyData: privateData, curve: curve)
        if let expectedID = payload.recipientKeyID, expectedID != keyID(for: publicData, curve: curve) {
            throw CryptoServiceError.wrongRecipient
        }
        let key = try recipientDecryptionKey(privateData: privateData, ephemeralPublicData: ephemeralData, curve: curve)
        return try open(payload: payload, using: key)
    }

    /// Opens a recipient-mode message with an explicitly supplied tutorial key.
    /// This deliberately bypasses Keychain so guided lessons never touch the
    /// person's real Ciphera identity.
    static func decryptForTutorialRecipient(_ encryptedText: String, privateKeyData: Data) throws -> String {
        let payload = try decode(encryptedText)
        guard payload.mode == .recipient,
              let ephemeralText = payload.ephemeralPublicKey,
              let ephemeralData = Data(base64Encoded: ephemeralText) else {
            throw CryptoServiceError.invalidPayload
        }
        let privateKey = try Curve25519.KeyAgreement.PrivateKey(rawRepresentation: privateKeyData)
        if let expectedID = payload.recipientKeyID,
           expectedID != keyID(for: privateKey.publicKey.rawRepresentation, curve: .curve25519) {
            throw CryptoServiceError.wrongRecipient
        }
        let key = try recipientDecryptionKey(
            privateData: privateKeyData,
            ephemeralPublicData: ephemeralData,
            curve: .curve25519
        )
        return try open(payload: payload, using: key)
    }

    // MARK: Public/private key helpers

    static func myPublicKeyText() throws -> String { try myPublicKeyText(curve: .curve25519) }

    static func myPublicKeyText(curve: PublicKeyCurve) throws -> String {
        let privateData = try KeychainService.agreementPrivateKeyData(for: curve)
        let publicData = try publicKeyData(fromPrivateKeyData: privateData, curve: curve)
        if curve == .curve25519 { return publicKeyPrefix + publicData.base64EncodedString() }
        let payload = PublicKeyPayload(version: 2, curve: curve, key: publicData.base64EncodedString())
        let encoded = try JSONEncoder().encode(payload).base64EncodedString()
        return publicKeyV2Prefix + encoded
    }

    static func myKeyFingerprint() throws -> String { try myKeyFingerprint(curve: .curve25519) }

    static func myKeyFingerprint(curve: PublicKeyCurve) throws -> String {
        let privateData = try KeychainService.agreementPrivateKeyData(for: curve)
        let publicData = try publicKeyData(fromPrivateKeyData: privateData, curve: curve)
        return fingerprint(for: publicData, label: curve.rawValue)
    }

    static func fingerprint(forPublicKeyText text: String) throws -> String {
        let parsed = try parsePublicKey(text)
        return fingerprint(for: parsed.raw, label: parsed.curve.rawValue)
    }

    static func resetMyKeyPair() throws -> String {
        _ = try KeychainService.resetAgreementPrivateKey(for: .curve25519)
        return try myPublicKeyText()
    }

    static func resetMyKeyPair(curve: PublicKeyCurve) throws -> String {
        _ = try KeychainService.resetAgreementPrivateKey(for: curve)
        return try myPublicKeyText(curve: curve)
    }

    static func exportMyPrivateKeyText() throws -> String {
        let data = try KeychainService.exportRecipientPrivateKey()
        return privateKeyPrefix + data.base64EncodedString()
    }

    static func importMyPrivateKeyText(_ text: String) throws -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix(privateKeyPrefix) else { throw KeychainServiceError.invalidImportedKey }
        let encoded = String(trimmed.dropFirst(privateKeyPrefix.count))
        guard let data = Data(base64Encoded: encoded) else { throw KeychainServiceError.invalidImportedKey }
        _ = try KeychainService.importRecipientPrivateKey(data)
        return try myPublicKeyText()
    }

    static func exportProtectedPrivateKeyText(secret: String) throws -> String {
        let privateKeyData = try KeychainService.exportRecipientPrivateKey()
        let salt = try KeyDerivationService.randomSalt()
        let key = try KeyDerivationService.personalEncryptionKey(secret: secret, salt: salt)
        let box = try AES.GCM.seal(privateKeyData, using: key)
        let payload = PrivateBackupPayload(
            version: 1, kdf: currentSecretKDF, salt: salt.base64EncodedString(),
            nonce: Data(box.nonce).base64EncodedString(), ciphertext: box.ciphertext.base64EncodedString(), tag: box.tag.base64EncodedString()
        )
        let encoded = try JSONEncoder().encode(payload).base64EncodedString()
        return protectedPrivateKeyPrefix + encoded
    }

    static func importProtectedPrivateKeyText(_ text: String, secret: String) throws -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix(protectedPrivateKeyPrefix),
              let data = Data(base64Encoded: String(trimmed.dropFirst(protectedPrivateKeyPrefix.count))),
              let payload = try? JSONDecoder().decode(PrivateBackupPayload.self, from: data),
              payload.version == 1, payload.kdf == currentSecretKDF,
              let salt = Data(base64Encoded: payload.salt),
              let nonce = Data(base64Encoded: payload.nonce),
              let ciphertext = Data(base64Encoded: payload.ciphertext),
              let tag = Data(base64Encoded: payload.tag) else { throw CryptoServiceError.invalidPrivateBackup }
        let key = try KeyDerivationService.personalEncryptionKey(secret: secret, salt: salt)
        do {
            let box = try AES.GCM.SealedBox(nonce: AES.GCM.Nonce(data: nonce), ciphertext: ciphertext, tag: tag)
            let privateData = try AES.GCM.open(box, using: key)
            _ = try KeychainService.importRecipientPrivateKey(privateData)
            return try myPublicKeyText()
        } catch { throw CryptoServiceError.decryptionFailed }
    }

    static func isProtectedPrivateKeyBackup(_ text: String) -> Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix(protectedPrivateKeyPrefix)
    }

    // MARK: Signing

    static func signingPublicKeyText(algorithm: SigningAlgorithm) throws -> String {
        let privateData = try KeychainService.signingPrivateKeyData(for: algorithm)
        let publicData = try signingPublicKeyData(privateData: privateData, algorithm: algorithm)
        let payload = ["version": "1", "algorithm": algorithm.rawValue, "key": publicData.base64EncodedString()]
        let data = try JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys])
        return "CP-SIGN1:" + data.base64EncodedString()
    }

    static func sign(
        _ text: String,
        algorithm: SigningAlgorithm,
        autographDrawingData: Data? = nil
    ) throws -> String {
        let privateData = try KeychainService.signingPrivateKeyData(for: algorithm)
        let publicData = try signingPublicKeyData(privateData: privateData, algorithm: algorithm)
        let publicKey = publicData.base64EncodedString()
        let autographDrawing = autographDrawingData?.base64EncodedString()
        let createdAt = ISO8601DateFormatter().string(from: Date())
        let createdUsing = "Ciphera"
        let signerFingerprint = fingerprint(for: publicData, label: algorithm.rawValue)
        let contentSHA256 = sha256Hex(Data(text.utf8))
        let autographSHA256 = autographDrawingData.map(sha256Hex)

        let material = SignatureSignedMaterial(
            version: 2,
            algorithm: algorithm,
            publicKey: publicKey,
            content: text,
            autographDrawing: autographDrawing,
            createdAt: createdAt,
            createdUsing: createdUsing,
            signerFingerprint: signerFingerprint,
            contentSHA256: contentSHA256,
            autographSHA256: autographSHA256
        )
        let message = try signatureMessageDataV2(material)
        let signature: Data

        switch algorithm {
        case .ed25519:
            signature = try Curve25519.Signing.PrivateKey(rawRepresentation: privateData).signature(for: message)
        case .p256:
            signature = try P256.Signing.PrivateKey(rawRepresentation: privateData).signature(for: message).derRepresentation
        case .p384:
            signature = try P384.Signing.PrivateKey(rawRepresentation: privateData).signature(for: message).derRepresentation
        case .p521:
            signature = try P521.Signing.PrivateKey(rawRepresentation: privateData).signature(for: message).derRepresentation
        }

        let payload = SignaturePayload(
            version: 2,
            algorithm: algorithm,
            publicKey: publicKey,
            signature: signature.base64EncodedString(),
            content: text,
            autographDrawing: autographDrawing,
            createdAt: createdAt,
            createdUsing: createdUsing,
            signerFingerprint: signerFingerprint,
            contentSHA256: contentSHA256,
            autographSHA256: autographSHA256
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return signaturePrefix + (try encoder.encode(payload)).base64EncodedString()
    }

    static func verify(_ text: String, signatureText: String) throws -> Bool {
        let payload = try decodeSignaturePayload(signatureText)
        return try verifySignaturePayload(payload, content: text)
    }

    static func verifyEmbeddedSignature(_ signatureText: String) throws -> Bool {
        let payload = try decodeSignaturePayload(signatureText)
        guard let content = payload.content else { throw CryptoServiceError.signatureContentRequired }
        return try verifySignaturePayload(payload, content: content)
    }

    static func signatureEmbeddedContent(_ signatureText: String) -> String? {
        (try? decodeSignaturePayload(signatureText))?.content
    }

    static func signatureRequiresExternalContent(_ signatureText: String) -> Bool {
        guard let payload = try? decodeSignaturePayload(signatureText) else { return false }
        return payload.content == nil
    }

    static func signatureAutographDrawingData(_ signatureText: String) -> Data? {
        guard let payload = try? decodeSignaturePayload(signatureText),
              let encoded = payload.autographDrawing
        else { return nil }
        return Data(base64Encoded: encoded)
    }

    static func signatureDetailsJSON(_ signatureText: String) throws -> Data {
        let payload = try decodeSignaturePayload(signatureText)
        let details = SignatureDetailsExport(
            format: "CP-SIG1",
            version: payload.version,
            message: payload.content,
            createdAt: payload.createdAt,
            createdUsing: payload.createdUsing ?? "Ciphera",
            algorithm: payload.algorithm,
            signerFingerprint: payload.signerFingerprint,
            contentSHA256: payload.contentSHA256,
            autographSHA256: payload.autographSHA256,
            hasAutograph: payload.autographDrawing != nil,
            publicKey: payload.publicKey,
            digitalSignature: payload.signature,
            signedPackage: signatureText
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(details)
    }

    static func signatureCreatedAt(_ signatureText: String) -> String? {
        (try? decodeSignaturePayload(signatureText))?.createdAt
    }

    static func signatureSignerFingerprint(_ signatureText: String) -> String? {
        (try? decodeSignaturePayload(signatureText))?.signerFingerprint
    }

    private static func verifySignaturePayload(_ payload: SignaturePayload, content: String) throws -> Bool {
        guard let publicData = Data(base64Encoded: payload.publicKey),
              let signatureData = Data(base64Encoded: payload.signature)
        else { throw CryptoServiceError.invalidSignature }

        let message: Data
        if payload.version >= 2 {
            guard let createdAt = payload.createdAt,
                  let createdUsing = payload.createdUsing,
                  let signerFingerprint = payload.signerFingerprint,
                  let contentSHA256 = payload.contentSHA256
            else { throw CryptoServiceError.invalidSignature }

            let material = SignatureSignedMaterial(
                version: payload.version,
                algorithm: payload.algorithm,
                publicKey: payload.publicKey,
                content: content,
                autographDrawing: payload.autographDrawing,
                createdAt: createdAt,
                createdUsing: createdUsing,
                signerFingerprint: signerFingerprint,
                contentSHA256: contentSHA256,
                autographSHA256: payload.autographSHA256
            )
            message = try signatureMessageDataV2(material)
        } else {
            let autographData = payload.autographDrawing.flatMap { Data(base64Encoded: $0) }
            message = signatureMessageData(text: content, autographDrawingData: autographData)
        }

        switch payload.algorithm {
        case .ed25519:
            return try Curve25519.Signing.PublicKey(rawRepresentation: publicData)
                .isValidSignature(signatureData, for: message)
        case .p256:
            let signature = try P256.Signing.ECDSASignature(derRepresentation: signatureData)
            return try P256.Signing.PublicKey(rawRepresentation: publicData)
                .isValidSignature(signature, for: message)
        case .p384:
            let signature = try P384.Signing.ECDSASignature(derRepresentation: signatureData)
            return try P384.Signing.PublicKey(rawRepresentation: publicData)
                .isValidSignature(signature, for: message)
        case .p521:
            let signature = try P521.Signing.ECDSASignature(derRepresentation: signatureData)
            return try P521.Signing.PublicKey(rawRepresentation: publicData)
                .isValidSignature(signature, for: message)
        }
    }

    private static func decodeSignaturePayload(_ signatureText: String) throws -> SignaturePayload {
        let trimmed = signatureText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix(signaturePrefix),
              let data = Data(base64Encoded: String(trimmed.dropFirst(signaturePrefix.count))),
              let payload = try? JSONDecoder().decode(SignaturePayload.self, from: data),
              payload.version == 1 || payload.version == 2
        else { throw CryptoServiceError.invalidSignature }
        return payload
    }

    private static func signatureMessageDataV2(_ material: SignatureSignedMaterial) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(material)
    }

    private static func signatureMessageData(text: String, autographDrawingData: Data?) -> Data {
        guard let autographDrawingData else {
            return Data(text.utf8)
        }

        let textData = Data(text.utf8)
        var message = Data("Ciphera.Signature+Autograph.v1".utf8)
        var textLength = UInt64(textData.count).bigEndian
        withUnsafeBytes(of: &textLength) { message.append(contentsOf: $0) }
        message.append(textData)
        message.append(autographDrawingData)
        return message
    }

    private static func sha256Hex(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    // MARK: File encryption

    static func encryptFileData(
        _ data: Data,
        filename: String,
        contentType: String? = nil,
        secret: String,
        algorithm: SymmetricCipher
    ) throws -> Data {
        guard data.count <= 20 * 1024 * 1024 else { throw CryptoServiceError.fileTooLarge }
        let salt = try KeyDerivationService.randomSalt()
        let key = try KeyDerivationService.personalEncryptionKey(secret: secret, salt: salt)
        let sealed = try seal(data, using: key, algorithm: algorithm)
        let payload = FilePayload(
            magic: fileMagic,
            version: 2,
            originalFilename: filename,
            contentType: contentType,
            mode: .secret,
            algorithm: algorithm,
            kdf: currentSecretKDF,
            salt: salt.base64EncodedString(),
            keyAgreement: nil,
            ephemeralPublicKey: nil,
            recipientKeyID: nil,
            nonce: sealed.nonce.base64EncodedString(),
            ciphertext: sealed.ciphertext.base64EncodedString(),
            tag: sealed.tag.base64EncodedString()
        )
        return try JSONEncoder().encode(payload)
    }

    static func encryptFileData(
        _ data: Data,
        filename: String,
        contentType: String? = nil,
        recipientPublicKeyText: String,
        algorithm: SymmetricCipher
    ) throws -> Data {
        guard data.count <= 20 * 1024 * 1024 else { throw CryptoServiceError.fileTooLarge }
        let parsed = try parsePublicKey(recipientPublicKeyText)
        let material = try recipientEncryptionMaterial(for: parsed)
        let sealed = try seal(data, using: material.key, algorithm: algorithm)
        let payload = FilePayload(
            magic: fileMagic,
            version: 2,
            originalFilename: filename,
            contentType: contentType,
            mode: .recipient,
            algorithm: algorithm,
            kdf: "\(parsed.curve.title)+HKDF-SHA256",
            salt: nil,
            keyAgreement: parsed.curve,
            ephemeralPublicKey: material.ephemeralPublicKey.base64EncodedString(),
            recipientKeyID: keyID(for: parsed.raw, curve: parsed.curve),
            nonce: sealed.nonce.base64EncodedString(),
            ciphertext: sealed.ciphertext.base64EncodedString(),
            tag: sealed.tag.base64EncodedString()
        )
        return try JSONEncoder().encode(payload)
    }

    static func encryptFileText(
        _ data: Data,
        filename: String,
        contentType: String? = nil,
        secret: String,
        algorithm: SymmetricCipher
    ) throws -> String {
        let payloadData = try encryptFileData(
            data,
            filename: filename,
            contentType: contentType,
            secret: secret,
            algorithm: algorithm
        )
        return filePrefix + payloadData.base64EncodedString()
    }

    static func encryptFileText(
        _ data: Data,
        filename: String,
        contentType: String? = nil,
        recipientPublicKeyText: String,
        algorithm: SymmetricCipher
    ) throws -> String {
        let payloadData = try encryptFileData(
            data,
            filename: filename,
            contentType: contentType,
            recipientPublicKeyText: recipientPublicKeyText,
            algorithm: algorithm
        )
        return filePrefix + payloadData.base64EncodedString()
    }

    static func decryptFileData(
        _ encryptedData: Data,
        secret: String?
    ) throws -> (filename: String, data: Data, contentType: String?) {
        let payload = try JSONDecoder().decode(FilePayload.self, from: encryptedData)
        return try decryptFilePayload(payload, secret: secret)
    }

    static func decryptFileText(
        _ encryptedText: String,
        secret: String?
    ) throws -> (filename: String, data: Data, contentType: String?) {
        let payload = try decodeFileText(encryptedText)
        return try decryptFilePayload(payload, secret: secret)
    }

    static func fileInfo(_ data: Data) -> (mode: ProtectionMode, algorithm: SymmetricCipher, filename: String)? {
        guard let payload = try? JSONDecoder().decode(FilePayload.self, from: data),
              payload.magic == fileMagic,
              payload.version == 1 || payload.version == 2
        else { return nil }
        return (payload.mode, payload.algorithm, payload.originalFilename)
    }

    static func fileInfo(
        _ encryptedText: String
    ) -> (mode: ProtectionMode, algorithm: SymmetricCipher, filename: String, contentType: String?)? {
        guard let payload = try? decodeFileText(encryptedText) else { return nil }
        return (payload.mode, payload.algorithm, payload.originalFilename, payload.contentType)
    }

    private static func decodeFileText(_ encryptedText: String) throws -> FilePayload {
        let trimmed = encryptedText.trimmingCharacters(in: .whitespacesAndNewlines)
        let payloadData: Data

        if trimmed.hasPrefix(filePrefix) {
            let encoded = String(trimmed.dropFirst(filePrefix.count))
            guard let decoded = Data(base64Encoded: encoded) else { throw CryptoServiceError.invalidBase64 }
            payloadData = decoded
        } else if let utf8 = trimmed.data(using: .utf8) {
            // Backward compatibility for the old raw-JSON .ciphera format.
            payloadData = utf8
        } else {
            throw CryptoServiceError.invalidPayload
        }

        let payload = try JSONDecoder().decode(FilePayload.self, from: payloadData)
        guard payload.magic == fileMagic, payload.version == 1 || payload.version == 2 else {
            throw CryptoServiceError.invalidPayload
        }
        return payload
    }

    private static func decryptFilePayload(
        _ payload: FilePayload,
        secret: String?
    ) throws -> (filename: String, data: Data, contentType: String?) {
        guard payload.magic == fileMagic, payload.version == 1 || payload.version == 2 else {
            throw CryptoServiceError.invalidPayload
        }

        let key: SymmetricKey
        if payload.mode == .secret {
            guard let secret,
                  let saltText = payload.salt,
                  let salt = Data(base64Encoded: saltText)
            else { throw CryptoServiceError.invalidPayload }
            key = try KeyDerivationService.personalEncryptionKey(secret: secret, salt: salt)
        } else {
            guard let ephemeralText = payload.ephemeralPublicKey,
                  let ephemeralData = Data(base64Encoded: ephemeralText)
            else { throw CryptoServiceError.invalidPayload }

            let curve = payload.keyAgreement ?? .curve25519
            let privateData = try KeychainService.agreementPrivateKeyData(for: curve)
            let publicData = try publicKeyData(fromPrivateKeyData: privateData, curve: curve)

            if let expected = payload.recipientKeyID,
               expected != keyID(for: publicData, curve: curve) {
                throw CryptoServiceError.wrongRecipient
            }

            key = try recipientDecryptionKey(
                privateData: privateData,
                ephemeralPublicData: ephemeralData,
                curve: curve
            )
        }

        let parts = Payload(
            version: 1,
            mode: payload.mode,
            algorithm: payload.algorithm,
            kdf: payload.kdf,
            salt: payload.salt,
            keyAgreement: payload.keyAgreement,
            ephemeralPublicKey: payload.ephemeralPublicKey,
            recipientKeyID: payload.recipientKeyID,
            nonce: payload.nonce,
            ciphertext: payload.ciphertext,
            tag: payload.tag
        )

        return (
            payload.originalFilename,
            try openData(payload: parts, using: key),
            payload.contentType
        )
    }

    // MARK: Inspection

    static func info(of encryptedText: String) -> CipheraMessageInfo? {
        guard let payload = try? decode(encryptedText) else { return nil }
        return CipheraMessageInfo(mode: payload.mode, algorithm: payload.algorithm)
    }

    static func details(of encryptedText: String) -> CipheraMessageDetails? {
        guard let payload = try? decode(encryptedText) else { return nil }
        return CipheraMessageDetails(
            version: payload.version, mode: payload.mode, algorithm: payload.algorithm, kdf: payload.kdf ?? "Unknown",
            salt: payload.salt, nonce: payload.nonce, tag: payload.tag,
            ephemeralPublicKey: payload.ephemeralPublicKey, recipientKeyID: payload.recipientKeyID, keyAgreement: payload.keyAgreement
        )
    }

    // MARK: Internals

    private struct ParsedPublicKey { let curve: PublicKeyCurve; let raw: Data }
    private struct RecipientMaterial { let key: SymmetricKey; let ephemeralPublicKey: Data }
    private struct SealedParts { let nonce: Data; let ciphertext: Data; let tag: Data }

    private static func parsePublicKey(_ text: String) throws -> ParsedPublicKey {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix(publicKeyPrefix) {
            guard let data = Data(base64Encoded: String(trimmed.dropFirst(publicKeyPrefix.count))) else { throw CryptoServiceError.invalidPublicKey }
            _ = try Curve25519.KeyAgreement.PublicKey(rawRepresentation: data)
            return ParsedPublicKey(curve: .curve25519, raw: data)
        }
        if trimmed.hasPrefix(publicKeyV2Prefix),
           let data = Data(base64Encoded: String(trimmed.dropFirst(publicKeyV2Prefix.count))),
           let payload = try? JSONDecoder().decode(PublicKeyPayload.self, from: data),
           let raw = Data(base64Encoded: payload.key) {
            do {
                switch payload.curve {
                case .curve25519: _ = try Curve25519.KeyAgreement.PublicKey(rawRepresentation: raw)
                case .p256: _ = try P256.KeyAgreement.PublicKey(rawRepresentation: raw)
                case .p384: _ = try P384.KeyAgreement.PublicKey(rawRepresentation: raw)
                case .p521: _ = try P521.KeyAgreement.PublicKey(rawRepresentation: raw)
                }
                return ParsedPublicKey(curve: payload.curve, raw: raw)
            } catch { throw CryptoServiceError.invalidPublicKey }
        }
        throw CryptoServiceError.invalidPublicKey
    }

    private static func publicKeyData(fromPrivateKeyData data: Data, curve: PublicKeyCurve) throws -> Data {
        switch curve {
        case .curve25519: return try Curve25519.KeyAgreement.PrivateKey(rawRepresentation: data).publicKey.rawRepresentation
        case .p256: return try P256.KeyAgreement.PrivateKey(rawRepresentation: data).publicKey.rawRepresentation
        case .p384: return try P384.KeyAgreement.PrivateKey(rawRepresentation: data).publicKey.rawRepresentation
        case .p521: return try P521.KeyAgreement.PrivateKey(rawRepresentation: data).publicKey.rawRepresentation
        }
    }

    private static func recipientEncryptionMaterial(for parsed: ParsedPublicKey) throws -> RecipientMaterial {
        switch parsed.curve {
        case .curve25519:
            let recipient = try Curve25519.KeyAgreement.PublicKey(rawRepresentation: parsed.raw)
            let eph = Curve25519.KeyAgreement.PrivateKey()
            return RecipientMaterial(key: recipientSymmetricKey(from: try eph.sharedSecretFromKeyAgreement(with: recipient), curve: parsed.curve), ephemeralPublicKey: eph.publicKey.rawRepresentation)
        case .p256:
            let recipient = try P256.KeyAgreement.PublicKey(rawRepresentation: parsed.raw)
            let eph = P256.KeyAgreement.PrivateKey()
            return RecipientMaterial(key: recipientSymmetricKey(from: try eph.sharedSecretFromKeyAgreement(with: recipient), curve: parsed.curve), ephemeralPublicKey: eph.publicKey.rawRepresentation)
        case .p384:
            let recipient = try P384.KeyAgreement.PublicKey(rawRepresentation: parsed.raw)
            let eph = P384.KeyAgreement.PrivateKey()
            return RecipientMaterial(key: recipientSymmetricKey(from: try eph.sharedSecretFromKeyAgreement(with: recipient), curve: parsed.curve), ephemeralPublicKey: eph.publicKey.rawRepresentation)
        case .p521:
            let recipient = try P521.KeyAgreement.PublicKey(rawRepresentation: parsed.raw)
            let eph = P521.KeyAgreement.PrivateKey()
            return RecipientMaterial(key: recipientSymmetricKey(from: try eph.sharedSecretFromKeyAgreement(with: recipient), curve: parsed.curve), ephemeralPublicKey: eph.publicKey.rawRepresentation)
        }
    }

    private static func recipientDecryptionKey(privateData: Data, ephemeralPublicData: Data, curve: PublicKeyCurve) throws -> SymmetricKey {
        switch curve {
        case .curve25519:
            let priv = try Curve25519.KeyAgreement.PrivateKey(rawRepresentation: privateData)
            let pub = try Curve25519.KeyAgreement.PublicKey(rawRepresentation: ephemeralPublicData)
            return recipientSymmetricKey(from: try priv.sharedSecretFromKeyAgreement(with: pub), curve: curve)
        case .p256:
            let priv = try P256.KeyAgreement.PrivateKey(rawRepresentation: privateData)
            let pub = try P256.KeyAgreement.PublicKey(rawRepresentation: ephemeralPublicData)
            return recipientSymmetricKey(from: try priv.sharedSecretFromKeyAgreement(with: pub), curve: curve)
        case .p384:
            let priv = try P384.KeyAgreement.PrivateKey(rawRepresentation: privateData)
            let pub = try P384.KeyAgreement.PublicKey(rawRepresentation: ephemeralPublicData)
            return recipientSymmetricKey(from: try priv.sharedSecretFromKeyAgreement(with: pub), curve: curve)
        case .p521:
            let priv = try P521.KeyAgreement.PrivateKey(rawRepresentation: privateData)
            let pub = try P521.KeyAgreement.PublicKey(rawRepresentation: ephemeralPublicData)
            return recipientSymmetricKey(from: try priv.sharedSecretFromKeyAgreement(with: pub), curve: curve)
        }
    }

    private static func recipientSymmetricKey(from sharedSecret: SharedSecret, curve: PublicKeyCurve) -> SymmetricKey {
        sharedSecret.hkdfDerivedSymmetricKey(
            using: SHA256.self,
            salt: Data("Ciphera.KeyAgreement.v1".utf8),
            sharedInfo: Data("recipient-content-encryption|\(curve.rawValue)".utf8),
            outputByteCount: 32
        )
    }

    private static func signingPublicKeyData(privateData: Data, algorithm: SigningAlgorithm) throws -> Data {
        switch algorithm {
        case .ed25519: return try Curve25519.Signing.PrivateKey(rawRepresentation: privateData).publicKey.rawRepresentation
        case .p256: return try P256.Signing.PrivateKey(rawRepresentation: privateData).publicKey.rawRepresentation
        case .p384: return try P384.Signing.PrivateKey(rawRepresentation: privateData).publicKey.rawRepresentation
        case .p521: return try P521.Signing.PrivateKey(rawRepresentation: privateData).publicKey.rawRepresentation
        }
    }

    private static func seal(_ data: Data, using key: SymmetricKey, algorithm: SymmetricCipher) throws -> SealedParts {
        switch algorithm {
        case .aes256GCM:
            let box = try AES.GCM.seal(data, using: key)
            return SealedParts(nonce: Data(box.nonce), ciphertext: box.ciphertext, tag: box.tag)
        case .chaCha20Poly1305:
            let box = try ChaChaPoly.seal(data, using: key)
            return SealedParts(nonce: Data(box.nonce), ciphertext: box.ciphertext, tag: box.tag)
        }
    }

    private static func open(payload: Payload, using key: SymmetricKey) throws -> String {
        let clear = try openData(payload: payload, using: key)
        guard let text = String(data: clear, encoding: .utf8) else { throw CryptoServiceError.decryptionFailed }
        return text
    }

    private static func openData(payload: Payload, using key: SymmetricKey) throws -> Data {
        guard let nonce = Data(base64Encoded: payload.nonce),
              let ciphertext = Data(base64Encoded: payload.ciphertext),
              let tag = Data(base64Encoded: payload.tag) else { throw CryptoServiceError.invalidBase64 }
        do {
            switch payload.algorithm {
            case .aes256GCM:
                let box = try AES.GCM.SealedBox(nonce: AES.GCM.Nonce(data: nonce), ciphertext: ciphertext, tag: tag)
                return try AES.GCM.open(box, using: key)
            case .chaCha20Poly1305:
                let box = try ChaChaPoly.SealedBox(nonce: ChaChaPoly.Nonce(data: nonce), ciphertext: ciphertext, tag: tag)
                return try ChaChaPoly.open(box, using: key)
            }
        } catch { throw CryptoServiceError.decryptionFailed }
    }

    private static func keyID(for publicKey: Data, curve: PublicKeyCurve) -> String {
        var material = Data(curve.rawValue.utf8); material.append(publicKey)
        return Data(SHA256.hash(data: material).prefix(8)).base64EncodedString()
    }

    private static func fingerprint(for publicKey: Data, label: String) -> String {
        var material = Data(label.utf8); material.append(publicKey)
        let digest = SHA256.hash(data: material)
        let hex = digest.prefix(8).map { String(format: "%02X", $0) }.joined()
        return stride(from: 0, to: hex.count, by: 4).map { index in
            let start = hex.index(hex.startIndex, offsetBy: index)
            let end = hex.index(start, offsetBy: min(4, hex.count - index))
            return String(hex[start..<end])
        }.joined(separator: " ")
    }

    private static func encode(_ payload: Payload) throws -> String {
        let encoded = try JSONEncoder().encode(payload).base64EncodedString()
        return prefix + encoded
    }

    private static func decode(_ encryptedText: String) throws -> Payload {
        let trimmed = encryptedText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix(prefix) else { throw CryptoServiceError.invalidPayload }
        guard let data = Data(base64Encoded: String(trimmed.dropFirst(prefix.count))) else { throw CryptoServiceError.invalidBase64 }
        do {
            let payload = try JSONDecoder().decode(Payload.self, from: data)
            guard payload.version == 1 else { throw CryptoServiceError.invalidPayload }
            return payload
        } catch let error as CryptoServiceError { throw error }
        catch { throw CryptoServiceError.invalidPayload }
    }
}
