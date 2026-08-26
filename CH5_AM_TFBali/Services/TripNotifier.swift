import UserNotifications

/// Announces what a rider who isn't looking at the app would otherwise miss: a landmark
/// sliding past the window, their stop coming up, and their finished trip's recap.
///
/// The trip sheet only helps someone already watching the screen. On a bus most people put
/// the phone away, which is exactly when a landmark slides past the window unnoticed — so the
/// same events are also delivered as local notifications.
///
/// Local, not remote: the trigger is the rider's own position against data already on the
/// device, so there is nothing for a server to know or to push.
@MainActor
final class TripNotifier: NSObject, UNUserNotificationCenterDelegate {
    static let shared = TripNotifier()

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
    /// Two lines, never three: a title that says what happened and a body that says what to
    /// do about it. The subtitle slot is left empty on purpose — on the lock screen it draws
    /// at the same weight as the body, and a rider glancing at a banner from a moving bus
    /// reads two lines far quicker than three.
    func announce(title: String, body: String, identifier: String) async {
        guard isAuthorized else { return }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        // No trigger: delivered now, because the bus is already moving past it.
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: nil)
        try? await center.add(request)
    }

    /// Tells the rider their finished trip is worth looking back at.
    ///
    /// ponytail: posted on demand, with no trigger of its own yet — whoever calls this decides
    /// when a trip counts as recapped.
    func announceTripRecap() async {
        await announce(
            title: "Your Trip Recap is Ready!",
            body: "Tap to view and share your journey",
            identifier: "trip-recap"
        )
    }

    /// Clears what the last trip left on the lock screen.
    func reset() {
        center.removeAllDeliveredNotifications()
    }
}
