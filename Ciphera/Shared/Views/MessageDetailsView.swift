import SwiftUI
import UIKit
import UniformTypeIdentifiers
import CryptoKit

struct MessageDetailsView: View {
    @Environment(\.dismiss) private var dismiss
    let details: CipheraMessageDetails

    var body: some View {
        NavigationStack {
            List {
                Section("Message") {
                    LabeledContent("Format", value: "CP1")
                    LabeledContent("Version", value: String(details.version))
                    LabeledContent("Protection", value: details.protectionTitle)
                    LabeledContent("Algorithm", value: details.algorithm.title)
                    LabeledContent("KDF", value: details.kdf)
                    if let keyAgreement = details.keyAgreement {
                        LabeledContent("Key Agreement", value: keyAgreement.title)
                    }
                }

                Section("Portable Metadata") {
                    if let salt = details.salt {
                        LabeledContent("Salt") { Text(salt).font(.system(.caption, design: .monospaced)).textSelection(.enabled) }
                    }
                    LabeledContent("Nonce") { Text(details.nonce).font(.system(.caption, design: .monospaced)).textSelection(.enabled) }
                    LabeledContent("Tag") { Text(details.tag).font(.system(.caption, design: .monospaced)).textSelection(.enabled) }
                    if let recipientID = details.recipientKeyID {
                        LabeledContent("Recipient ID") { Text(recipientID).font(.system(.caption, design: .monospaced)).textSelection(.enabled) }
                    }
                    if let ephemeral = details.ephemeralPublicKey {
                        LabeledContent("Ephemeral Public Key") { Text(ephemeral).font(.system(.caption, design: .monospaced)).textSelection(.enabled) }
                    }
                }

                Section {
                    Text("These values are not secret. They are included so compatible tools can understand how a CP1 message was protected. The secret, derived symmetric key, and private key are never stored inside CP1.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Encryption Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
