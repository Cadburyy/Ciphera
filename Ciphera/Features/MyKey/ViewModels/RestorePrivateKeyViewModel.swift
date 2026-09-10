import Foundation
import Combine

@MainActor
final class RestorePrivateKeyViewModel: ObservableObject {
    @Published var privateKeyText = ""
    @Published var backupSecret = ""
    @Published var errorMessage: String?
    @Published var isAuthenticating = false

    var needsBackupPassword: Bool {
        CryptoService.isProtectedPrivateKeyBackup(privateKeyText)
    }

    var canRestore: Bool {
        !privateKeyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        && !isAuthenticating
        && (!needsBackupPassword || backupSecret.count >= 8)
    }

    func restore() async -> String? {
        isAuthenticating = true
        errorMessage = nil
        defer { isAuthenticating = false }
        do {
            try await DeviceAuthenticationService.authenticate(reason: "Authenticate to restore your Ciphera private key.")
            if needsBackupPassword {
                return try CryptoService.importProtectedPrivateKeyText(privateKeyText, secret: backupSecret)
            }
            return try CryptoService.importMyPrivateKeyText(privateKeyText)
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }
}
