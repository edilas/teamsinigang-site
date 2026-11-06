import SwiftUI
import UIKit

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        supportedInterfaceOrientationsFor window: UIWindow?
    ) -> UIInterfaceOrientationMask {
        .portrait
    }
}

@main
struct StarfallApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var store = GameStore()
    @StateObject private var gameCenter = GameCenter()

    var body: some Scene {
        WindowGroup {
            GameView()
                .environmentObject(store)
                .environmentObject(gameCenter)
                .ignoresSafeArea()
                .statusBarHidden()
                .persistentSystemOverlays(.hidden)
                .defersSystemGestures(on: .all)
                .task {
                    gameCenter.authenticate()
                    await store.loadProducts()
                    await store.refreshEntitlements()
                }
        }
    }
}
