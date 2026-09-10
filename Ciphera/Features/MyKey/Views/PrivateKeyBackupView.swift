import SwiftUI
import UIKit
import UniformTypeIdentifiers
import CryptoKit

struct PrivateKeyBackupView: View {
    @StateObject private var viewModel = PrivateKeyBackupViewModel()
    @State private var revealSecret = false

    var body: some View {

        List {

            Section {

                Label("Private Key Backup", systemImage: "key.fill")

                    .font(.headline)

                Text("Create a password-protected CP-PRIV2 backup for recovery or another device. Ciphera protects the private key with the current learning KDF and AES-256-GCM before showing the backup text.")

                    .foregroundStyle(.secondary)

            }

            if viewModel.exportedPrivateKey.isEmpty {

                Section("Backup Password") {
                    HStack {
                        Group {
                            if revealSecret {
                                TextField("Backup password", text: $viewModel.backupSecret)
                            } else {
                                SecureField("Backup password", text: $viewModel.backupSecret)
                            }
                        }
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                        Button {
                            revealSecret.toggle()
                        } label: {
                            Image(systemName: "eye")
                                .foregroundStyle(revealSecret ? Color.blue : Color.black)
                        }
                        .buttonStyle(.borderless)
                    }

                    if revealSecret {
                        TextField("Confirm password", text: $viewModel.confirmSecret)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    } else {
                        SecureField("Confirm password", text: $viewModel.confirmSecret)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }
                }

                Section {

                    Button {

                        Task { await viewModel.exportPrivateKey() }

                    } label: {

                        HStack {

                            if viewModel.isAuthenticating { ProgressView() }

                            Label("Create Protected Backup", systemImage: "faceid")

                        }

                    }

                    .disabled(!viewModel.canCreateBackup)

                }

            } else {

                Section("CP-PRIV2 Backup") {

                    Text(viewModel.exportedPrivateKey)

                        .font(.system(.footnote, design: .monospaced))

                        .textSelection(.enabled)

                    Button {

                        UIPasteboard.general.string = viewModel.exportedPrivateKey

                    } label: {

                        Label("Copy Backup", systemImage: "doc.on.doc")

                    }

                }

                Section {

                    Button {

                        viewModel.clearBackup()

                        UIPasteboard.general.string = nil

                    } label: {

                        Label("Hide Private Key Backup", systemImage: "eye.slash")

                    }

                }

            }

            Section {

                Label("Anyone who gets both the CP-PRIV2 backup and its password may be able to decrypt messages intended for this identity. Keep them separate.", systemImage: "exclamationmark.shield.fill")

                    .font(.footnote)

                    .foregroundStyle(.orange)

            }

            if let errorMessage = viewModel.errorMessage {

                Section {

                    Label(errorMessage, systemImage: "exclamationmark.triangle.fill")

                        .foregroundStyle(.red)

                        .font(.footnote)

                }

            }

        }

        .navigationTitle("Private Key Backup")

        .navigationBarTitleDisplayMode(.inline)
    }

}
