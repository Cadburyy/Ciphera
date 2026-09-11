import SwiftUI
import UIKit
import PencilKit
import PhotosUI

struct SignVerifyView: View {
    @StateObject private var viewModel = SignVerifyViewModel()
    @State private var showAutographSheet = false
    @State private var importingSignedAutographPNG = false
    @State private var signedAutographPhotoSelection: PhotosPickerItem?

    var body: some View {
        Form {
            Section {
                Picker("Action", selection: $viewModel.mode) {
                    ForEach(SignVerifyMode.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                .onChange(of: viewModel.mode) { _, newMode in
                    if newMode == .verify {
                        viewModel.resetVerification()
                    }
                }
            }

            if viewModel.mode == .sign {
                signingSections
            } else {
                verificationSections
            }

            if let errorMessage = viewModel.errorMessage {
                Section {
                    Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle("Sign & Verify")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $viewModel.verificationNavigationResult) { result in
            SignatureVerificationResultView(result: result)
        }
        .navigationDestination(isPresented: $viewModel.showingSignResult) {
            SignatureCreationResultView(viewModel: viewModel)
        }
        .sheet(isPresented: $showAutographSheet) {
            AutographCaptureView(drawingData: $viewModel.autographDrawingData)
        }
        .onChange(of: viewModel.autographDrawingData) { _, newValue in
            if newValue != nil {
                viewModel.prepareUnsignedAutographPNG()
            }
        }
        .fileImporter(
            isPresented: $importingSignedAutographPNG,
            allowedContentTypes: [.png],
            allowsMultipleSelection: false
        ) { result in
            do {
                guard let url = try result.get().first else { return }
                let accessed = url.startAccessingSecurityScopedResource()
                defer { if accessed { url.stopAccessingSecurityScopedResource() } }
                viewModel.importSignedAutographPNG(from: url)
            } catch {
                viewModel.errorMessage = error.localizedDescription
            }
        }
        .onChange(of: signedAutographPhotoSelection) { _, newValue in
            guard let newValue else { return }
            Task {
                do {
                    guard let data = try await newValue.loadTransferable(type: Data.self) else {
                        throw CocoaError(.fileReadCorruptFile)
                    }
                    try await MainActor.run {
                        try viewModel.importSignedAutographPNG(data: data)
                    }
                } catch {
                    await MainActor.run {
                        viewModel.errorMessage = error.localizedDescription
                    }
                }
                await MainActor.run {
                    signedAutographPhotoSelection = nil
                }
            }
        }
    }

    @ViewBuilder
    private var signingSections: some View {
        Section("Content to Sign") {
            TextEditor(text: $viewModel.text)
                .frame(minHeight: 140)
                .scrollContentBackground(.hidden)
        }

        Section {
            Picker("Signing Algorithm", selection: $viewModel.algorithm) {
                ForEach(SigningAlgorithm.allCases) { Text($0.title).tag($0) }
            }
        } footer: {
            Text("Ed25519 is the recommended default. ECDSA options are available for learning and interoperability.")
        }

        Section {
            if let drawingData = viewModel.autographDrawingData {
                AutographPreview(drawingData: drawingData)
                    .frame(height: 110)

                Button {
                    showAutographSheet = true
                } label: {
                    Label("Edit Autograph", systemImage: "pencil.tip")
                }

                Button {
                    viewModel.copyAutographImage()
                } label: {
                    Label("Copy Autograph Image", systemImage: "doc.on.doc")
                }

                if let autographPNGURL = viewModel.autographPNGURL {
                    ShareLink(item: autographPNGURL) {
                        Label("Save or Share Autograph PNG", systemImage: "square.and.arrow.up")
                    }
                }

                Button(role: .destructive) {
                    viewModel.clearAutograph()
                } label: {
                    Label("Clear Autograph", systemImage: "trash")
                }
            } else {
                Button {
                    showAutographSheet = true
                } label: {
                    Label("Add Handwritten Autograph", systemImage: "signature")
                }
            }
        } header: {
            Text("Handwritten Autograph")
        } footer: {
            Text("Required. Add a handwritten autograph before signing. It is attached to the content and cryptographically bound to the digital signature.")
        }

        Section {
            Button(action: viewModel.sign) {
                Label("Sign Content", systemImage: "signature")
                    .fontWeight(.semibold)
                    .foregroundStyle(viewModel.canSign ? Color.white : Color(uiColor: .secondaryLabel))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(viewModel.canSign ? Color.accentColor : Color(uiColor: .tertiarySystemFill))
            .disabled(!viewModel.canSign)
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
        }

    }

    @ViewBuilder
    private var verificationSections: some View {
        Section {
            TextField("Paste a CP-SIG1 signed package", text: $viewModel.signature)
                .font(.system(.footnote, design: .monospaced))
                .lineLimit(1)
                .truncationMode(.tail)
                .onChange(of: viewModel.signature) { _, _ in
                    viewModel.signatureChanged()
                }

            Button {
                viewModel.signature = UIPasteboard.general.string ?? ""
                viewModel.signatureChanged()
            } label: {
                Label("Paste Signed Package", systemImage: "doc.on.clipboard")
            }

            Menu {
                PhotosPicker(selection: $signedAutographPhotoSelection, matching: .images) {
                    Label("Gallery", systemImage: "photo.on.rectangle")
                }

                Button {
                    importingSignedAutographPNG = true
                } label: {
                    Label("Files", systemImage: "folder")
                }
            } label: {
                Label("Verify Autograph", systemImage: "photo.badge.checkmark")
            }
        } header: {
            Text("CP-SIG1 Signed Package")
        } footer: {
            Text("For current Ciphera signatures, this package already contains the signed content and optional autograph. You do not need to enter the content again.")
        }

        if viewModel.isLegacySignature {
            Section {
                TextEditor(text: $viewModel.text)
                    .frame(minHeight: 120)
                    .scrollContentBackground(.hidden)
            } header: {
                Text("Original Content")
            } footer: {
                Text("This is an older CP-SIG1 signature that does not contain its original content. Enter the exact content that was signed.")
            }
        }

        Section {
            Button(action: viewModel.verify) {
                Label("Verify Signature", systemImage: "checkmark.seal.fill")
                    .fontWeight(.semibold)
                    .foregroundStyle(viewModel.canVerify ? Color.white : Color(uiColor: .secondaryLabel))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(viewModel.canVerify ? Color.accentColor : Color(uiColor: .tertiarySystemFill))
            .disabled(!viewModel.canVerify)
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
        }



    }
}

private struct SignatureCreationResultView: View {
    @ObservedObject var viewModel: SignVerifyViewModel

    var body: some View {
        Form {
            Section {
                HStack(spacing: 12) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.title2)
                        .foregroundStyle(.green)

                    VStack(alignment: .leading, spacing: 3) {
                        Text("Signature Created")
                            .font(.headline)

                        Text("This content has been digitally signed.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text("Signing")
            } footer: {
                Text("The CP-SIG1 package contains the signed content, optional autograph, public signing key, and digital signature. It is signed, not encrypted.")
            }

            Section("Signed Package") {
                Text(viewModel.signature)
                    .font(.system(.footnote, design: .monospaced))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .textSelection(.enabled)
                    .accessibilityLabel("Signed CP-SIG1 package preview")

                Button {
                    UIPasteboard.general.string = viewModel.signature
                } label: {
                    Label("Copy Signed Package", systemImage: "doc.on.doc")
                }

                ShareLink(item: viewModel.signature) {
                    Label("Share Signed Package", systemImage: "square.and.arrow.up")
                }

                if let autographPNGURL = viewModel.autographPNGURL {
                    ShareLink(item: autographPNGURL) {
                        Label("Share Signed Autograph PNG", systemImage: "signature")
                    }
                }

                if let signatureJSONURL = viewModel.signatureJSONURL {
                    ShareLink(item: signatureJSONURL) {
                        Label("Export Signature Details JSON", systemImage: "curlybraces")
                    }
                }
            }
        }
        .navigationTitle("Signed")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct SignatureVerificationResultView: View {
    let result: SignatureVerificationResult

    var body: some View {
        Form {
            Section {
                HStack(spacing: 12) {
                    Image(systemName: result.isValid ? "checkmark.seal.fill" : "xmark.seal.fill")
                        .font(.title2)
                        .foregroundStyle(result.isValid ? Color.green : Color.red)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(result.isValid ? "Signature Verified" : "Verification Failed")
                            .font(.headline)
                        Text(
                            result.isValid
                                ? "This package has a valid digital signature."
                                : "Ciphera could not verify this signed package."
                        )
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text("Verification")
            } footer: {
                Text(
                    result.isValid
                        ? "The signed content and autograph match the original digital signature."
                        : "The content, autograph, public key, or signature may have been changed."
                )
            }

            if result.isValid {
                if let content = result.signedContent {
                    Section("Signed Content") {
                        Text(content)
                            .textSelection(.enabled)
                    }
                }

                if let drawingData = result.autographDrawingData {
                    Section {
                        AutographPreview(drawingData: drawingData)
                            .frame(height: 140)
                    } header: {
                        Text("Signed Autograph")
                    } footer: {
                        Text("This autograph was cryptographically bound to the signed content.")
                    }
                }

                if result.signerFingerprint != nil || result.createdAt != nil {
                    Section("Signature Details") {
                        if let fingerprint = result.signerFingerprint {
                            LabeledContent("Signer", value: fingerprint)
                        }

                        if let createdAt = result.createdAt {
                            LabeledContent("Created", value: createdAt)
                        }
                    }
                }
            }
        }
        .navigationTitle(result.isValid ? "Verified" : "Not Verified")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct AutographCaptureView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var drawingData: Data?
    @State private var workingDrawingData: Data?

    init(drawingData: Binding<Data?>) {
        _drawingData = drawingData
        _workingDrawingData = State(initialValue: drawingData.wrappedValue)
    }

    private var hasWorkingAutograph: Bool {
        guard let workingDrawingData,
              let drawing = try? PKDrawing(data: workingDrawingData) else {
            return false
        }
        return !drawing.strokes.isEmpty
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Write your autograph")
                        .font(.headline)
                    Text("Draw naturally with your finger or Apple Pencil. This drawing will be attached to the digital signature.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                PencilAutographCanvas(drawingData: $workingDrawingData)
                    .frame(minHeight: 300)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color(uiColor: .separator), lineWidth: 0.5)
                    }

                Text("The handwriting is not a replacement for cryptographic identity. Ciphera digitally signs the content and this drawing together.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding()
            .navigationTitle("Autograph")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Clear") {
                        workingDrawingData = nil
                    }
                    .disabled(workingDrawingData == nil)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        drawingData = workingDrawingData
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(!hasWorkingAutograph)
                }
            }
        }
        .presentationDetents([.large])
    }
}

private struct PencilAutographCanvas: UIViewRepresentable {
    @Binding var drawingData: Data?

    func makeCoordinator() -> Coordinator {
        Coordinator(drawingData: $drawingData)
    }

    func makeUIView(context: Context) -> PKCanvasView {
        let canvasView = PKCanvasView()
        canvasView.delegate = context.coordinator
        canvasView.drawingPolicy = .anyInput
        canvasView.backgroundColor = .secondarySystemBackground
        canvasView.isOpaque = true

        if let drawingData,
           let drawing = try? PKDrawing(data: drawingData) {
            canvasView.drawing = drawing
        }

        context.coordinator.canvasView = canvasView
        DispatchQueue.main.async {
            context.coordinator.attachToolPickerIfNeeded()
        }
        return canvasView
    }

    func updateUIView(_ canvasView: PKCanvasView, context: Context) {
        if drawingData == nil && !canvasView.drawing.strokes.isEmpty {
            canvasView.drawing = PKDrawing()
        } else if let drawingData,
                  let drawing = try? PKDrawing(data: drawingData),
                  drawing.dataRepresentation() != canvasView.drawing.dataRepresentation() {
            canvasView.drawing = drawing
        }

        context.coordinator.attachToolPickerIfNeeded()
    }

    final class Coordinator: NSObject, PKCanvasViewDelegate {
        @Binding var drawingData: Data?
        weak var canvasView: PKCanvasView?
        private var toolPicker: PKToolPicker?

        init(drawingData: Binding<Data?>) {
            _drawingData = drawingData
        }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            drawingData = canvasView.drawing.strokes.isEmpty
                ? nil
                : canvasView.drawing.dataRepresentation()
        }

        func attachToolPickerIfNeeded() {
            guard toolPicker == nil,
                  let canvasView,
                  canvasView.window != nil
            else { return }

            let picker = PKToolPicker()
            picker.selectedTool = PKInkingTool(.pen, color: .label, width: 3)
            picker.addObserver(canvasView)
            picker.setVisible(true, forFirstResponder: canvasView)
            canvasView.becomeFirstResponder()
            toolPicker = picker
        }
    }
}

private struct AutographPreview: View {
    let drawingData: Data

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(uiColor: .secondarySystemBackground))

                if let drawing = try? PKDrawing(data: drawingData),
                   !drawing.strokes.isEmpty {
                    let bounds = drawing.bounds.insetBy(dx: -12, dy: -12)
                    let image = drawing.image(from: bounds, scale: UIScreen.main.scale)
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .padding(8)
                } else {
                    Text("No autograph")
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
    }
}
