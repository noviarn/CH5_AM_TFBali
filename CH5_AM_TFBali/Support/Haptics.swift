import SwiftUI

/// One place for the app's haptics. `.sensoryFeedback` is the native SwiftUI hook; routing it
/// through here keeps the style consistent — impact for plain taps and toggles, success for
/// actions that begin or end something, selection for picking between options.
enum Haptics {
    static func tap() {
        HapticBridge.shared.impact(style: .light)
    }

    static func toggle() {
        HapticBridge.shared.impact(style: .rigid)
    }

    static func success() {
        HapticBridge.shared.notification(type: .success)
    }

    static func selection() {
        HapticBridge.shared.selection()
    }
}

/// `.sensoryFeedback` must attach to a view, but many triggers here are plain `Button(action:)`
/// closures (not view builders). This bridge lets any code path fire the same haptics without
/// scattering UIKit generator instances through every view.
private final class HapticBridge {
    static let shared = HapticBridge()

    private let impactLight = UIImpactFeedbackGenerator(style: .light)
    private let impactRigid = UIImpactFeedbackGenerator(style: .rigid)
    private let notification = UINotificationFeedbackGenerator()
    private let selectionGenerator = UISelectionFeedbackGenerator()

    func impact(style: UIImpactFeedbackGenerator.FeedbackStyle) {
        switch style {
        case .light:
            impactLight.prepare()
            impactLight.impactOccurred()
        case .rigid:
            impactRigid.prepare()
            impactRigid.impactOccurred()
        default:
            UIImpactFeedbackGenerator(style: style).impactOccurred()
        }
    }

    func notification(type: UINotificationFeedbackGenerator.FeedbackType) {
        notification.prepare()
        notification.notificationOccurred(type)
    }

    func selection() {
        selectionGenerator.prepare()
        selectionGenerator.selectionChanged()
    }
}
