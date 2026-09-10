import Foundation
import Combine

@MainActor
final class MyKeyViewModel: ObservableObject {
    @Published var publicKey = ""
    @Published var fingerprint = ""
    @Published var errorMessage: String?

    func loadKey() {
        do {
            publicKey = try CryptoService.myPublicKeyText()
            refreshFingerprint()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func imported(_ publicKey: String) {
        self.publicKey = publicKey
        refreshFingerprint()
        errorMessage = nil
    }

    func resetKey() {
        do {
            publicKey = try CryptoService.resetMyKeyPair()
            refreshFingerprint()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func refreshFingerprint() {
        fingerprint = (try? CryptoService.myKeyFingerprint()) ?? ""
    }
}
