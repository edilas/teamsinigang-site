import SwiftUI
import WebKit
import UIKit

/// Hosts Starfall's index.html and bridges StoreKit + Game Center into JavaScript.
struct GameView: UIViewRepresentable {
    @EnvironmentObject var store: GameStore
    @EnvironmentObject var gameCenter: GameCenter

    func makeCoordinator() -> Bridge { Bridge(store: store, gameCenter: gameCenter) }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []

        let userContent = WKUserContentController()
        userContent.add(context.coordinator, name: "iap")
        userContent.add(context.coordinator, name: "gamecenter")
        userContent.add(context.coordinator, name: "haptics")
        userContent.addUserScript(
            WKUserScript(source: Self.bridgeJS, injectionTime: .atDocumentStart, forMainFrameOnly: true)
        )
        config.userContentController = userContent

        let web = WKWebView(frame: .zero, configuration: config)
        web.isOpaque = false
        web.backgroundColor = .black
        web.scrollView.bounces = false
        web.scrollView.contentInsetAdjustmentBehavior = .never
        web.scrollView.decelerationRate = .fast
        web.configuration.dataDetectorTypes = []
        web.scrollView.pinchGestureRecognizer?.isEnabled = false
        web.scrollView.minimumZoomScale = 1
        web.scrollView.maximumZoomScale = 1
        web.scrollView.bouncesZoom = false
        web.allowsBackForwardNavigationGestures = false
        web.navigationDelegate = context.coordinator

        #if DEBUG
        if #available(iOS 16.4, *) { web.isInspectable = true }
        #endif

