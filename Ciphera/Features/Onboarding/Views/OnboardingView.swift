import SwiftUI
import UIKit
import UniformTypeIdentifiers
import CryptoKit

struct OnboardingPage {

    let symbol: String

    let title: String

    let message: String

}

struct OnboardingView: View {

    let onFinish: () -> Void

    @State private var page = 0

    private let pages: [OnboardingPage] = [

        .init(

            symbol: "lock.shield.fill",

            title: "Encrypt without storing",

            message: "Ciphera encrypts and decrypts on your iPhone. The text you type and the encrypted results are not saved by the app."

        ),

        .init(

            symbol: "key.horizontal.fill",

            title: "Protect with a secret",

            message: "Use a secret you know. Anyone with the same secret and CP1 message can decrypt it. Choose AES-256-GCM or ChaCha20-Poly1305."

        ),

        .init(

            symbol: "person.2.fill",

            title: "Encrypt for someone",

            message: "Use someone’s public key to create a message intended only for their key pair. You never need to send them a shared password."

        ),

        .init(

            symbol: "key.viewfinder",

            title: "Your public key is shareable",

            message: "Your public key acts like an open padlock. Share it freely. Your private key stays protected in Keychain and can be intentionally backed up."

        ),

        .init(

            symbol: "graduationcap.fill",

            title: "Learn as you go",

            message: "New to encryption? Open Tools → Guided Tutorials anytime for step-by-step practice with messages, keys, files, and signatures."

        ),

        .init(

            symbol: "doc.on.doc.fill",

            title: "One portable format",

            message: "Ciphera packages the method and algorithm into a CP1 message, so Decrypt can recognize how it was protected automatically."

        )

    ]

    var body: some View {

        VStack(spacing: 0) {

            HStack {

                Text("Ciphera")

                    .font(.headline)

                Spacer()

                Text("\(page + 1) of \(pages.count)")

                    .font(.subheadline)

                    .foregroundStyle(.secondary)

            }

            .padding(.horizontal, 20)

            .padding(.top, 20)

            Spacer(minLength: 30)

            ZStack {

                RoundedRectangle(cornerRadius: 34, style: .continuous)

                    .fill(.thinMaterial)

                    .frame(width: 158, height: 158)

                Image(systemName: pages[page].symbol)

                    .font(.system(size: 62, weight: .semibold))

                    .symbolRenderingMode(.hierarchical)

                    .foregroundStyle(.tint)

            }

            VStack(spacing: 14) {

                Text(pages[page].title)

                    .font(.system(size: 30, weight: .bold, design: .rounded))

                    .multilineTextAlignment(.center)

                Text(pages[page].message)

                    .font(.body)

                    .foregroundStyle(.secondary)

                    .multilineTextAlignment(.center)

                    .lineSpacing(3)

                    .padding(.horizontal, 20)

            }

            .padding(.top, 34)

            Spacer()

            HStack(spacing: 8) {

                ForEach(pages.indices, id: \.self) { index in

                    Capsule()

                        .fill(index == page ? Color.accentColor : Color.secondary.opacity(0.2))

                        .frame(width: index == page ? 24 : 8, height: 8)

                }

            }

            .animation(.snappy, value: page)

            .padding(.bottom, 22)

            Button {

                if page == pages.count - 1 {

                    onFinish()

                } else {

                    withAnimation(.snappy) { page += 1 }

                }

            } label: {

                Text(page == pages.count - 1 ? "Get Started" : "Continue")

                    .fontWeight(.semibold)

                    .frame(maxWidth: .infinity)

                    .frame(height: 52)

            }

            .buttonStyle(.borderedProminent)

            .buttonBorderShape(.roundedRectangle(radius: 16))

            .padding(.horizontal, 20)

            .padding(.bottom, 12)

            if page > 0 {

                Button("Back") {

                    withAnimation(.snappy) { page -= 1 }

                }

                .padding(.bottom, 18)

            }

        }

    }

}

// MARK: - Root HIG hierarchy
