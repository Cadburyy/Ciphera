import Foundation
import Combine
import UniformTypeIdentifiers


struct FileEncryptionResult: Hashable {
    let packageURL: URL
    let originalFilename: String
    let kind: String
    let packageByteCount: Int
    let protection: String
    let algorithm: String
}

struct FileDecryptionResult: Hashable {
    let data: Data
    let filename: String
    let contentTypeIdentifier: String?
    let outputURL: URL
    let kind: String
}

enum FileCryptMode: String, CaseIterable, Identifiable {
    case encrypt = "Encrypt"
    case decrypt = "Decrypt"
    var id: String { rawValue }
}

@MainActor
final class FileCryptViewModel: ObservableObject {
    @Published var mode: FileCryptMode = .encrypt
    @Published var protection: ProtectionMode = .secret
    @Published var algorithm: SymmetricCipher = .aes256GCM
    @Published var selectedURL: URL?
    @Published var selectedFilename: String?
    @Published var selectedData: Data?
    @Published var selectedContentTypeIdentifier: String?
    @Published var encryptedPackageURL: URL?
    @Published private(set) var encryptedPackageByteCount = 0
    private var encryptedPackageText = ""
    @Published var detectedFileInfo: (mode: ProtectionMode, algorithm: SymmetricCipher, filename: String, contentType: String?)?
    @Published var secret = ""
    @Published var recipientPublicKey = ""
    @Published var decryptedData: Data?
    @Published var decryptedFilename: String?
    @Published var decryptedContentTypeIdentifier: String?
    @Published var outputURL: URL?
    @Published var errorMessage: String?

    var canEncrypt: Bool {
        guard selectedData != nil, selectedFilename != nil else { return false }
        return protection == .secret ? secret.count >= 8 : recipientFingerprint != nil
    }

    var canDecrypt: Bool {
        guard let detectedFileInfo else { return false }
        return detectedFileInfo.mode == .secret ? secret.count >= 8 : true
    }

    var recipientFingerprint: String? {
        guard !recipientPublicKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return try? CryptoService.fingerprint(forPublicKeyText: recipientPublicKey)
    }

    var selectedFileExtension: String? {
        selectedFilename
            .map { URL(fileURLWithPath: $0).pathExtension.lowercased() }
            .flatMap { $0.isEmpty ? nil : $0 }
    }

    var selectedKindLabel: String {
        kindLabel(filename: selectedFilename, contentTypeIdentifier: selectedContentTypeIdentifier)
    }

    var decryptedKindLabel: String {
        kindLabel(filename: decryptedFilename, contentTypeIdentifier: decryptedContentTypeIdentifier)
    }

    var decryptedIsImage: Bool {
        isImage(filename: decryptedFilename, contentTypeIdentifier: decryptedContentTypeIdentifier)
    }

    func resetSelection() {
        selectedURL = nil
        selectedFilename = nil
        selectedData = nil
        selectedContentTypeIdentifier = nil
        encryptedPackageText = ""
        encryptedPackageByteCount = 0
        encryptedPackageURL = nil
        detectedFileInfo = nil
        decryptedData = nil
        decryptedFilename = nil
        decryptedContentTypeIdentifier = nil
        outputURL = nil
        errorMessage = nil
        secret = ""
    }

    func clearSelection() {
        selectedURL = nil
        selectedFilename = nil
        selectedData = nil
        selectedContentTypeIdentifier = nil
        encryptedPackageText = ""
        encryptedPackageByteCount = 0
        encryptedPackageURL = nil
        outputURL = nil
        errorMessage = nil
    }

    func loadSelectedFile(url: URL, data: Data) {
        selectedURL = url
        selectedFilename = url.lastPathComponent
        selectedData = data
        selectedContentTypeIdentifier = UTType(filenameExtension: url.pathExtension)?.identifier
        encryptedPackageText = ""
        encryptedPackageByteCount = 0
        encryptedPackageURL = nil
        outputURL = nil
        errorMessage = nil
    }

    func loadSelectedPhoto(data: Data, contentType: UTType?) {
        selectedURL = nil
        let type = contentType ?? .jpeg
        let ext = type.preferredFilenameExtension ?? "jpg"
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        selectedFilename = "Photo-\(formatter.string(from: Date())).\(ext)"
        selectedData = data
        selectedContentTypeIdentifier = type.identifier
        encryptedPackageText = ""
        encryptedPackageByteCount = 0
        encryptedPackageURL = nil
        outputURL = nil
        errorMessage = nil
    }

