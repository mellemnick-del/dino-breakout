import UIKit

/// Taps and thumps through the phone's Taptic Engine. Can be turned off in Settings.
enum Haptics {
    static let key = "haptics"

    static var enabled: Bool {
        UserDefaults.standard.object(forKey: key) as? Bool ?? true
    }

    private static let light = UIImpactFeedbackGenerator(style: .light)
    private static let medium = UIImpactFeedbackGenerator(style: .medium)
    private static let heavy = UIImpactFeedbackGenerator(style: .heavy)
    private static let notice = UINotificationFeedbackGenerator()

    /// Building, selling, and picking things.
    static func tap() {
        guard enabled else { return }
        light.impactOccurred()
    }

    /// Upgrades and abilities.
    static func punch() {
        guard enabled else { return }
        medium.impactOccurred()
    }

    /// A T-Rex arriving.
    static func stomp() {
        guard enabled else { return }
        heavy.impactOccurred(intensity: 1)
    }

    static func success() {
        guard enabled else { return }
        notice.notificationOccurred(.success)
    }

    /// A dino reached the helipad.
    static func warning() {
        guard enabled else { return }
        notice.notificationOccurred(.warning)
    }

    static func failure() {
        guard enabled else { return }
        notice.notificationOccurred(.error)
    }
}
