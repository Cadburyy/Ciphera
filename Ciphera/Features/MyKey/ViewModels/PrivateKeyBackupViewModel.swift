import Foundation
import Combine

@MainActor
final class PrivateKeyBackupViewModel: ObservableObject {
    @Published var exportedPrivateKey = ""
    @Published var backupSecret = ""
    @Published var confirmSecret = ""
    @Published var errorMessage: String?
    @Published var isAuthenticating = false

    var canCreateBackup: Bool {
        !isAuthenticating && backupSecret.count >= 8 && backupSecret == confirmSecret
    }

    func clearBackup() {
        exportedPrivateKey = ""
        backupSecret = ""
        confirmSecret = ""
    }

    func exportPrivateKey() async {
        guard backupSecret == confirmSecret else {
            errorMessage = "The backup passwords do not match."
            return
        }
        isAuthenticating = true
        errorMessage = nil
        defer { isAuthenticating = false }
        do {
            try await DeviceAuthenticationService.authenticate(reason: "Authenticate to create your Ciphera private-key backup.")
            exportedPrivateKey = try CryptoService.exportProtectedPrivateKeyText(secret: backupSecret)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
