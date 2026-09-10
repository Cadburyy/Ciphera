import SwiftUI
import UIKit
import UniformTypeIdentifiers
import CryptoKit

struct MyKeyView: View {

    let replayOnboarding: () -> Void

    @StateObject private var viewModel = MyKeyViewModel()

    @State private var showResetConfirmation = false


    var body: some View {

        NavigationStack {

            List {

                Section {

                    VStack(alignment: .leading, spacing: 10) {

                        Image(systemName: "key.viewfinder")

                            .font(.system(size: 38, weight: .semibold))

                            .foregroundStyle(.tint)

                        Text("Your encryption identity")

                            .font(.title3.bold())

                        Text("Share the public key. Keep the private key protected unless you intentionally make a backup.")

                            .foregroundStyle(.secondary)

                    }

                    .padding(.vertical, 8)

                }

                Section {

                    if viewModel.publicKey.isEmpty {

                        HStack {

                            ProgressView()

                            Text("Loading key…")

                                .foregroundStyle(.secondary)

                        }

                    } else {

                        Text(viewModel.publicKey)

                            .font(.system(.footnote, design: .monospaced))

                            .textSelection(.enabled)

                        if !viewModel.fingerprint.isEmpty {
                            LabeledContent("Fingerprint", value: viewModel.fingerprint)
                                .font(.subheadline)
                        }

                        Button {

                            UIPasteboard.general.string = viewModel.publicKey

                        } label: {

                            Label("Copy Public Key", systemImage: "doc.on.doc")

                        }

                    }

                } header: {

                    Text("Public Key")

                } footer: {

                    Text("Anyone can use this CP-PUB1 value to encrypt a recipient-mode message for you. Compare fingerprints when verifying a key in person.")

                }

                Section {

                    NavigationLink {

                        PrivateKeyBackupView()

                    } label: {

                        Label("Backup Private Key", systemImage: "externaldrive.badge.plus")

                    }

                    NavigationLink {

                        RestorePrivateKeyView { importedPublicKey in
                            viewModel.imported(importedPublicKey)
                        }

                    } label: {

                        Label("Restore Private Key", systemImage: "square.and.arrow.down")

                    }

                } header: {

                    Text("Private Key")

                } footer: {

                    Text("Protected backups use your secret, SHA-256 with HKDF, and AES-GCM. The private key normally remains hidden in this iPhone’s Keychain.")

                }

                Section("Advanced") {

                    Button("Generate New Key Pair", role: .destructive) {

                        showResetConfirmation = true

                    }

                }

                if let errorMessage = viewModel.errorMessage {

                    Section {

                        Label(errorMessage, systemImage: "exclamationmark.triangle.fill")

                            .foregroundStyle(.red)

                            .font(.footnote)

                    }

                }

            }

            .navigationTitle("My Key")

            .toolbar {

                ToolbarItemGroup(placement: .topBarTrailing) {

                    if !viewModel.publicKey.isEmpty {

                        ShareLink(item: viewModel.publicKey) {

                            Image(systemName: "square.and.arrow.up")

                        }

                        .accessibilityLabel("Share public key")

                    }

                    Menu {

                        Button {

                            replayOnboarding()

                        } label: {

                            Label("Replay Onboarding", systemImage: "arrow.counterclockwise")

                        }

                    } label: {

                        Image(systemName: "ellipsis.circle")

                    }

                }

            }

            .task { viewModel.loadKey() }

            .confirmationDialog(

                "Generate a new key pair?",

                isPresented: $showResetConfirmation,

                titleVisibility: .visible

            ) {

                Button("Generate New Key", role: .destructive) {

                    viewModel.resetKey()

                }

                Button("Cancel", role: .cancel) { }

            } message: {

                Text("Old recipient-mode messages for your current public key will stop decrypting unless you backed up and later restore its private key.")

            }

        }

    }

}
