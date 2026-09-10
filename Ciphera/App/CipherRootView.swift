import SwiftUI

struct CipherRootView: View {

    @Environment(\.scenePhase) private var scenePhase

    let replayOnboarding: () -> Void

    var body: some View {
        TabView {
            EncryptView()
                .tabItem {
                    Label("Encrypt", systemImage: "lock.fill")
                }

            DecryptView()
                .tabItem {
                    Label("Decrypt", systemImage: "lock.open.fill")
                }

            ToolsView()
                .tabItem {
                    Label("Tools", systemImage: "wrench.and.screwdriver.fill")
                }

            MyKeyView(replayOnboarding: replayOnboarding)
                .tabItem {
                    Label("My Key", systemImage: "key.horizontal.fill")
                }
        }
        .overlay {
            if scenePhase != .active {
                PrivacyShieldView()
            }
        }
        .animation(.easeOut(duration: 0.15), value: scenePhase)
    }
}

private struct PrivacyShieldView: View {
    var body: some View {
        ZStack {
            Color(uiColor: .systemBackground)
                .ignoresSafeArea()

            VStack(spacing: 12) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 42, weight: .semibold))
                    .foregroundStyle(.tint)

                Text("Ciphera")
                    .font(.headline)

                Text("Sensitive content is hidden while the app is inactive.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(28)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Ciphera privacy screen")
    }
}
