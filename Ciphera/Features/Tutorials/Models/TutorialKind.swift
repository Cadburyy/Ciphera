import Foundation

enum TutorialKind: CaseIterable, Identifiable {
    case secret
    case recipient
    case backup
    case file
    case sign

    var id: Self { self }

    var title: String {
        switch self {
        case .secret: return "Protect a Message"
        case .recipient: return "Encrypt for Someone"
        case .backup: return "Back Up Your Key"
        case .file: return "Protect a File"
        case .sign: return "Sign & Verify"
        }
    }

    var symbol: String {
        switch self {
        case .secret: return "lock.fill"
        case .recipient: return "person.badge.key.fill"
        case .backup: return "externaldrive.badge.plus"
        case .file: return "folder.fill"
        case .sign: return "signature"
        }
    }

    var listTitle: String {
        switch self {
        case .secret: return "1. Protect a message"
        case .recipient: return "2. Send only to one key"
        case .backup: return "3. Back up your identity"
        case .file: return "4. Encrypt a file"
        case .sign: return "5. Sign and verify"
        }
    }
}
