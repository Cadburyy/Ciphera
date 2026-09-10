import SwiftUI
import UIKit
import UniformTypeIdentifiers
import CryptoKit

struct CryptoDictionaryDetailView: View {
    let entry: CryptoDictionaryEntry

    var body: some View {
        List {
            Section {
                Label(entry.category, systemImage: dictionarySymbol)
                    .foregroundStyle(.secondary)
            }

            Section("In Simple Terms") {
                Text(entry.beginnerExplanation)
            }

            Section("Used in Ciphera") {
                Text(entry.usedFor)
            }

            if let note = entry.note {
                Section("Good to Know") {
                    Text(note)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle(entry.term)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var dictionarySymbol: String {
        switch entry.category {
        case "Encryption Cipher": return "lock.shield"
        case "Key Agreement": return "key.horizontal"
        case "Digital Signature": return "signature"
        case "Hash & Key Derivation": return "number"
        case "Encryption Metadata": return "info.circle"
        default: return "doc.text"
        }
    }
}
