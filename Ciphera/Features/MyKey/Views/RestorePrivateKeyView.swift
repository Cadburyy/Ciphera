import SwiftUI
import UIKit
import UniformTypeIdentifiers
import CryptoKit

struct RestorePrivateKeyView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = RestorePrivateKeyViewModel()
    @State private var revealSecret = false
    @State private var showReplaceConfirmation = false

    let onImported: (String) -> Void

    var body: some View {

        Form {

            Section {

                TextEditor(text: $viewModel.privateKeyText)

                    .font(.system(.footnote, design: .monospaced))

                    .frame(minHeight: 170)

                    .scrollContentBackground(.hidden)

                    .textInputAutocapitalization(.never)

                    .autocorrectionDisabled()

                Button {

                    viewModel.privateKeyText = UIPasteboard.general.string ?? ""

                } label: {

                    Label("Paste Private Key Backup", systemImage: "doc.on.clipboard")

                }

            } header: {

                Text("Private Key Backup")

            } footer: {

                Text("CP-PRIV2 is password-protected. Legacy CP-PRIV1 backups are still accepted for compatibility.")

            }

            if viewModel.needsBackupPassword {
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
                }
            }

            if let errorMessage = viewModel.errorMessage {

                Section {

                    Label(errorMessage, systemImage: "exclamationmark.triangle.fill")

                        .foregroundStyle(.red)

                        .font(.footnote)

                }

            }

            Section {

                Button {

                    showReplaceConfirmation = true

                } label: {

                    HStack {

                        if viewModel.isAuthenticating { ProgressView() }

                        Label("Restore This Key", systemImage: "key.horizontal.fill")

                            .fontWeight(.semibold)

                            .frame(maxWidth: .infinity)

                    }

                }

                .disabled(!viewModel.canRestore)

            }

        }

        .navigationTitle("Restore Key")

        .navigationBarTitleDisplayMode(.inline)

        .confirmationDialog(

            "Replace the private key on this iPhone?",

            isPresented: $showReplaceConfirmation,

            titleVisibility: .visible

        ) {

            Button("Replace & Restore", role: .destructive) {

                Task {
                    if let publicKey = await viewModel.restore() {
                        onImported(publicKey)
                        dismiss()
                    }
                }

            }

            Button("Cancel", role: .cancel) { }

        } message: {

            Text("Messages encrypted for the current public key may stop decrypting unless its private key was backed up.")

        }

    }

}
