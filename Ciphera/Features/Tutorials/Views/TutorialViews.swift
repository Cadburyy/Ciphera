import CryptoKit
import SwiftUI
import UniformTypeIdentifiers

struct TutorialCenterView: View {
    var body: some View {
        List(TutorialKind.allCases) { kind in
            NavigationLink {
                InteractiveTutorialView(kind: kind)
            } label: {
                Label(kind.listTitle, systemImage: kind.symbol)
            }
        }
        .navigationTitle("Guided Tutorials")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            Text("Tutorials are educational and do not upload or save your practice text.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(.bar)
        }
    }
}

struct InteractiveTutorialView: View {
    @Environment(\.dismiss) private var dismiss

    let kind: TutorialKind

    @State private var step = 0
    @State private var text = "Hello Ciphera"
    @State private var secret = ""
    @State private var encryptedText = ""
    @State private var decryptedText = ""
    @State private var tutorialPrivateKeyData: Data?
    @State private var tutorialPublicKey = ""
    @State private var publicKey = ""
    @State private var backupPreviewReady = false
    @State private var acknowledgedBackupRisk = false
    @State private var selectedFileURL: URL?
    @State private var selectedFileData: Data?
    @State private var encryptedFilePackage = ""
    @State private var fileRoundTripSucceeded = false
    @State private var importingFile = false
    @State private var signature = ""
    @State private var verified = false
    @State private var tamperText = ""
    @State private var tamperFailed = false
    @State private var revealSecret = false
    @State private var errorMessage: String?

