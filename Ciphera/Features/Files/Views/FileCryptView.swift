import SwiftUI
import UIKit
import UniformTypeIdentifiers
import PhotosUI

struct FileCryptView: View {
    @StateObject private var viewModel = FileCryptViewModel()
    @State private var importing = false
    @State private var importingPackageText = false
    @State private var photoSelection: PhotosPickerItem?
    @State private var resultDestination: FileCryptResultDestination?
    @State private var showingResult = false

    var body: some View {
        Form {
            Section {
                Picker("Action", selection: $viewModel.mode) {
                    ForEach(FileCryptMode.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                .onChange(of: viewModel.mode) { _, _ in
                    photoSelection = nil
                    viewModel.resetSelection()
                }
            }

            if viewModel.mode == .encrypt {
                encryptSections
            } else {
                decryptSections
            }

            if let errorMessage = viewModel.errorMessage {
                Section {
                    Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle("Files & Photos")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $showingResult) {
            if let resultDestination {
                switch resultDestination {
                case .encrypted(let result):
                    FileEncryptionResultView(result: result)
                case .decrypted(let result):
                    FileDecryptionResultView(result: result)
                }
            }
        }
        .fileImporter(
            isPresented: $importing,
            allowedContentTypes: [.item],
            allowsMultipleSelection: false
        ) { result in
            do {
                guard let url = try result.get().first else { return }
                let accessed = url.startAccessingSecurityScopedResource()
                defer { if accessed { url.stopAccessingSecurityScopedResource() } }
                viewModel.loadSelectedFile(url: url, data: try Data(contentsOf: url))
            } catch {
                viewModel.errorMessage = error.localizedDescription
            }
        }
        .fileImporter(
            isPresented: $importingPackageText,
            allowedContentTypes: [.plainText, .text, .data],
            allowsMultipleSelection: false
        ) { result in
            do {
                guard let url = try result.get().first else { return }
                let accessed = url.startAccessingSecurityScopedResource()
                defer { if accessed { url.stopAccessingSecurityScopedResource() } }
                viewModel.loadEncryptedPackageText(try String(contentsOf: url, encoding: .utf8))
            } catch {
                viewModel.errorMessage = error.localizedDescription
            }
        }
        .onChange(of: photoSelection) { _, newValue in
            guard let newValue else { return }
            Task {
                do {
                    guard let data = try await newValue.loadTransferable(type: Data.self) else {
                        throw CocoaError(.fileReadCorruptFile)
                    }
                    await MainActor.run {
                        viewModel.loadSelectedPhoto(
                            data: data,
                            contentType: newValue.supportedContentTypes.first
                        )
                    }
                } catch {
                    await MainActor.run {
                        viewModel.errorMessage = error.localizedDescription
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var encryptSections: some View {
        Section(
            header: Text("Source"),
            footer: Text("Ciphera detects the selected item type automatically, encrypts its raw bytes, and creates a portable CPFILE1 .txt package. The full ciphertext is not rendered on screen.")
        ) {
            Button {
                importing = true
            } label: {
                Label("Choose from Files", systemImage: "folder.fill")
            }

            PhotosPicker(selection: $photoSelection, matching: .images) {
                Label("Choose from Photos", systemImage: "photo.on.rectangle.angled")
            }

            if let filename = viewModel.selectedFilename,
               let data = viewModel.selectedData {
                LabeledContent("Selected", value: filename)
                LabeledContent("Detected as", value: viewModel.selectedKindLabel)
                LabeledContent(
                    "Size",
                    value: ByteCountFormatter.string(
                        fromByteCount: Int64(data.count),
                        countStyle: .file
                    )
                )

                if let image = UIImage(data: data) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 180)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .frame(maxWidth: .infinity)
                }

                Button(role: .destructive) {
                    viewModel.clearSelection()
                    photoSelection = nil
                } label: {
                    Label("Remove Selection", systemImage: "xmark.circle")
                }
            }
        }

        Section(footer: Text(viewModel.protection.subtitle)) {
            Picker("Protection", selection: $viewModel.protection) {
                Text("With a Secret").tag(ProtectionMode.secret)
                Text("For Someone").tag(ProtectionMode.recipient)
            }
            .pickerStyle(.segmented)
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
        }

        Section {
            Picker("Algorithm", selection: $viewModel.algorithm) {
                ForEach(SymmetricCipher.allCases) { Text($0.title).tag($0) }
            }
        }

        if viewModel.protection == .secret {
            Section(
                header: Text("Encryption Secret"),
                footer: Text("Ciphera does not save this secret. You will need the same secret to decrypt the package.")
            ) {
                SecureField("At least 8 characters", text: $viewModel.secret)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }
        } else {
            Section(
                header: Text("Recipient Public Key"),
                footer: Text("Only the matching private key can decrypt this package.")
            ) {
                TextField("CP-PUB1 public key", text: $viewModel.recipientPublicKey, axis: .vertical)
                    .font(.system(.footnote, design: .monospaced))
                    .lineLimit(2, reservesSpace: true)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                Button {
                    viewModel.recipientPublicKey = UIPasteboard.general.string ?? ""
                } label: {
                    Label("Paste Public Key", systemImage: "doc.on.clipboard")
                }

                if let fingerprint = viewModel.recipientFingerprint {
                    LabeledContent("Fingerprint", value: fingerprint)
                }
            }
        }

        Section {
            Button {
                if let result = viewModel.encryptFile() {
                    resultDestination = .encrypted(result)
                    showingResult = true
                }
            } label: {
                Label("Encrypt", systemImage: "lock.fill")
                    .fontWeight(.semibold)
                    .foregroundStyle(viewModel.canEncrypt ? Color.white : Color(uiColor: .secondaryLabel))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(viewModel.canEncrypt ? Color.accentColor : Color(uiColor: .tertiarySystemFill))
            .disabled(!viewModel.canEncrypt)
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
        }
    }

    @ViewBuilder
    private var decryptSections: some View {
        Section(
            header: Text("Encrypted Package"),
            footer: Text("Import the Ciphera CPFILE1 .txt package created during encryption. The package is read directly from the file instead of being loaded into a visible text editor.")
        ) {
            Button {
                importingPackageText = true
            } label: {
                Label("Import CPFILE1 .txt Package", systemImage: "doc.fill")
            }

            if viewModel.detectedFileInfo != nil {
                Label("Package loaded", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)

                LabeledContent(
                    "Package Size",
                    value: ByteCountFormatter.string(
                        fromByteCount: Int64(viewModel.encryptedPackageByteCount),
                        countStyle: .file
                    )
                )
            }
        }

        if let info = viewModel.detectedFileInfo {
            Section("Detected") {
                LabeledContent("Original File", value: info.filename)
                LabeledContent("Type", value: detectedKind(info.filename, info.contentType))
                LabeledContent("Protection", value: info.mode.title)
                LabeledContent("Algorithm", value: info.algorithm.title)
            }

            if info.mode == .secret {
                Section("Encryption Secret") {
                    SecureField("Secret", text: $viewModel.secret)
                }
            } else {
                Section {
                    Label(
                        "Ciphera will use the matching private key stored in Keychain.",
                        systemImage: "key.fill"
                    )
                }
            }

            Section {
                Button {
                    if let result = viewModel.decryptFile() {
                        resultDestination = .decrypted(result)
                        showingResult = true
                    }
                } label: {
                    Label("Decrypt", systemImage: "lock.open.fill")
                        .fontWeight(.semibold)
                        .foregroundStyle(viewModel.canDecrypt ? Color.white : Color(uiColor: .secondaryLabel))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(viewModel.canDecrypt ? Color.accentColor : Color(uiColor: .tertiarySystemFill))
                .disabled(!viewModel.canDecrypt)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
            }
        }
    }

    private func detectedKind(_ filename: String, _ contentTypeIdentifier: String?) -> String {
        let type: UTType?
        if let contentTypeIdentifier {
            type = UTType(contentTypeIdentifier)
        } else {
            type = UTType(filenameExtension: URL(fileURLWithPath: filename).pathExtension)
        }
        if type?.conforms(to: .image) == true { return "Image" }
        if type?.conforms(to: .pdf) == true { return "PDF" }
        if type?.conforms(to: .archive) == true { return "Archive" }
        if type?.conforms(to: .text) == true { return "Text" }
        if type?.conforms(to: .audio) == true { return "Audio" }
        if type?.conforms(to: .movie) == true { return "Video" }
        return "File"
    }
}

private enum FileCryptResultDestination {
    case encrypted(FileEncryptionResult)
    case decrypted(FileDecryptionResult)
}

private struct FileEncryptionResultView: View {
    let result: FileEncryptionResult

    var body: some View {
        List {
            Section {
                HStack(spacing: 12) {
                    Image(systemName: "checkmark.shield.fill")
                        .font(.title2)
                        .foregroundStyle(.green)

                    VStack(alignment: .leading, spacing: 3) {
                        Text("Encryption Complete")
                            .font(.headline)
                        Text("Your file is ready as a Ciphera encrypted package.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text("Encryption")
            } footer: {
                Text("Ciphera keeps the encrypted payload out of the interface. Save or share the .txt package before leaving if you need it later.")
            }

            Section("Summary") {
                LabeledContent("Original File", value: result.originalFilename)
                LabeledContent("Type", value: result.kind)
                LabeledContent("Protection", value: result.protection)
                LabeledContent("Algorithm", value: result.algorithm)
                LabeledContent("Format", value: "Ciphera CPFILE1")
                LabeledContent(
                    "Package Size",
                    value: ByteCountFormatter.string(
                        fromByteCount: Int64(result.packageByteCount),
                        countStyle: .file
                    )
                )
            }

            Section {
                ShareLink(item: result.packageURL) {
                    Label("Save or Share .txt Package", systemImage: "square.and.arrow.up")
                }
            }
        }
        .navigationTitle("Encrypted")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct FileDecryptionResultView: View {
    let result: FileDecryptionResult

    private var isImage: Bool {
        if let identifier = result.contentTypeIdentifier,
           let type = UTType(identifier),
           type.conforms(to: .image) {
            return true
        }
        let ext = URL(fileURLWithPath: result.filename).pathExtension
        return UTType(filenameExtension: ext)?.conforms(to: .image) == true
    }

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
                        Text("The original file was restored successfully.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text("Decryption")
            } footer: {
                Text("The restored file is temporary until you choose to save or share it.")
            }

            Section("Summary") {
                LabeledContent("Filename", value: result.filename)
                LabeledContent("Detected as", value: result.kind)
                LabeledContent(
                    "Size",
                    value: ByteCountFormatter.string(
                        fromByteCount: Int64(result.data.count),
                        countStyle: .file
                    )
                )
            }

            if isImage, let image = UIImage(data: result.data) {
                Section("Preview") {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 320)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .frame(maxWidth: .infinity)
                }
            }

            Section {
                ShareLink(item: result.outputURL) {
                    Label(
                        isImage ? "Save or Share Image" : "Save or Share File",
                        systemImage: "square.and.arrow.up"
                    )
                }
            }
        }
        .navigationTitle("Decrypted")
        .navigationBarTitleDisplayMode(.inline)
    }
}
