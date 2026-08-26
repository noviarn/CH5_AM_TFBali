import UserNotifications

/// Announces a landmark to a rider who isn't looking at the app.
///
/// The map card only helps someone already watching the screen. On a bus most people put the
/// phone away, which is exactly when a landmark slides past the window unnoticed — so the
/// same proximity event is also delivered as a local notification.
///
/// Local, not remote: the trigger is the rider's own position against data already on the
/// device, so there is nothing for a server to know or to push.
@MainActor
final class LandmarkNotifier: NSObject, UNUserNotificationCenterDelegate {
    static let shared = LandmarkNotifier()

    private let center = UNUserNotificationCenter.current()
    private var isAuthorized = false

    private override init() {
        super.init()
        // Without a delegate iOS swallows banners while the app is on screen. A rider
        // watching the map should get the same announcement as one with the phone away.
        center.delegate = self
    }

    /// Shows the banner even in the foreground.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .list]
    }

    /// Asked for when a trip starts rather than at launch: by then the rider has said where
    /// they're going, so the reason to interrupt them is obvious.
    func requestAuthorizationIfNeeded() async {
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .notDetermined:
            isAuthorized = (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
        case .authorized, .provisional, .ephemeral:
            isAuthorized = true
        default:
            isAuthorized = false
        }
    }

    /// Posts one announcement. Deliberately keeps no history of its own — `RouteMapView`
    /// decides when a landmark has reached a new stage, so that judgement lives in one place
    /// and can't drift from the haptics fired alongside it.
    ///
    /// Shaped to read like the card on the map: the stage on top, the place under it, and
    /// the detail last.
    func announce(title: String, subtitle: String, body: String, identifier: String) async {
        guard isAuthorized else { return }

        let content = UNMutableNotificationContent()
        content.title = title
        content.subtitle = subtitle
        content.body = body
        content.sound = .default
        // No trigger: delivered now, because the bus is already moving past it.
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: nil)
        try? await center.add(request)
    }

    /// Clears what the last trip left on the lock screen.
    func reset() {
        center.removeAllDeliveredNotifications()
    }
}
