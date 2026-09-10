import SwiftUI
import UIKit

@main
struct CipheraApp: App {

    init() {
        UINavigationBar.appearance().tintColor = .black
        UITabBar.appearance().tintColor = .black
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
