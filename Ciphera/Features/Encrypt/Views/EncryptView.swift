import SwiftUI
import UIKit
import UniformTypeIdentifiers
import CryptoKit

struct EncryptView: View {

    @StateObject private var viewModel = EncryptViewModel()

    var body: some View {

        NavigationStack(path: $viewModel.path) {

            Form {

                Section {

                    Picker("Protection", selection: $viewModel.mode) {

                        Text("With a Secret").tag(ProtectionMode.secret)

                        Text("For Someone").tag(ProtectionMode.recipient)

                    }

                    .pickerStyle(.segmented)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))

                } header: {

                    Text("Protection")

                } footer: {

                    Text(viewModel.mode.subtitle)

                }

                Section("Your Text") {

                    TextEditor(text: $viewModel.plaintext)

                        .frame(minHeight: 150)

                        .scrollContentBackground(.hidden)

                }

                Section {

                    Menu {

                        ForEach(SymmetricCipher.allCases) { cipher in

                            Button {

                                viewModel.algorithm = cipher

                            } label: {

                                if viewModel.algorithm == cipher {

                                    Label(cipher.title, systemImage: "checkmark")

                                } else {

                                    Text(cipher.title)

                                }

                            }

                        }

                    } label: {

                        HStack {

                            Label("Algorithm", systemImage: "shield.lefthalf.filled")

                            Spacer()

                            Text(viewModel.algorithm.title)

                                .foregroundStyle(.secondary)

                            Image(systemName: "chevron.up.chevron.down")

                                .font(.caption2)

                                .foregroundStyle(.tertiary)

                        }

                    }

                    .foregroundStyle(.primary)

                } footer: {

                    Text(viewModel.algorithm.shortDescription)

                }

                if viewModel.mode == .secret {

                    Section {

                        HStack {

                            Group {

                                if viewModel.revealSecret {

                                    TextField("Secret", text: $viewModel.secret)

                                } else {

                                    SecureField("Secret", text: $viewModel.secret)

                                }

                            }

                            .textInputAutocapitalization(.never)

                            .autocorrectionDisabled()

                            Button {

                                viewModel.revealSecret.toggle()

                            } label: {

                                Image(systemName: "eye")
                                    .foregroundStyle(viewModel.revealSecret ? Color.blue : Color.black)

                            }

                            .buttonStyle(.borderless)

                            .accessibilityLabel(viewModel.revealSecret ? "Hide secret" : "Show secret")

                        }

                    } header: {

                        Text("Encryption Secret")

                    } footer: {

                        if !viewModel.secret.isEmpty && viewModel.secret.count < 8 {
                            Text("Use at least 8 characters.")
                                .foregroundStyle(.red)
                        } else {
                            Text("Not saved. The same secret is required to decrypt this CP1 message.")
                        }

                    }

                } else {

                    Section {

                        TextField("CP-PUB1 public key", text: $viewModel.recipientPublicKey, axis: .vertical)

                            .font(.system(.footnote, design: .monospaced))

                            .lineLimit(2, reservesSpace: true)

                            .textInputAutocapitalization(.never)

                            .autocorrectionDisabled()

                        if let fingerprint = viewModel.recipientFingerprint {
                            LabeledContent("Fingerprint", value: fingerprint)
                                .font(.subheadline)
                        } else if !viewModel.recipientPublicKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Label("Invalid Ciphera public key", systemImage: "exclamationmark.triangle.fill")
                                .font(.footnote)
                                .foregroundStyle(.red)
                        }

                        Button {
                            viewModel.pastePublicKey(UIPasteboard.general.string)
                        } label: {
                            Label("Paste Public Key", systemImage: "doc.on.clipboard")
                        }

                    } header: {

                        Text("Recipient Public Key")

                    } footer: {

                        Text("Paste the recipient’s CP-PUB1 public key. Public keys are safe to share.")

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

                    Button(action: viewModel.encrypt) {

                        Label(

                            viewModel.mode == .secret ? "Encrypt" : "Encrypt for Recipient",

                            systemImage: viewModel.mode == .secret ? "lock.fill" : "person.badge.key.fill"

                        )

                        .fontWeight(.semibold)
                        .foregroundStyle(
                            viewModel.canEncrypt
                                ? Color.white
                                : Color(uiColor: .secondaryLabel)
                        )
                        .frame(maxWidth: .infinity)

                    }

                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .tint(
                        viewModel.canEncrypt
                            ? Color.accentColor
                            : Color(uiColor: .tertiarySystemFill)
                    )
                    .disabled(!viewModel.canEncrypt)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))

                }

            }

            .navigationTitle("Encrypt")

            .navigationDestination(for: EncryptionResult.self) { result in

                EncryptionResultView(result: result)

            }

        }

    }

}
