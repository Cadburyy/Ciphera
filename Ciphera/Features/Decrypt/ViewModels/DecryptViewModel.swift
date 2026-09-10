import Foundation
import Combine

@MainActor
final class DecryptViewModel: ObservableObject {
    @Published var path: [DecryptionResult] = []
    @Published var encryptedText = ""
    @Published var detectedInfo: CipheraMessageInfo?
    @Published var secret = ""
    @Published var revealSecret = false
    @Published var errorMessage: String?

    var canDecrypt: Bool {
        guard let detectedInfo else { return false }
        return detectedInfo.mode == .secret ? secret.count >= 8 : true
    }

    func setEncryptedText(_ value: String?) {
        encryptedText = value ?? ""
        detect()
    }

    func detect() {
        detectedInfo = CryptoService.info(of: encryptedText)
        errorMessage = nil
    }

    func decrypt() {
        errorMessage = nil
        guard let info = detectedInfo else {
            errorMessage = "Paste a valid CP1 message first."
            return
        }
        if info.mode == .secret && secret.count < 8 {
            errorMessage = "Enter the same secret used to encrypt this message (at least 8 characters)."
            return
        }

        do {
            let plaintext: String
            let protection: String
            switch info.mode {
            case .secret:
                plaintext = try CryptoService.decryptWithSecret(encryptedText, secret: secret)
                protection = "With a Secret"
            case .recipient:
                plaintext = try CryptoService.decryptForMe(encryptedText)
                protection = "For Someone"
            }
            path.append(DecryptionResult(plaintext: plaintext, protection: protection, algorithm: info.algorithm.title))
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
