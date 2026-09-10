import SwiftUI
import UIKit
import UniformTypeIdentifiers
import CryptoKit

struct ToolsView: View {
    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink {
                        TutorialCenterView()
                    } label: {
                        Label("Guided Tutorials", systemImage: "graduationcap.fill")
                    }

                    NavigationLink {
                        CryptoDictionaryView()
                    } label: {
                        Label("Crypto Dictionary", systemImage: "books.vertical.fill")
                    }
                } header: {
                    Text("Learn")
                } footer: {
                    Text("Practice features step by step, or look up the cryptography and Ciphera formats used by the app.")
                }

                Section("Protect More Than Text") {
                    NavigationLink {
                        FileCryptView()
                    } label: {
                        Label("Encrypt Files & Photos", systemImage: "folder.fill")
                    }

                    NavigationLink {
                        SignVerifyView()
                    } label: {
                        Label("Sign & Verify", systemImage: "signature")
                    }
                }

                Section {
                    NavigationLink {
                        PublicKeyLabView()
                    } label: {
                        Label("Public Key Algorithms", systemImage: "key.radiowaves.forward")
                    }
                } header: {
                    Text("Advanced")
                } footer: {
                    Text("Explore Curve25519, P-256, P-384, and P-521. Curve25519 remains the recommended default for everyday recipient encryption.")
                }
            }
            .navigationTitle("Tools")
        }
    }
}
