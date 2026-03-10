import Combine
import GameKit
import SwiftUI
import UIKit

// MARK: - GameCenterManager

@MainActor
final class GameCenterManager: ObservableObject {

    static let leaderboardID = "com.manomath.daily"

    @Published var isAuthenticated = false
    @Published var authViewController: UIViewController? = nil

    init() {
        authenticate()
    }

    // MARK: - Authentication

    func authenticate() {
        GKLocalPlayer.local.authenticateHandler = { [weak self] vc, _ in
            Task { @MainActor [weak self] in
                if let vc {
                    // Game Center needs the user to sign in — present immediately
                    self?.authViewController = vc
                    self?.presentAuthViewController(vc)
                } else if GKLocalPlayer.local.isAuthenticated {
                    self?.isAuthenticated = true
                    self?.authViewController = nil
                } else {
                    self?.isAuthenticated = false
                }
            }
        }
    }

    private func presentAuthViewController(_ vc: UIViewController) {
        guard let rootVC = UIApplication.shared
            .connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first?.windows.first?.rootViewController else { return }
        guard rootVC.presentedViewController == nil else { return }
        rootVC.present(vc, animated: true)
    }

    // MARK: - Score Submission

    func submitDailyScore(_ score: Int) async {
        guard GKLocalPlayer.local.isAuthenticated else { return }
        do {
            try await GKLeaderboard.submitScore(
                score,
                context: 0,
                player: GKLocalPlayer.local,
                leaderboardIDs: [Self.leaderboardID]
            )
        } catch {
            print("[GameCenter] Score submission failed: \(error)")
        }
    }

    // MARK: - Leaderboard Presentation

    func showLeaderboard() {
        guard GKLocalPlayer.local.isAuthenticated else { return }
        guard let rootVC = UIApplication.shared
            .connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first?.windows.first?.rootViewController else { return }

        let vc = GKGameCenterViewController(
            leaderboardID: Self.leaderboardID,
            playerScope: .global,
            timeScope: .today
        )
        vc.gameCenterDelegate = LeaderboardDismissCoordinator.shared
        rootVC.present(vc, animated: true)
    }
}

// MARK: - Dismiss Coordinator

private final class LeaderboardDismissCoordinator: NSObject, GKGameCenterControllerDelegate {
    static let shared = LeaderboardDismissCoordinator()
    func gameCenterViewControllerDidFinish(_ vc: GKGameCenterViewController) {
        vc.dismiss(animated: true)
    }
}
