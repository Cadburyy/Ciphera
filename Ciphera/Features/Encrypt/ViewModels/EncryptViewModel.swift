import Foundation
import Combine
import CryptoKit

@MainActor
final class EncryptViewModel: ObservableObject {
    @Published var path: [EncryptionResult] = []
    @Published var mode: ProtectionMode = .secret
    @Published var algorithm: SymmetricCipher = .aes256GCM
    @Published var plaintext = ""
    @Published var secret = ""
    @Published var revealSecret = false
    @Published var recipientPublicKey = ""
    @Published var errorMessage: String?

    var canEncrypt: Bool {
        guard !plaintext.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        switch mode {
        case .secret:
            return secret.count >= 8
        case .recipient:
            return recipientFingerprint != nil
        }
    }

    var recipientFingerprint: String? {
        guard !recipientPublicKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return try? CryptoService.fingerprint(forPublicKeyText: recipientPublicKey)
    }

    func pastePublicKey(_ value: String?) {
        recipientPublicKey = value ?? ""
    }

    func encrypt() {
        errorMessage = nil

        if mode == .secret && secret.count < 8 {
            errorMessage = "Use a secret with at least 8 characters."
            return
        }

        if mode == .recipient && recipientFingerprint == nil {
            errorMessage = "Paste a valid Ciphera public key before encrypting."
            return
        }

        do {
            let output: String
            let protection: String
            switch mode {
            case .secret:
                output = try CryptoService.encryptWithSecret(plaintext, secret: secret, algorithm: algorithm)
                protection = "With a Secret"
            case .recipient:
                output = try CryptoService.encryptForRecipient(plaintext, recipientPublicKeyText: recipientPublicKey, algorithm: algorithm)
                protection = "For Someone"
            }
            path.append(EncryptionResult(text: output, protection: protection, algorithm: algorithm.title))
        } catch {
            errorMessage = error.localizedDescription
        }
    }

}
