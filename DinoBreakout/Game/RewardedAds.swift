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

/// Optional rewarded ads through Google AdMob. Players only ever see an ad when
/// they tap a "Watch an ad" button for a revive or bonus cash; nothing is forced.
///
/// Until the GoogleMobileAds package is added in Xcode, everything here is off
/// and the ad buttons never appear. Debug builds use Google's test ad unit;
/// release builds use `releaseUnitID`, and stay ad free while it's empty.
final class RewardedAds: NSObject {
    static let shared = RewardedAds()

    /// Your rewarded ad unit ID from AdMob, like "ca-app-pub-1234567890123456/1234567890".
    static let releaseUnitID = ""
    /// Google's public test unit, safe to tap as much as you like.
    static let testUnitID = "ca-app-pub-3940256099942544/1712485313"

    private var unitID: String {
        #if DEBUG
        return RewardedAds.testUnitID
        #else
        return RewardedAds.releaseUnitID
        #endif
    }

    /// The SDK is installed and there's an ad unit to load from.
    var isAvailable: Bool {
        #if canImport(GoogleMobileAds)
        return !unitID.isEmpty
        #else
        return false
        #endif
    }

    #if canImport(GoogleMobileAds)
    private var ad: RewardedAd?
    #endif
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
            self?.load()
        }
        #endif
    }

    private func load() {
        #if canImport(GoogleMobileAds)
        RewardedAd.load(with: unitID, request: Request()) { [weak self] ad, _ in
            self?.ad = ad
            ad?.fullScreenContentDelegate = self
        }
        #endif
    }

    /// Shows an ad and calls `onReward` only if the player watches to the end.
    /// Calls `onUnavailable` if no ad is ready yet.
    func show(onReward: @escaping () -> Void, onUnavailable: @escaping () -> Void) {
        #if canImport(GoogleMobileAds)
        guard let ad else {
            onUnavailable()
            load()
            return
        }
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
        ad = nil
        load()
        #endif
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
