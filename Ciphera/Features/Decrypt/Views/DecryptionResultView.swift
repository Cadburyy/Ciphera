import SwiftUI
import UIKit
import UniformTypeIdentifiers
import CryptoKit

struct DecryptionResultView: View {

    let result: DecryptionResult

    var body: some View {

        List {

            Section {

                HStack(spacing: 12) {

                    Image(systemName: "lock.open.fill")
                        .font(.title2)
                        .foregroundStyle(.green)

                    VStack(alignment: .leading, spacing: 3) {

                        Text("Decryption Complete")
                            .font(.headline)

                        Text("The plaintext was recovered successfully.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

            } header: {

                Text("Decryption")

            } footer: {

                Text("The plaintext is shown temporarily and is not saved by Ciphera.")

            }

            Section("Plaintext") {

                Text(result.plaintext)

                    .textSelection(.enabled)

                Button {

                    UIPasteboard.general.string = result.plaintext

                } label: {

                    Label("Copy Plaintext", systemImage: "doc.on.doc")

                }

            }

            Section("Summary") {

                LabeledContent("Protection", value: result.protection)

                LabeledContent("Algorithm", value: result.algorithm)

            }

        }

        .navigationTitle("Decrypted")

        .navigationBarTitleDisplayMode(.inline)

        .toolbar {

            ToolbarItem(placement: .topBarTrailing) {

                ShareLink(item: result.plaintext) {

                    Image(systemName: "square.and.arrow.up")

                }

                .accessibilityLabel("Share plaintext")

            }

        }

    }

}

// MARK: - My Key
