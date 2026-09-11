import SwiftUI
import UIKit
import UniformTypeIdentifiers
import CryptoKit

struct DecryptView: View {

    @StateObject private var viewModel = DecryptViewModel()

    var body: some View {

        NavigationStack(path: $viewModel.path) {

            Form {

                Section {

                    TextField("Paste a CP1 message", text: $viewModel.encryptedText)
                        .font(.system(.footnote, design: .monospaced))
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .onChange(of: viewModel.encryptedText) { _, _ in viewModel.detect() }

                    Button {
                        viewModel.setEncryptedText(UIPasteboard.general.string)
                    } label: {
                        Label("Paste CP1 Message", systemImage: "doc.on.clipboard")
                    }

                } header: {

                    Text("CP1 Message")

                } footer: {

                    Text("Paste a Ciphera CP1 message here. Ciphera will detect how it was protected and show what is required to decrypt it.")

                }

                if let info = viewModel.detectedInfo {

                    Section("Detected") {

                        LabeledContent(

                            "Protection",

                            value: info.mode == .secret ? "With a Secret" : "For Someone"

                        )

                        LabeledContent(

                            "Algorithm",

                            value: info.mode == .secret ? info.algorithm.title : "Curve25519 + \(info.algorithm.title)"

                        )

                    }

                    if info.mode == .secret {

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
                                Text("Enter the same secret used when this CP1 message was encrypted.")
                            }

                        }

                    } else {

                        Section {

                            Label("Ciphera will use the private Curve25519 key protected in this iPhone’s Keychain.", systemImage: "iphone.and.arrow.forward")

                                .font(.subheadline)

                        } header: {

                            Text("Recipient Key")

                        }

                    }

                } else if !viewModel.encryptedText.isEmpty {

                    Section {

                        Label("Paste a complete Ciphera message beginning with CP1:.", systemImage: "questionmark.circle")

                            .foregroundStyle(.secondary)

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

                    Button(action: viewModel.decrypt) {

                        Label("Decrypt", systemImage: "lock.open.fill")

                            .fontWeight(.semibold)
                            .foregroundStyle(
                                viewModel.canDecrypt
                                    ? Color.white
                                    : Color(uiColor: .secondaryLabel)
                            )
                            .frame(maxWidth: .infinity)

                    }

                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .tint(
                        viewModel.canDecrypt
                            ? Color.accentColor
                            : Color(uiColor: .tertiarySystemFill)
                    )
                    .disabled(!viewModel.canDecrypt)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))

                }

            }

            .navigationTitle("Decrypt")

            .navigationDestination(for: DecryptionResult.self) { result in

                DecryptionResultView(result: result)

            }

        }

    }

}
