import Foundation
import Combine

@MainActor
final class PublicKeyLabViewModel: ObservableObject {
    @Published var curve: PublicKeyCurve = .curve25519
    @Published var publicKey = ""
    @Published var fingerprint = ""
    @Published var errorMessage: String?

    func load() {
        do {
            publicKey = try CryptoService.myPublicKeyText(curve: curve)
            fingerprint = try CryptoService.myKeyFingerprint(curve: curve)
            errorMessage = nil
        } catch { errorMessage = error.localizedDescription }
    }

    func reset() {
        do {
            publicKey = try CryptoService.resetMyKeyPair(curve: curve)
            fingerprint = try CryptoService.myKeyFingerprint(curve: curve)
            errorMessage = nil
        } catch { errorMessage = error.localizedDescription }
    }
}
