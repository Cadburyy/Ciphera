import SwiftUI
import UIKit
import UniformTypeIdentifiers
import CryptoKit

struct EncryptionResult: Hashable, Identifiable {

    let id = UUID()

    let text: String

    let protection: String

    let algorithm: String

}
