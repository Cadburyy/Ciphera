import SwiftUI
import UIKit
import UniformTypeIdentifiers
import CryptoKit

struct PublicKeyLabView: View {
    @StateObject private var viewModel = PublicKeyLabViewModel()
    @State private var showReset = false

    var body: some View {
        Form {
            Section {
                Picker("Key Type", selection: $viewModel.curve) {
                    ForEach(PublicKeyCurve.allCases) { item in
                        Text(item.title).tag(item)
                    }
                }
                .onChange(of: viewModel.curve) { _, _ in viewModel.load() }
            } header: {
                Text("Key Agreement")
            } footer: {
                Text(viewModel.curve.shortDescription)
            }

            Section("My Public Key") {
                if viewModel.publicKey.isEmpty {
                    ProgressView()
                } else {
                    Text(viewModel.publicKey)
                        .font(.system(.footnote, design: .monospaced))
                        .textSelection(.enabled)
                    LabeledContent("Fingerprint", value: viewModel.fingerprint)
                    Button {
                        UIPasteboard.general.string = viewModel.publicKey
                    } label: {
                        Label("Copy Public Key", systemImage: "doc.on.doc")
                    }
                }
            }

            if let errorMessage = viewModel.errorMessage {
                Section { Label(errorMessage, systemImage: "exclamationmark.triangle.fill").foregroundStyle(.red) }
            }
        }
        .navigationTitle("Public Key Algorithms")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                if !viewModel.publicKey.isEmpty {
                    ShareLink(item: viewModel.publicKey) { Image(systemName: "square.and.arrow.up") }
                }
                Menu {
                    Button(role: .destructive) { showReset = true } label: { Label("Generate New \(viewModel.curve.title) Key", systemImage: "arrow.triangle.2.circlepath") }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .confirmationDialog("Generate a new \(viewModel.curve.title) key?", isPresented: $showReset, titleVisibility: .visible) {
            Button("Generate New Key", role: .destructive) { viewModel.reset() }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Messages encrypted for the current \(viewModel.curve.title) public key will no longer decrypt unless you still have its old private key.")
        }        .task { viewModel.load() }
    }

}