        context.coordinator.web = web
        store.bridge = context.coordinator
        gameCenter.bridge = context.coordinator
        load(into: web)
        return web
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        context.coordinator.pushSafeAreas()
    }

    private func load(into web: WKWebView) {
        guard let staged = Self.stageResources() else {
            web.loadHTMLString(Self.failureHTML, baseURL: nil)
            return
        }
        web.loadFileURL(staged, allowingReadAccessTo: staged.deletingLastPathComponent())
    }

    /// Copy the whole web folder so Starfall's nested assets/ directory is preserved.
    private static func stageResources() -> URL? {
        let fm = FileManager.default
        guard let source = Bundle.main.url(forResource: "index", withExtension: "html", subdirectory: "web")
                ?? Bundle.main.url(forResource: "index", withExtension: "html") else { return nil }

        let sourceDir = source.deletingLastPathComponent()
        guard let support = try? fm.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        ) else { return source }

        let destDir = support.appendingPathComponent("StarfallWeb", isDirectory: true)
        try? fm.removeItem(at: destDir)
        do {
            try fm.createDirectory(at: destDir, withIntermediateDirectories: true)
            try copyDirectoryContents(from: sourceDir, to: destDir, fileManager: fm)
        } catch {
            print("Starfall web staging failed: \(error.localizedDescription)")
            return source
        }

        let dest = destDir.appendingPathComponent("index.html")
        return fm.fileExists(atPath: dest.path) ? dest : source
    }

    private static func copyDirectoryContents(from source: URL, to destination: URL, fileManager fm: FileManager) throws {
        let items = try fm.contentsOfDirectory(at: source, includingPropertiesForKeys: [.isDirectoryKey])
        for item in items {
            let values = try item.resourceValues(forKeys: [.isDirectoryKey])
            let target = destination.appendingPathComponent(item.lastPathComponent, isDirectory: values.isDirectory == true)
            if values.isDirectory == true {
                try fm.createDirectory(at: target, withIntermediateDirectories: true)
                try copyDirectoryContents(from: item, to: target, fileManager: fm)
            } else {
                try fm.copyItem(at: item, to: target)
            }
        }
    }

    private static let failureHTML = """
    <html><head><meta name="viewport" content="width=device-width,initial-scale=1"></head>
    <body style="background:#030a16;color:#e8f8ff;font:14px -apple-system;padding:32px">
    <h2>Starfall web files not found</h2>
    <p>Add the <code>web</code> folder to the app target's Copy Bundle Resources phase.</p>
    </body></html>
    """

    static let bridgeJS = """
    window.nativeGameCenter = {
      submit: function(score){ window.webkit.messageHandlers.gamecenter.postMessage({action:'submit', score:score}); },
      show: function(){ window.webkit.messageHandlers.gamecenter.postMessage({action:'show'}); }
    };
    window.nativeIAP = {
      unlock: function(pid){ window.webkit.messageHandlers.iap.postMessage({action:'unlock', product:pid}); },
      restore: function(pid){ window.webkit.messageHandlers.iap.postMessage({action:'restore', product:pid}); }
    };
    window.nativeHaptics = {
      fire: function(kind){ window.webkit.messageHandlers.haptics.postMessage({kind:kind||'light'}); }
    };
    """

    final class Bridge: NSObject, WKScriptMessageHandler, WKNavigationDelegate {
        weak var web: WKWebView?
        let store: GameStore
        let gameCenter: GameCenter

        init(store: GameStore, gameCenter: GameCenter) {
            self.store = store
            self.gameCenter = gameCenter
            super.init()
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(appWillResignActive),
                name: UIApplication.willResignActiveNotification,
                object: nil
            )
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(appDidBecomeActive),
                name: UIApplication.didBecomeActiveNotification,
                object: nil
            )
        }

        deinit {
            NotificationCenter.default.removeObserver(self)
        }

        @objc private func appWillResignActive() {
            DispatchQueue.main.async { [weak self] in
                self?.web?.evaluateJavaScript("window.starfallNativePause && window.starfallNativePause()")
            }
        }

        @objc private func appDidBecomeActive() {
            DispatchQueue.main.async { [weak self] in
                self?.web?.evaluateJavaScript("window.starfallNativeResume && window.starfallNativeResume()")
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            pushSafeAreas()
            Task { @MainActor in
                self.store.pushStateToPage()
                self.gameCenter.pushStateToPage()
            }
        }

        func pushSafeAreas() {
            guard let web else { return }
            let window = web.window
                ?? UIApplication.shared.connectedScenes
                    .compactMap { ($0 as? UIWindowScene)?.keyWindow }
                    .first
            let insets = window?.safeAreaInsets ?? web.safeAreaInsets
            let top = max(insets.top, web.safeAreaInsets.top)
            let js = """
            (function(){var r=document.documentElement.style;
              r.setProperty('--sa-top','\(Int(top.rounded()))px');
              r.setProperty('--sa-bottom','\(Int(insets.bottom.rounded()))px');
              r.setProperty('--sa-left','\(Int(insets.left.rounded()))px');
              r.setProperty('--sa-right','\(Int(insets.right.rounded()))px');})();
            """
            web.evaluateJavaScript(js)
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            switch message.name {
            case "gamecenter":
                guard let data = message.body as? [String: Any],
                      let action = data["action"] as? String else { return }
                if action == "submit" {
                    let raw = data["score"]
                    let score = (raw as? Int) ?? Int((raw as? Double) ?? 0)
                    Task { @MainActor in self.gameCenter.submit(score: score) }
                } else if action == "show" {
                    Task { @MainActor in self.gameCenter.showLeaderboard() }
                }
            case "iap":
                guard let data = message.body as? [String: Any],
                      let action = data["action"] as? String else { return }
                let productID = data["product"] as? String ?? GameStore.productID
                Task { @MainActor in
                    if action == "restore" { await self.store.restore() }
                    else { await self.store.purchase(productID) }
                }
            case "haptics":
                guard let data = message.body as? [String: Any] else { return }
                let kind = data["kind"] as? String ?? "light"
                Task { @MainActor in self.fireHaptic(kind) }
            default:
                break
            }
        }

        @MainActor private func fireHaptic(_ kind: String) {
            switch kind {
            case "selection":
                let generator = UISelectionFeedbackGenerator()
                generator.prepare()
                generator.selectionChanged()
            case "success":
                let generator = UINotificationFeedbackGenerator()
                generator.prepare()
                generator.notificationOccurred(.success)
            case "warning":
                let generator = UINotificationFeedbackGenerator()
                generator.prepare()
                generator.notificationOccurred(.warning)
            case "error":
                let generator = UINotificationFeedbackGenerator()
                generator.prepare()
                generator.notificationOccurred(.error)
            case "medium":
                let generator = UIImpactFeedbackGenerator(style: .medium)
                generator.prepare()
                generator.impactOccurred()
            case "heavy":
                let generator = UIImpactFeedbackGenerator(style: .heavy)
                generator.prepare()
                generator.impactOccurred()
            default:
                let generator = UIImpactFeedbackGenerator(style: .light)
                generator.prepare()
                generator.impactOccurred()
            }
        }

        @MainActor func reportGameCenter(available: Bool) {
            web?.evaluateJavaScript("window.starfallOnGameCenter && window.starfallOnGameCenter(\(available))")
        }

        @MainActor func reportPrice(_ price: String) {
            let safe = jsEscaped(price)
            web?.evaluateJavaScript("window.starfallOnPrice && window.starfallOnPrice('\(safe)')")
        }

        @MainActor func reportEntitlement(owned: Bool) {
            web?.evaluateJavaScript("window.starfallOnEntitlement && window.starfallOnEntitlement(\(owned))")
        }

        @MainActor func reportPurchase(success: Bool, message: String?) {
            let safe = jsEscaped(message ?? "")
            web?.evaluateJavaScript(
                "window.starfallOnPurchaseResult && window.starfallOnPurchaseResult(\(success), '\(safe)')"
            )
        }

        private func jsEscaped(_ value: String) -> String {
            value
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "'", with: "\\'")
                .replacingOccurrences(of: "\n", with: "\\n")
                .replacingOccurrences(of: "\r", with: "")
        }
    }
}
