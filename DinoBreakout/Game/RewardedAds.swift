import UIKit
#if canImport(GoogleMobileAds)
import GoogleMobileAds
#endif
#if canImport(UserMessagingPlatform)
import UserMessagingPlatform
#endif
#if canImport(AppTrackingTransparency)
import AppTrackingTransparency
#endif

/// Where a rewarded ad is offered. Each has its own AdMob ad unit, so AdMob
/// reports show which offer players take most.
enum AdPlacement: CaseIterable {
    /// Game over: back in with 5 lives, once per game.
    case revive
    /// Between waves, every 5 waves: bonus cash.
    case bonusCash
    /// Game over: double the amber this run earned.
    case doubleAmber

    /// The ad unit IDs from AdMob (Dino Breakout app).
    var releaseUnitID: String {
        switch self {
        case .revive: "ca-app-pub-5409507532746127/9907679487"
        case .bonusCash: "ca-app-pub-5409507532746127/2036928320"
        case .doubleAmber: "ca-app-pub-5409507532746127/2993866908"
        }
    }
}

/// Optional rewarded ads through Google AdMob. Players only ever see an ad when
/// they tap a "Watch" button for a revive, bonus cash, or double amber; nothing is forced.
///
/// Until the GoogleMobileAds package is added in Xcode, everything here is off
/// and the ad buttons never appear. Debug builds use Google's test ad unit, so
/// tapping test ads is always safe; release builds use the real units.
final class RewardedAds: NSObject {
    static let shared = RewardedAds()

    /// Google's public test unit, safe to tap as much as you like.
    static let testUnitID = "ca-app-pub-3940256099942544/1712485313"

    private func unitID(_ placement: AdPlacement) -> String {
        #if DEBUG
        return RewardedAds.testUnitID
        #else
        return placement.releaseUnitID
        #endif
    }

    /// The SDK is installed, so ad offers can be shown.
    var isAvailable: Bool {
        #if canImport(GoogleMobileAds)
        return true
        #else
        return false
        #endif
    }

    #if canImport(GoogleMobileAds)
    private var ads: [AdPlacement: RewardedAd] = [:]
    private var loading: Set<AdPlacement> = []
    #endif
    private var showing: AdPlacement?
    private var started = false
    private var onReward: (() -> Void)?
    private var earned = false

    /// Ask for consent where the law requires it (EU and UK), then start the SDK and preload an ad.
    func start() {
        guard isAvailable, !started else { return }
        started = true
        #if canImport(UserMessagingPlatform)
        ConsentInformation.shared.requestConsentInfoUpdate(with: RequestParameters()) { [weak self] _ in
            ConsentForm.loadAndPresentIfRequired(from: RewardedAds.topViewController()) { _ in
                self?.startSDK()
            }
        }
        #else
        startSDK()
        #endif
    }

    private func startSDK() {
        #if canImport(GoogleMobileAds)
        MobileAds.shared.start { [weak self] _ in
            for placement in AdPlacement.allCases {
                self?.load(placement)
            }
        }
        #endif
    }

    private func load(_ placement: AdPlacement) {
        #if canImport(GoogleMobileAds)
        guard ads[placement] == nil, !loading.contains(placement) else { return }
        loading.insert(placement)
        RewardedAd.load(with: unitID(placement), request: Request()) { [weak self] ad, _ in
            self?.loading.remove(placement)
            self?.ads[placement] = ad
            ad?.fullScreenContentDelegate = self
        }
        #endif
    }

    /// Shows an ad and calls `onReward` only if the player watches to the end.
    /// Calls `onUnavailable` if no ad is ready yet.
    func show(_ placement: AdPlacement, onReward: @escaping () -> Void, onUnavailable: @escaping () -> Void) {
        #if canImport(GoogleMobileAds)
        guard let ad = ads[placement] else {
            onUnavailable()
            load(placement)
            return
        }
        showing = placement
        self.onReward = onReward
        earned = false
        requestTrackingIfNeeded { [weak self] in
            ad.present(from: RewardedAds.topViewController()) {
                self?.earned = true
            }
        }
        #else
        onUnavailable()
        #endif
    }

    /// Apple's tracking prompt, asked the first time a player chooses to watch an ad.
    private func requestTrackingIfNeeded(then next: @escaping () -> Void) {
        #if canImport(AppTrackingTransparency)
        guard ATTrackingManager.trackingAuthorizationStatus == .notDetermined else {
            next()
            return
        }
        ATTrackingManager.requestTrackingAuthorization { _ in
            DispatchQueue.main.async { next() }
        }
        #else
        next()
        #endif
    }

    private func finish() {
        let reward = earned ? onReward : nil
        onReward = nil
        earned = false
        #if canImport(GoogleMobileAds)
        if let showing {
            ads[showing] = nil
            load(showing)
        }
        #endif
        showing = nil
        if let reward {
            DispatchQueue.main.async { reward() }
        }
    }

    static func topViewController() -> UIViewController? {
        var top = UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.keyWindow }
            .first?.rootViewController
        while let presented = top?.presentedViewController {
            top = presented
        }
        return top
    }
}

#if canImport(GoogleMobileAds)
extension RewardedAds: FullScreenContentDelegate {
    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        finish()
    }

    func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        earned = false
        finish()
    }
}
#endif
