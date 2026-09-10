import SwiftUI
import UIKit
import UniformTypeIdentifiers
import CryptoKit

struct CryptoDictionaryEntry: Identifiable, Hashable {
    let id = UUID()
    let term: String
    let category: String
    let summary: String
    let beginnerExplanation: String
    let usedFor: String
    let note: String?
}