    var body: some View {
        Form {
            Section {
                TutorialProgressHeader(
                    symbol: kind.symbol,
                    currentStep: step + 1,
                    totalSteps: 5
                )
            }

            stepContent

            if let errorMessage {
                Section {
                    Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                        .font(.footnote)
                }
            }
        }
        .navigationTitle(kind.title)
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            TutorialNavigationBar(
                showsBack: step > 0,
                primaryTitle: primaryTitle,
                primaryEnabled: primaryEnabled,
                back: { step -= 1 },
                primary: primaryAction
            )
        }
        .fileImporter(
            isPresented: $importingFile,
            allowedContentTypes: [.data],
            allowsMultipleSelection: false,
            onCompletion: importPracticeFile
        )
    }

    @ViewBuilder private var stepContent: some View {
        switch kind {
        case .secret: secretStep
        case .recipient: recipientStep
        case .backup: backupStep
        case .file: fileStep
        case .sign: signStep
        }
    }

    private var primaryTitle: String {
        if step == 4 { return "Finish Tutorial" }

        switch (kind, step) {
        case (.secret, 2), (.recipient, 2), (.file, 2): return "Encrypt"
        case (.secret, 3), (.recipient, 3), (.file, 3): return "Decrypt"
        case (.recipient, 1): return "Create Tutorial Key"
        case (.backup, 0): return "Show My Public Key"
        case (.backup, 2): return "Preview Safe Backup"
        case (.sign, 1): return "Sign"
        case (.sign, 2): return "Verify"
        case (.sign, 3): return "Test Tampered Text"
        default: return "Continue"
        }
    }

    private var primaryEnabled: Bool {
        if step == 4 { return true }

        switch (kind, step) {
        case (.secret, 0), (.recipient, 0), (.sign, 0):
            return !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case (.secret, 1), (.file, 1):
            return secret.count >= 8
        case (.secret, 2):
            return !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && secret.count >= 8
        case (.secret, 3):
            return secret.count >= 8 && !encryptedText.isEmpty
        case (.recipient, 1):
            return true
        case (.recipient, 2):
            return !tutorialPublicKey.isEmpty
        case (.recipient, 3):
            return !encryptedText.isEmpty && tutorialPrivateKeyData != nil
        case (.backup, 1):
            return !publicKey.isEmpty
        case (.backup, 2):
            return true
        case (.backup, 3):
            return acknowledgedBackupRisk
        case (.file, 0):
            return selectedFileData != nil
        case (.file, 2):
            return selectedFileData != nil && secret.count >= 8
        case (.file, 3):
            return !encryptedFilePackage.isEmpty
        case (.sign, 1):
            return !text.isEmpty
        case (.sign, 2):
            return !signature.isEmpty
        case (.sign, 3):
            return !signature.isEmpty && !tamperText.isEmpty
        default:
            return true
        }
    }

    private func primaryAction() {
        errorMessage = nil

        do {
            if step == 4 {
                dismiss()
                return
            }

            switch (kind, step) {
            case (.secret, 2):
                encryptedText = try CryptoService.encryptWithSecret(
                    text,
                    secret: secret,
                    algorithm: .aes256GCM
                )
                step = 3
            case (.secret, 3):
                decryptedText = try CryptoService.decryptWithSecret(encryptedText, secret: secret)
                step = 4
            case (.recipient, 1):
                let key = Curve25519.KeyAgreement.PrivateKey()
                tutorialPrivateKeyData = key.rawRepresentation
                tutorialPublicKey = "CP-PUB1:" + key.publicKey.rawRepresentation.base64EncodedString()
                step = 2
            case (.recipient, 2):
                encryptedText = try CryptoService.encryptForRecipient(
                    text,
                    recipientPublicKeyText: tutorialPublicKey,
                    algorithm: .aes256GCM
                )
                step = 3
            case (.recipient, 3):
                guard let tutorialPrivateKeyData else { return }
                decryptedText = try CryptoService.decryptForTutorialRecipient(
                    encryptedText,
                    privateKeyData: tutorialPrivateKeyData
                )
                step = 4
            case (.backup, 0):
                publicKey = try CryptoService.myPublicKeyText()
                step = 1
            case (.backup, 2):
                backupPreviewReady = true
                step = 3
            case (.file, 2):
                guard let selectedFileData, let selectedFileURL else { return }
                encryptedFilePackage = try CryptoService.encryptFileText(
                    selectedFileData,
                    filename: selectedFileURL.lastPathComponent,
                    contentType: UTType(filenameExtension: selectedFileURL.pathExtension)?.identifier,
                    secret: secret,
                    algorithm: .aes256GCM
                )
                step = 3
            case (.file, 3):
                guard !encryptedFilePackage.isEmpty else { return }
                let opened = try CryptoService.decryptFileText(encryptedFilePackage, secret: secret)
                fileRoundTripSucceeded = opened.data == selectedFileData
                    && opened.filename == selectedFileURL?.lastPathComponent
                step = 4
            case (.sign, 1):
                signature = try CryptoService.sign(text, algorithm: .ed25519)
                step = 2
            case (.sign, 2):
                verified = try CryptoService.verify(text, signatureText: signature)
                step = 3
            case (.sign, 3):
                tamperFailed = !(try CryptoService.verify(tamperText, signatureText: signature))
                step = 4
            default:
                step += 1
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func importPracticeFile(_ result: Result<[URL], Error>) {
        do {
            guard let url = try result.get().first else { return }
            let accessed = url.startAccessingSecurityScopedResource()
            defer { if accessed { url.stopAccessingSecurityScopedResource() } }

            selectedFileURL = url
            selectedFileData = try Data(contentsOf: url)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @ViewBuilder private var secretStep: some View {
        switch step {
        case 0:
            TutorialStepCard(title: "Write a practice message", detail: "This stays in the tutorial and will be encrypted with a real CP1 round trip.") {
                tutorialEditor($text, height: 130)
            }
        case 1:
            TutorialStepCard(title: "Create a secret", detail: "Use at least 8 characters. You will need the same secret to open the message.") {
                secretField("At least 8 characters")
            }
        case 2:
            TutorialStepCard(
                title: "See what encryption will do",
                detail: "Encryption turns readable plaintext into ciphertext. Your secret helps derive the key, but the secret itself is not stored inside the CP1 message."
            ) {
                TutorialProcessView(
                    items: [
                        .init(symbol: "text.alignleft", title: "Plaintext", detail: text),
                        .init(symbol: "key.fill", title: "Your secret", detail: "Used to derive a 256-bit key"),
                        .init(symbol: "shield.lefthalf.filled", title: "AES-256-GCM", detail: "Encrypts and authenticates the message"),
                        .init(symbol: "shippingbox.fill", title: "CP1 package", detail: "Ciphertext with safe-to-share metadata")
                    ]
                )
            }
        case 3:
            TutorialStepCard(
                title: "Your message is now encrypted",
                detail: "The CP1 result below is what you can copy or send. To reverse it, Ciphera needs this CP1 message and the same secret."
            ) {
                TutorialProcessView(
                    items: [
                        .init(symbol: "doc.plaintext", title: "Original", detail: text),
                        .init(symbol: "arrow.down", title: "Encrypted with", detail: "AES-256-GCM using a key derived from your secret"),
                        .init(symbol: "lock.doc.fill", title: "Encrypted result", detail: shortened(encryptedText))
                    ]
                )
                secretField("Enter the same secret")
            }
        default:
            TutorialStepCard(
                title: "You completed the round trip",
                detail: "Decryption recreated the same key from your secret, verified the authentication tag, and converted the ciphertext back into readable plaintext."
            ) {
                TutorialProcessView(
                    items: [
                        .init(symbol: "lock.doc.fill", title: "CP1 ciphertext", detail: "Encrypted input"),
                        .init(symbol: "key.fill", title: "Same secret", detail: "Recreates the same encryption key"),
                        .init(symbol: "lock.open.fill", title: "AES-GCM decrypt", detail: "Verifies integrity and opens the message"),
                        .init(symbol: "text.alignleft", title: "Plaintext", detail: decryptedText)
                    ]
                )
                messageResult
            }
        }
    }

    @ViewBuilder private var recipientStep: some View {
        switch step {
        case 0:
            TutorialStepCard(title: "Write a practice message", detail: "This lesson uses a temporary recipient identity, never your real one.") {
                tutorialEditor($text, height: 130)
            }
        case 1:
            TutorialStepCard(title: "Create a tutorial recipient", detail: "Create an isolated Curve25519 public key for this lesson.") { EmptyView() }
        case 2:
            TutorialStepCard(
                title: "See how recipient encryption works",
                detail: "The public key does not encrypt the text by itself. Curve25519 first creates shared key material, then AES-256-GCM encrypts the actual message."
            ) {
                TutorialProcessView(
                    items: [
                        .init(symbol: "key.horizontal.fill", title: "Recipient public key", detail: shortened(tutorialPublicKey)),
                        .init(symbol: "arrow.triangle.2.circlepath", title: "Curve25519", detail: "Creates a shared secret with a temporary sender key"),
                        .init(symbol: "function", title: "HKDF-SHA256", detail: "Derives the content-encryption key"),
                        .init(symbol: "shield.lefthalf.filled", title: "AES-256-GCM", detail: "Encrypts the plaintext into CP1")
                    ]
                )
            }
        case 3:
            TutorialStepCard(
                title: "The CP1 is locked to this recipient",
                detail: "The temporary public key is safe to include in CP1. The matching recipient private key is still required to recreate the shared secret and decrypt."
            ) {
                TutorialProcessView(
                    items: [
                        .init(symbol: "lock.doc.fill", title: "Encrypted result", detail: shortened(encryptedText)),
                        .init(symbol: "key.fill", title: "Recipient private key", detail: "Never included in the CP1 message"),
                        .init(symbol: "lock.open.fill", title: "Decrypt", detail: "Recreates the shared key and opens the message")
                    ]
                )
            }
        default:
            TutorialStepCard(
                title: "Only the matching key opened it",
                detail: "The tutorial recipient recovered the original plaintext. Your real Ciphera identity was never changed."
            ) {
                messageResult
            }
        }
    }

    @ViewBuilder private var backupStep: some View {
        switch step {
        case 0:
            TutorialStepCard(title: "Start with the public half", detail: "Show the actual public key for this iPhone. It is safe to share.") { EmptyView() }
        case 1:
            TutorialStepCard(title: "This public key is shareable", detail: "Messages intended for it require the matching private half to open.") {
                monospacedValue(publicKey)
            }
        case 2:
            TutorialStepCard(
                title: "Understand a protected backup",
                detail: "A protected backup takes the private key you normally never see and encrypts it before it leaves the device. This tutorial only shows the process — it does not export your real private key."
            ) {
                TutorialProcessView(
                    items: [
                        .init(symbol: "key.fill", title: "Private key", detail: "The sensitive identity secret normally kept in Keychain"),
                        .init(symbol: "lock.fill", title: "Backup secret", detail: "Used to derive a protection key"),
                        .init(symbol: "shield.lefthalf.filled", title: "AES-256-GCM", detail: "Encrypts the private-key backup"),
                        .init(symbol: "externaldrive.badge.checkmark", title: "CP-PRIV2", detail: "Portable protected backup")
                    ]
                )
            }
        case 3:
            TutorialStepCard(title: "Keep the two secrets apart", detail: "A real CP-PRIV2 backup and its password must be stored separately. Anyone who has both may be able to restore your identity.") {
                Toggle("I understand that a backup and its password must stay separate.", isOn: $acknowledgedBackupRisk)
            }
        default:
            TutorialStepCard(title: "You understand the safe path", detail: "When ready, use My Key → Backup Private Key to authenticate and create a real protected backup.") {
                Label("This tutorial did not modify your identity.", systemImage: "checkmark.shield.fill")
                    .foregroundStyle(.green)
            }
        }
    }

    @ViewBuilder private var fileStep: some View {
        switch step {
        case 0:
            TutorialStepCard(title: "Choose something to protect", detail: "Pick a photo, ZIP, PDF, document, or another small file. Ciphera detects the item type, then encrypts its underlying bytes.") {
                Button { importingFile = true } label: {
                    Label("Choose File", systemImage: "folder.fill")
                }
                    .buttonStyle(.bordered)
                if let selectedFileURL {
                    Label(selectedFileURL.lastPathComponent, systemImage: "folder.fill")
                }
            }
        case 1:
            TutorialStepCard(title: "Create a secret", detail: "Use at least 8 characters. The same secret opens the encrypted file.") {
                secretField("At least 8 characters")
            }
        case 2:
            TutorialStepCard(
                title: "See what happens to the file",
                detail: "Ciphera reads the item as data, derives a key from your secret, encrypts the bytes, and creates a copyable CPFILE1 text package that remembers the original filename and type."
            ) {
                TutorialProcessView(
                    items: [
                        .init(symbol: "folder.fill", title: "Original file", detail: selectedFileURL?.lastPathComponent ?? "Selected file"),
                        .init(symbol: "key.fill", title: "Your secret", detail: "Derives the file-encryption key"),
                        .init(symbol: "shield.lefthalf.filled", title: "AES-256-GCM", detail: "Encrypts and authenticates the file bytes"),
                        .init(symbol: "doc.badge.lock", title: "CPFILE1", detail: "Copyable Base64-encoded encrypted package")
                    ]
                )
            }
        case 3:
            TutorialStepCard(
                title: "The file bytes are encrypted",
                detail: "Decrypting reverses the process with the same secret, checks integrity, and restores the original bytes. The result is only saved if you choose to save it."
            ) {
                TutorialProcessView(
                    items: [
                        .init(symbol: "doc.badge.lock", title: "Encrypted package", detail: "CPFILE1 text is ready to copy or share"),
                        .init(symbol: "key.fill", title: "Same secret", detail: "Recreates the same key"),
                        .init(symbol: "lock.open.fill", title: "Decrypt & verify", detail: "Restores the original filename and bytes before you choose whether to save")
                    ]
                )
            }
        default:
            TutorialStepCard(title: "File round trip complete", detail: fileRoundTripSucceeded ? "The restored filename and file contents match." : "The file did not match after decryption.") {
                Label(fileRoundTripSucceeded ? "They match" : "Check the result", systemImage: fileRoundTripSucceeded ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundStyle(fileRoundTripSucceeded ? .green : .red)
            }
        }
    }

    @ViewBuilder private var signStep: some View {
        switch step {
        case 0:
            TutorialStepCard(title: "Write something to sign", detail: "A signature proves the message has not changed; it does not hide its text.") {
                tutorialEditor($text, height: 130)
            }
        case 1:
            TutorialStepCard(
                title: "See what signing does",
                detail: "Signing does not encrypt or hide the message. Your private signing key creates proof tied to this exact text."
            ) {
                TutorialProcessView(
                    items: [
                        .init(symbol: "text.alignleft", title: "Message", detail: text),
                        .init(symbol: "key.fill", title: "Private signing key", detail: "Stays protected in Keychain"),
                        .init(symbol: "signature", title: "Ed25519", detail: "Creates a digital signature"),
                        .init(symbol: "shippingbox.fill", title: "CP-SIG1", detail: "Portable signature package")
                    ]
                )
            }
        case 2:
            TutorialStepCard(
                title: "Verify the signature",
                detail: "Verification uses the public signing key. A valid result means the signature matches this exact message and key."
            ) {
                TutorialProcessView(
                    items: [
                        .init(symbol: "text.alignleft", title: "Message", detail: text),
                        .init(symbol: "signature", title: "Signature", detail: shortened(signature)),
                        .init(symbol: "checkmark.shield", title: "Verify", detail: "Public-key check — no private key is needed")
                    ]
                )
            }
        case 3:
            TutorialStepCard(title: "Try a tamper test", detail: "Change even one character. The signature should no longer verify.") {
                tutorialEditor($tamperText, height: 110)
                    .onAppear { if tamperText.isEmpty { tamperText = text + " (changed)" } }
            }
        default:
            TutorialStepCard(title: "You saw both outcomes", detail: tamperFailed && verified ? "The original verified, and the changed text failed verification." : "Try the tamper test again with changed text.") {
                Label(tamperFailed ? "Tampering was detected" : "Tamper test needs a changed message", systemImage: tamperFailed ? "checkmark.shield.fill" : "exclamationmark.triangle.fill")
                    .foregroundStyle(tamperFailed ? .green : .orange)
            }
        }
    }

    private var messageResult: some View {
        VStack(alignment: .leading, spacing: 10) {
            LabeledContent("Original", value: text)
            LabeledContent("Decrypted", value: decryptedText)
            Label(text == decryptedText ? "They match" : "They do not match", systemImage: text == decryptedText ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(text == decryptedText ? .green : .red)
        }
    }

    private func shortened(_ value: String, limit: Int = 44) -> String {
        guard value.count > limit else { return value }
        return String(value.prefix(limit)) + "…"
    }

    private func secretField(_ prompt: String) -> some View {
        HStack {
            Group {
                if revealSecret {
                    TextField(prompt, text: $secret)
                } else {
                    SecureField(prompt, text: $secret)
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
            .accessibilityLabel(revealSecret ? "Hide secret" : "Show secret")
        }
    }

    private func tutorialEditor(_ binding: Binding<String>, height: CGFloat) -> some View {
        TextEditor(text: binding)
            .frame(minHeight: height)
            .scrollContentBackground(.hidden)
    }

    private func monospacedValue(_ value: String, limit: Int? = nil) -> some View {
        Text(value)
            .lineLimit(limit)
            .font(.system(.caption, design: .monospaced))
            .textSelection(.enabled)
    }
}

private struct TutorialProcessItem: Identifiable {
    let id = UUID()
    let symbol: String
    let title: String
    let detail: String
}

private struct TutorialProcessView: View {
    let items: [TutorialProcessItem]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: item.symbol)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.tint)
                        .frame(width: 28, height: 28)
                        .background(Color.accentColor.opacity(0.10), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                    VStack(alignment: .leading, spacing: 3) {
                        Text(item.title)
                            .font(.subheadline.weight(.semibold))
                        Text(item.detail)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.vertical, 8)

                if index < items.count - 1 {
                    Image(systemName: "arrow.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                        .padding(.leading, 8)
                }
            }
        }
        .accessibilityElement(children: .contain)
    }
}

private struct TutorialProgressHeader: View {
    let symbol: String
    let currentStep: Int
    let totalSteps: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Image(systemName: symbol).foregroundStyle(.tint)
                Text("\(currentStep) of \(totalSteps)").font(.subheadline.weight(.semibold))
                Spacer()
            }
            ProgressView(value: Double(currentStep), total: Double(totalSteps))
                .tint(.accentColor)
        }
        .padding(.vertical, 4)
    }
}

private struct TutorialNavigationBar: View {
    let showsBack: Bool
    let primaryTitle: String
    let primaryEnabled: Bool
    let back: () -> Void
    let primary: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            if showsBack {
                Button("Back", action: back)
                    .buttonStyle(.bordered)
            }
            Button(primaryTitle, action: primary)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .foregroundStyle(
                    primaryEnabled
                        ? Color.white
                        : Color(uiColor: .secondaryLabel)
                )
                .tint(
                    primaryEnabled
                        ? Color.accentColor
                        : Color(uiColor: .tertiarySystemFill)
                )
                .disabled(!primaryEnabled)
                .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.bar)
    }
}

private struct TutorialStepCard<Content: View>: View {
    let title: String
    let detail: String
    let content: Content

    init(
        title: String,
        detail: String,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.detail = detail
        self.content = content()
    }

    var body: some View {
        Section {
            Text(detail)
                .foregroundStyle(.secondary)
            content
        } header: {
            Text(title)
        }
    }
}
