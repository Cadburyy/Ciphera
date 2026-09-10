import SwiftUI
import UIKit
import UniformTypeIdentifiers
import CryptoKit

struct DecryptionResult: Hashable, Identifiable {

    let id = UUID()

    let plaintext: String

    let protection: String

    let algorithm: String

}
