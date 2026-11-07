//
//  KlimaxApp.swift
//  Klimax
//

import SwiftUI
import UIKit

final class KlimaxAppDelegate: NSObject, UIApplicationDelegate {
    static var supportedOrientations: UIInterfaceOrientationMask = .portrait

    func application(
        _ application: UIApplication,
        supportedInterfaceOrientationsFor window: UIWindow?
    ) -> UIInterfaceOrientationMask {
        Self.supportedOrientations
    }
}

@main
struct KlimaxApp: App {
    @UIApplicationDelegateAdaptor(KlimaxAppDelegate.self) private var appDelegate

    // One shared content store for the whole app. Today it loads the bundled
    // scripture.json; later this same object will fetch from the CMS instead.
    @State private var scripture = ScriptureStore()
    @State private var diptycha = DiptychaStore()

    var body: some Scene {
        WindowGroup {
            Group {
                #if DEBUG
                if let preview = ProcessInfo.processInfo.arguments.first(where: { $0.hasPrefix("--athos-preview=") }) {
                    // Isolated visual QA; production launches always use RootView.
                    AthosReferencePreview(screen: String(preview.dropFirst("--athos-preview=".count)))
                } else {
                    RootView()
                }
                #else
                RootView()
                #endif
            }
                .environment(scripture)
                .environment(diptycha)
                .task { await scripture.load() }
        }
    }
}
