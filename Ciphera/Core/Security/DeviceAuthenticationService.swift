import Foundation
import LocalAuthentication

@MainActor
struct DeviceAuthenticationService {
    static func authenticate(reason: String) async throws {
        let context = LAContext()
        context.localizedCancelTitle = "Cancel"

        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            throw error ?? DeviceAuthenticationError.unavailable
        }

        let success = try await context.evaluatePolicy(
            .deviceOwnerAuthentication,
            localizedReason: reason
        )

        guard success else {
            throw DeviceAuthenticationError.failed
        }
    }
}

enum DeviceAuthenticationError: LocalizedError {
    case unavailable
    case failed

    var errorDescription: String? {
        switch self {
        case .unavailable:
            return "Device authentication is unavailable. Set a device passcode or Face ID and try again."
        case .failed:
            return "Authentication was not completed."
        }
    }
}
