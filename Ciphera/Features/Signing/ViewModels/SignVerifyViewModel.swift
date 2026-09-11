import Foundation
import Combine
import UIKit
import PencilKit
import ImageIO
import UniformTypeIdentifiers


struct SignatureVerificationResult: Identifiable, Hashable {
    let id = UUID()
    let isValid: Bool
    let signedContent: String?
    let autographDrawingData: Data?
    let signerFingerprint: String?
    let createdAt: String?
}

enum SignVerifyMode: String, CaseIterable, Identifiable {
    case sign = "Sign"
    case verify = "Verify"
    var id: String { rawValue }
}

@MainActor
final class SignVerifyViewModel: ObservableObject {
    @Published var mode: SignVerifyMode = .sign
    @Published var algorithm: SigningAlgorithm = .ed25519
    @Published var text = ""
    @Published var signature = ""
    @Published var autographDrawingData: Data?
    @Published var embeddedAutographDrawingData: Data?
    @Published var embeddedContent: String?
    @Published var verificationResult: Bool?
    @Published var verificationNavigationResult: SignatureVerificationResult?
    @Published var showingSignResult = false
    @Published var errorMessage: String?
    @Published var autographPNGURL: URL?
    @Published var signatureJSONURL: URL?

    var hasAutograph: Bool {
        guard let autographDrawingData,
              let drawing = try? PKDrawing(data: autographDrawingData) else {
            return false
        }
        return !drawing.strokes.isEmpty
    }

    var canSign: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && hasAutograph
    }

    var isLegacySignature: Bool {
        !signature.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && CryptoService.signatureRequiresExternalContent(signature)
    }

    var canVerify: Bool {
        let hasSignature = !signature.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        guard hasSignature else { return false }
        return !isLegacySignature || !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func sign() {
        guard canSign else {
            errorMessage = "Enter content and add a handwritten autograph before signing."
            return
        }

        do {
            signature = try CryptoService.sign(
                text,
                algorithm: algorithm,
                autographDrawingData: autographDrawingData
            )
            embeddedContent = text
            embeddedAutographDrawingData = autographDrawingData
            verificationResult = nil
            errorMessage = nil
            try prepareExports()
            showingSignResult = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func signatureChanged() {
        // Loading or editing a package must not reveal signed content/autograph.
        // Those values are populated only after the user explicitly verifies it.
        verificationResult = nil
        verificationNavigationResult = nil
        errorMessage = nil
        embeddedContent = nil
        embeddedAutographDrawingData = nil
    }

    func verify() {
        do {
            let content = CryptoService.signatureEmbeddedContent(signature)
            let autograph = CryptoService.signatureAutographDrawingData(signature)

            let isValid: Bool
            if let content {
                isValid = try CryptoService.verifyEmbeddedSignature(signature)
                if isValid {
                    text = content
                }
            } else {
                isValid = try CryptoService.verify(text, signatureText: signature)
            }

            verificationResult = isValid
            embeddedContent = nil
            embeddedAutographDrawingData = nil
            errorMessage = nil

            verificationNavigationResult = SignatureVerificationResult(
                isValid: isValid,
                signedContent: isValid ? content : nil,
                autographDrawingData: isValid ? autograph : nil,
                signerFingerprint: isValid ? CryptoService.signatureSignerFingerprint(signature) : nil,
                createdAt: isValid ? CryptoService.signatureCreatedAt(signature) : nil
            )
        } catch {
            verificationResult = nil
            verificationNavigationResult = nil
            embeddedContent = nil
            embeddedAutographDrawingData = nil
            errorMessage = error.localizedDescription
        }
    }

    func clearAutograph() {
        autographDrawingData = nil
        autographPNGURL = nil
        signatureJSONURL = nil
    }

    func copyAutographImage() {
        do {
            guard let image = try autographImage(from: autographDrawingData) else {
                throw ExportError.missingAutograph
            }
            UIPasteboard.general.image = image
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func prepareUnsignedAutographPNG() {
        do {
            autographPNGURL = try writeAutographPNG(embeddedPackage: nil)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func importSignedAutographPNG(from url: URL) {
        do {
            try importSignedAutographPNG(data: Data(contentsOf: url))
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func importSignedAutographPNG(data: Data) throws {
        do {
            guard let source = CGImageSourceCreateWithData(data as CFData, nil),
                  let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
                  let png = properties[kCGImagePropertyPNGDictionary] as? [CFString: Any],
                  let description = png[kCGImagePropertyPNGDescription] as? String,
                  let jsonData = description.data(using: .utf8),
                  let json = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                  let package = json["signedPackage"] as? String,
                  package.hasPrefix("CP-SIG1:")
            else {
                throw ExportError.missingCipheraMetadata
            }

            signature = package
            signatureChanged()
        } catch {
            throw error
        }
    }

    func resetVerification() {
        signature = ""
        embeddedContent = nil
        embeddedAutographDrawingData = nil
        verificationResult = nil
        verificationNavigationResult = nil
        errorMessage = nil
        text = ""
    }

    private func prepareExports() throws {
        signatureJSONURL = try writeSignatureJSON()
        autographPNGURL = autographDrawingData == nil ? nil : try writeAutographPNG(embeddedPackage: signature)
    }

    private func writeSignatureJSON() throws -> URL {
        let data = try CryptoService.signatureDetailsJSON(signature)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("Ciphera-Signature-Details.json")
        try data.write(to: url, options: .atomic)
        return url
    }

    private func writeAutographPNG(embeddedPackage: String?) throws -> URL {
        guard let image = try autographImage(from: autographDrawingData),
              let cgImage = image.cgImage
        else { throw ExportError.missingAutograph }

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("Ciphera-Autograph.png")
        guard let destination = CGImageDestinationCreateWithURL(
            url as CFURL,
            UTType.png.identifier as CFString,
            1,
            nil
        ) else { throw ExportError.couldNotCreatePNG }

        var pngMetadata: [CFString: Any] = [:]
        if let embeddedPackage {
            let metadataData = try CryptoService.signatureDetailsJSON(embeddedPackage)
            if let metadataString = String(data: metadataData, encoding: .utf8) {
                pngMetadata[kCGImagePropertyPNGDescription] = metadataString
                pngMetadata[kCGImagePropertyPNGTitle] = "Ciphera Signed Autograph"
            }
        }

        let properties: [CFString: Any] = [
            kCGImagePropertyPNGDictionary: pngMetadata
        ]
        CGImageDestinationAddImage(destination, cgImage, properties as CFDictionary)
        guard CGImageDestinationFinalize(destination) else {
            throw ExportError.couldNotCreatePNG
        }
        return url
    }

    private func autographImage(from data: Data?) throws -> UIImage? {
        guard let data else { return nil }
        let drawing = try PKDrawing(data: data)
        guard !drawing.strokes.isEmpty else { return nil }
        let bounds = drawing.bounds.insetBy(dx: -24, dy: -24)
        return drawing.image(from: bounds, scale: 3)
    }
}

private enum ExportError: LocalizedError {
    case missingAutograph
    case couldNotCreatePNG
    case missingCipheraMetadata

    var errorDescription: String? {
        switch self {
        case .missingAutograph:
            return "Draw an autograph first."
        case .couldNotCreatePNG:
            return "Ciphera could not create the autograph PNG."
        case .missingCipheraMetadata:
            return "This PNG does not contain Ciphera signature metadata. It may be a normal image or its metadata may have been removed by another app."
        }
    }
}
