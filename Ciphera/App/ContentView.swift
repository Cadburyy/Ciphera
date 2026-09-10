import SwiftUI

import UIKit
import UniformTypeIdentifiers
import CryptoKit

struct ContentView: View {

    @AppStorage("Ciphera.onboarding.cp1") private var completedOnboarding = false

    var body: some View {

        Group {

            if completedOnboarding {

                CipherRootView {

                    completedOnboarding = false

                }

            } else {

                OnboardingView {

                    completedOnboarding = true

                }

            }

        }

        .animation(.snappy, value: completedOnboarding)
        .scrollDismissesKeyboard(.immediately)

    }

}

// MARK: - Onboarding
