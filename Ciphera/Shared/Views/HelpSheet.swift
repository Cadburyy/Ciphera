import SwiftUI
import UIKit
import UniformTypeIdentifiers
import CryptoKit

struct HelpSheet: View {

    @Environment(\.dismiss) private var dismiss

    let title: String

    let message: String

    var body: some View {

        NavigationStack {

            ScrollView {

                VStack(alignment: .leading, spacing: 18) {

                    Image(systemName: "questionmark.circle.fill")

                        .font(.system(size: 42))

                        .foregroundStyle(.tint)

                    Text(title)

                        .font(.system(size: 28, weight: .bold, design: .rounded))

                    Text(message)

                        .foregroundStyle(.secondary)

                        .lineSpacing(4)

                        .frame(maxWidth: .infinity, alignment: .leading)

                }

                .padding(20)

            }

            .navigationTitle("Help")

            .navigationBarTitleDisplayMode(.inline)

            .toolbar {

                ToolbarItem(placement: .confirmationAction) {

                    Button("Done") { dismiss() }

                }

            }

        }

        .presentationDetents([.medium, .large])

    }

}
// MARK: - Tools