    func loadEncryptedPackageText(_ text: String) {
        encryptedPackageText = text
        encryptedPackageByteCount = text.utf8.count
        encryptedPackageChanged()
    }

    private func encryptedPackageChanged() {
        decryptedData = nil
        decryptedFilename = nil
        decryptedContentTypeIdentifier = nil
        outputURL = nil
        errorMessage = nil
        detectedFileInfo = CryptoService.fileInfo(encryptedPackageText)

        let trimmed = encryptedPackageText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty && detectedFileInfo == nil {
            errorMessage = "This does not look like a valid Ciphera CPFILE1 text package."
        }
    }

    func encryptFile() -> FileEncryptionResult? {
        guard let data = selectedData, let filename = selectedFilename else {
            errorMessage = "Choose a file or photo first."
            return nil
        }

        if protection == .secret && secret.count < 8 {
            errorMessage = "Use a secret with at least 8 characters."
            return nil
        }

        if protection == .recipient && recipientFingerprint == nil {
            errorMessage = "Paste a valid Ciphera public key before encrypting."
            return nil
        }

        do {
            if protection == .secret {
                encryptedPackageText = try CryptoService.encryptFileText(
                    data,
                    filename: filename,
                    contentType: selectedContentTypeIdentifier,
                    secret: secret,
                    algorithm: algorithm
                )
            } else {
                encryptedPackageText = try CryptoService.encryptFileText(
                    data,
                    filename: filename,
                    contentType: selectedContentTypeIdentifier,
                    recipientPublicKeyText: recipientPublicKey,
                    algorithm: algorithm
                )
            }
            encryptedPackageByteCount = encryptedPackageText.utf8.count
            encryptedPackageURL = try writePackageText(encryptedPackageText)
            errorMessage = nil

            guard let packageURL = encryptedPackageURL else { return nil }
            return FileEncryptionResult(
                packageURL: packageURL,
                originalFilename: filename,
                kind: selectedKindLabel,
                packageByteCount: encryptedPackageByteCount,
                protection: protection.title,
                algorithm: algorithm.title
            )
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    func decryptFile() -> FileDecryptionResult? {
        guard let info = detectedFileInfo else {
            errorMessage = "Import a valid Ciphera CPFILE1 .txt package first."
            return nil
        }

        if info.mode == .secret && secret.count < 8 {
            errorMessage = "Enter the same secret used to encrypt this item."
            return nil
        }

        do {
            let result = try CryptoService.decryptFileText(
                encryptedPackageText,
                secret: info.mode == .secret ? secret : nil
            )
            decryptedData = result.data
            decryptedFilename = result.filename
            decryptedContentTypeIdentifier = result.contentType
            outputURL = try writeTemporary(result.data, name: result.filename)
            errorMessage = nil

            guard let outputURL else { return nil }
            return FileDecryptionResult(
                data: result.data,
                filename: result.filename,
                contentTypeIdentifier: result.contentType,
                outputURL: outputURL,
                kind: decryptedKindLabel
            )
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    private func kindLabel(filename: String?, contentTypeIdentifier: String?) -> String {
        let type = resolvedType(filename: filename, contentTypeIdentifier: contentTypeIdentifier)
        if type?.conforms(to: .image) == true { return "Image" }
        if type?.conforms(to: .pdf) == true { return "PDF" }
        if type?.conforms(to: .archive) == true { return "Archive" }
        if type?.conforms(to: .text) == true { return "Text" }
        if type?.conforms(to: .audio) == true { return "Audio" }
        if type?.conforms(to: .movie) == true { return "Video" }
        return "File"
    }

    private func isImage(filename: String?, contentTypeIdentifier: String?) -> Bool {
        resolvedType(filename: filename, contentTypeIdentifier: contentTypeIdentifier)?.conforms(to: .image) == true
    }

    private func resolvedType(filename: String?, contentTypeIdentifier: String?) -> UTType? {
        if let contentTypeIdentifier, let type = UTType(contentTypeIdentifier) { return type }
        guard let filename else { return nil }
        let ext = URL(fileURLWithPath: filename).pathExtension
        guard !ext.isEmpty else { return nil }
        return UTType(filenameExtension: ext)
    }


    private func writePackageText(_ text: String) throws -> URL {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let name = "Ciphera-Package-\(formatter.string(from: Date())).txt"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        try text.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    private func writeTemporary(_ data: Data, name: String) throws -> URL {
        let safeName = name.replacingOccurrences(of: "/", with: "-")
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + "-" + safeName)
        try data.write(to: url, options: .atomic)
        return url
    }
}
