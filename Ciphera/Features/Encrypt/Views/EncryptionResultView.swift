import SwiftUI
import UIKit
import UniformTypeIdentifiers
import CryptoKit

struct EncryptionResultView: View {

    let result: EncryptionResult

    @State private var showDetails = false

    var body: some View {

        List {

            Section {

                HStack(spacing: 12) {

                    Image(systemName: "checkmark.shield.fill")
                        .font(.title2)
                        .foregroundStyle(.green)

                    VStack(alignment: .leading, spacing: 3) {

                        Text("Encryption Complete")
                            .font(.headline)

                        Text("This message has been encrypted successfully.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

            } header: {

                Text("Encryption")

            } footer: {

                Text("Ciphera does not save this result. Copy or share it before leaving if you need it later.")

            }

            Section {

                Text(result.text)
                    .font(.system(.footnote, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityLabel("Encrypted CP1 message preview")

                Button {
                    UIPasteboard.general.string = result.text
                } label: {
                    Label("Copy CP1 Message", systemImage: "doc.on.doc")
                }

            } header: {

                Text("CP1 Message")

            }

            Section("Summary") {

                LabeledContent("Protection", value: result.protection)

                LabeledContent("Algorithm", value: result.algorithm)

                LabeledContent("Format", value: "Ciphera CP1")

                if let details = CryptoService.details(of: result.text) {
                    LabeledContent("Key Derivation", value: details.kdf)
                }

            }

        }

        .navigationTitle("Encrypted")

        .navigationBarTitleDisplayMode(.inline)

        .toolbar {

            ToolbarItemGroup(placement: .topBarTrailing) {

                ShareLink(item: result.text) {

                    Image(systemName: "square.and.arrow.up")

                }

                .accessibilityLabel("Share encrypted message")

                Menu {

                    Button {

                        UIPasteboard.general.string = result.text

                    } label: {

                        Label("Copy", systemImage: "doc.on.doc")

                    }

                    Button {

                        showDetails = true

                    } label: {

                        Label("Encryption Details", systemImage: "info.circle")

                    }

                } label: {

                    Image(systemName: "ellipsis.circle")

                }

            }

        }

        .sheet(isPresented: $showDetails) {
            if let details = CryptoService.details(of: result.text) {
                MessageDetailsView(details: details)
            } else {
                HelpSheet(title: "Encryption Details", message: "The CP1 metadata could not be read.")
            }
        }

    }

}

// MARK: - Decrypt
