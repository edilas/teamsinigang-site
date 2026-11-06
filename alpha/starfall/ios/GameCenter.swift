import Foundation
import GameKit
import UIKit
import Combine

/// Starfall Game Center integration.
/// Create a matching leaderboard in App Store Connect with the ID below.
@MainActor
final class GameCenter: NSObject, ObservableObject, GKGameCenterControllerDelegate {
    static let boardID = "com.agosllc.starfall.score"

    @Published private(set) var authenticated = false
    weak var bridge: GameView.Bridge?

    func authenticate() {
        GKLocalPlayer.local.authenticateHandler = { [weak self] vc, error in
            guard let self else { return }
            if let vc {
                Self.topViewController()?.present(vc, animated: true)
                return
            }
            self.authenticated = GKLocalPlayer.local.isAuthenticated
            if let error {
                print("Game Center unavailable: \(error.localizedDescription)")
            }
            self.bridge?.reportGameCenter(available: self.authenticated)
        }
    }

    func pushStateToPage() {
        bridge?.reportGameCenter(available: authenticated)
    }

    func submit(score: Int) {
        guard authenticated, score > 0 else { return }
        Task {
            do {
                try await GKLeaderboard.submitScore(
                    score,
                    context: 0,
                    player: GKLocalPlayer.local,
                    leaderboardIDs: [Self.boardID]
                )
            } catch {
                print("Starfall score submission failed: \(error.localizedDescription)")
            }
        }
    }

    func showLeaderboard() {
        guard authenticated else {
            // Triggering authentication again is safer than silently doing nothing.
            authenticate()
            return
        }

        if #available(iOS 18.0, *) {
            GKAccessPoint.shared.trigger(
                leaderboardID: Self.boardID,
                playerScope: .global,
                timeScope: .allTime
            ) { }
        } else {
            let controller = GKGameCenterViewController(
                leaderboardID: Self.boardID,
                playerScope: .global,
                timeScope: .allTime
            )
            controller.gameCenterDelegate = self
            Self.topViewController()?.present(controller, animated: true)
        }
    }

    func gameCenterViewControllerDidFinish(_ gameCenterViewController: GKGameCenterViewController) {
        gameCenterViewController.dismiss(animated: true)
    }

    static func topViewController() -> UIViewController? {
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
        var top = scene?.keyWindow?.rootViewController
        while let presented = top?.presentedViewController { top = presented }
        return top
    }
}
