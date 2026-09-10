import SwiftUI
import UIKit
import UniformTypeIdentifiers
import CryptoKit

struct CryptoDictionaryView: View {
    @State private var searchText = ""

    private let entries: [CryptoDictionaryEntry] = [
        .init(
            term: "AES-256-GCM",
            category: "Encryption Cipher",
            summary: "Authenticated symmetric encryption using a 256-bit AES key.",
            beginnerExplanation: "AES hides the content, while GCM also checks that the encrypted data was not changed. The same derived key is needed to encrypt and decrypt.",
            usedFor: "Text encryption, file encryption, and protected private-key backups.",
            note: "Ciphera offers this as the default symmetric cipher."
        ),
        .init(
            term: "ChaCha20-Poly1305",
            category: "Encryption Cipher",
            summary: "Authenticated symmetric encryption built from the ChaCha20 stream cipher and Poly1305 authenticator.",
            beginnerExplanation: "It serves the same job as AES-GCM in Ciphera: hide the content and detect tampering, but it uses a different cryptographic design.",
            usedFor: "Text and file encryption as an alternative to AES-256-GCM.",
            note: nil
        ),
        .init(
            term: "Curve25519 / X25519",
            category: "Key Agreement",
            summary: "Elliptic-curve Diffie-Hellman key agreement used to create a shared secret.",
            beginnerExplanation: "Your public key can be shared, while your private key stays secret. A sender combines their temporary private key with your public key, and you combine your private key with their temporary public key. Both sides arrive at the same shared secret.",
            usedFor: "The default “For Someone” recipient-encryption flow.",
            note: "X25519 creates key material; AES-GCM or ChaCha20-Poly1305 still encrypts the actual message."
        ),
        .init(
            term: "P-256",
            category: "Key Agreement",
            summary: "A NIST elliptic curve supported by CryptoKit for ECDH key agreement and ECDSA signatures.",
            beginnerExplanation: "P-256 is another public/private key system. In recipient mode, Ciphera uses it to agree on a shared secret before symmetric encryption.",
            usedFor: "Optional recipient key agreement and P-256 ECDSA signing.",
            note: nil
        ),
        .init(
            term: "P-384",
            category: "Key Agreement",
            summary: "A larger NIST elliptic curve for ECDH and ECDSA.",
            beginnerExplanation: "It follows the same general public/private-key idea as P-256, with a larger curve and key representation.",
            usedFor: "Optional recipient key agreement and P-384 ECDSA signing.",
            note: nil
        ),
        .init(
            term: "P-521",
            category: "Key Agreement",
            summary: "A NIST elliptic curve for ECDH key agreement and ECDSA signatures.",
            beginnerExplanation: "P-521 does not directly encrypt your text. Ciphera can use it to establish a shared secret, then AES or ChaCha encrypts the content.",
            usedFor: "Optional recipient key agreement and P-521 ECDSA signing.",
            note: nil
        ),
        .init(
            term: "Ed25519",
            category: "Digital Signature",
            summary: "A modern public-key signature scheme.",
            beginnerExplanation: "A signature does not hide a message. It lets another person check that the message was signed by the matching private key and that the message has not been modified.",
            usedFor: "Ciphera’s default signing tutorial and signing workflow.",
            note: "Signing and encryption solve different problems."
        ),
        .init(
            term: "ECDSA",
            category: "Digital Signature",
            summary: "Elliptic Curve Digital Signature Algorithm.",
            beginnerExplanation: "ECDSA creates a signature with a private key and verifies it with the corresponding public key. Ciphera supports ECDSA with P-256, P-384, and P-521.",
            usedFor: "Optional digital signatures.",
            note: nil
        ),
        .init(
            term: "SHA-256",
            category: "Hash & Key Derivation",
            summary: "A cryptographic hash function that maps data to a fixed 256-bit digest.",
            beginnerExplanation: "A hash is like a one-way fingerprint of data. Ciphera currently also uses SHA-256 as part of its learning-oriented secret-key derivation flow.",
            usedFor: "Key derivation, key IDs, and public-key fingerprints.",
            note: "The current password derivation is intentionally a learning implementation and should be hardened before production use."
        ),
        .init(
            term: "HKDF-SHA256",
            category: "Hash & Key Derivation",
            summary: "A key-derivation function based on HMAC-SHA256.",
            beginnerExplanation: "HKDF turns existing key material into a clean key for a specific purpose. In Ciphera it separates key-agreement or password-derived material from the final content-encryption key.",
            usedFor: "Secret mode and public-key recipient mode.",
            note: nil
        ),
        .init(
            term: "Salt",
            category: "Hash & Key Derivation",
            summary: "Random public data mixed into password-based key derivation.",
            beginnerExplanation: "The salt does not need to be secret. It helps ensure that the same password does not always lead to identical derived material across different encryptions.",
            usedFor: "Secret-protected CP1 messages and protected backups.",
            note: nil
        ),
        .init(
            term: "Nonce",
            category: "Encryption Metadata",
            summary: "A unique value used for one authenticated-encryption operation.",
            beginnerExplanation: "The nonce is not a password. It travels with the ciphertext and helps the cipher safely encrypt each message as a distinct operation.",
            usedFor: "AES-GCM and ChaCha20-Poly1305 payloads.",
            note: nil
        ),
        .init(
            term: "Authentication Tag",
            category: "Encryption Metadata",
            summary: "A value produced by authenticated encryption that is checked during decryption.",
            beginnerExplanation: "Think of the tag as a tamper check. If the encrypted content or the wrong key is used, verification fails instead of returning trusted plaintext.",
            usedFor: "AES-GCM and ChaCha20-Poly1305.",
            note: nil
        ),
        .init(
            term: "CP1",
            category: "Ciphera Format",
            summary: "Ciphera Portable Message Format version 1.",
            beginnerExplanation: "CP1 is the package around an encrypted text message. It carries the ciphertext plus non-secret information Ciphera needs to know how to decrypt it.",
            usedFor: "Portable encrypted text messages.",
            note: "CP1 is a Ciphera format, not a cryptographic algorithm."
        ),
        .init(
            term: "CP-PUB1 / CP-PUB2",
            category: "Ciphera Format",
            summary: "Portable public-key representations.",
            beginnerExplanation: "These values are meant to be shared. Other people use them when encrypting something specifically for your public/private key identity.",
            usedFor: "Public-key sharing and recipient encryption.",
            note: nil
        ),
        .init(
            term: "CP-PRIV1 / CP-PRIV2",
            category: "Ciphera Format",
            summary: "Ciphera private-key backup formats.",
            beginnerExplanation: "CP-PRIV1 is the sensitive raw portable backup. CP-PRIV2 protects the private-key backup with a secret before export.",
            usedFor: "Identity backup and recovery.",
            note: "Private-key backups must never be treated like public keys."
        ),
        .init(
            term: "CP-SIG1",
            category: "Ciphera Format",
            summary: "Ciphera’s portable signature package.",
            beginnerExplanation: "It packages the signature information needed for another Ciphera instance to verify a signed message.",
            usedFor: "Digital signature verification.",
            note: nil
        ),
        .init(
            term: "CPFILE1",
            category: "Ciphera Format",
            summary: "Ciphera’s encrypted-file container marker.",
            beginnerExplanation: "It identifies encrypted file data and stores the metadata needed to reverse the encryption when the correct secret or recipient key is available.",
            usedFor: "File encryption and decryption.",
            note: nil
        )
    ]

    private var filteredEntries: [CryptoDictionaryEntry] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return entries }
        return entries.filter {
            $0.term.localizedCaseInsensitiveContains(query)
            || $0.category.localizedCaseInsensitiveContains(query)
            || $0.summary.localizedCaseInsensitiveContains(query)
        }
    }

    private var categories: [String] {
        Array(Set(filteredEntries.map(\.category))).sorted()
    }

    var body: some View {
        List {
            Section {
                Text("Plain-language references for the cryptography and portable formats currently used by Ciphera.")
                    .foregroundStyle(.secondary)
            }

            ForEach(categories, id: \.self) { category in
                Section(category) {
                    ForEach(filteredEntries.filter { $0.category == category }) { entry in
                        NavigationLink {
                            CryptoDictionaryDetailView(entry: entry)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(entry.term)
                                    .font(.body.weight(.medium))
                                Text(entry.summary)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }
            }
        }
        .navigationTitle("Crypto Dictionary")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, prompt: "Search ciphers, keys, formats")
    }
}
