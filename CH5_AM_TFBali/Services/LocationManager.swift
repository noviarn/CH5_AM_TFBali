import Combine
import CoreLocation

@MainActor
final class LocationManager: NSObject, CLLocationManagerDelegate, ObservableObject {
    enum Status {
        case notDetermined, denied, authorized
    }

    private let manager = CLLocationManager()
    private var continuation: CheckedContinuation<CLLocationCoordinate2D?, Never>?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
    }

    var authorizationStatus: Status {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            return .authorized
        case .denied, .restricted:
            return .denied
        default:
            return .notDetermined
        }
    }

    /// True when iOS is deliberately fuzzing our fix because Precise Location is off for this app.
    var hasReducedAccuracy: Bool {
        manager.accuracyAuthorization == .reducedAccuracy
    }

    func requestAuthorization() {
        manager.requestWhenInUseAuthorization()
    }

    /// CLLocationManager.location is a system-wide cache that survives launches — it can be hours old
    /// and from another area. Only reuse it when recent and accurate; otherwise ask for a fresh fix.
    nonisolated static func isUsable(_ location: CLLocation, now: Date = Date(), maxAge: TimeInterval = 60, maxAccuracyMeters: CLLocationDistance = 200) -> Bool {
        location.horizontalAccuracy >= 0 &&
        location.horizontalAccuracy <= maxAccuracyMeters &&
        now.timeIntervalSince(location.timestamp) <= maxAge
    }

    func currentLocation() async -> CLLocationCoordinate2D? {
        if let cached = manager.location, Self.isUsable(cached) {
            return cached.coordinate
        }
        return await withCheckedContinuation { continuation in
            self.continuation = continuation
            manager.requestLocation()
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in
            continuation?.resume(returning: locations.last?.coordinate)
            continuation = nil
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            continuation?.resume(returning: nil)
            continuation = nil
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            objectWillChange.send()
        }
    }
}

#if DEBUG
extension LocationManager {
    nonisolated static func runSelfCheck() {
        let now = Date()
        let here = CLLocationCoordinate2D(latitude: -8.7, longitude: 115.2)

        func sample(ageSeconds: TimeInterval, accuracy: CLLocationDistance) -> CLLocation {
            CLLocation(
                coordinate: here,
                altitude: 0,
                horizontalAccuracy: accuracy,
                verticalAccuracy: 0,
                timestamp: now.addingTimeInterval(-ageSeconds)
            )
        }

        assert(isUsable(sample(ageSeconds: 5, accuracy: 10), now: now), "a fresh, accurate fix should be usable")
        // The reported bug: a cached fix from hours ago in another area was trusted as the origin.
        assert(!isUsable(sample(ageSeconds: 3600, accuracy: 10), now: now), "an hour-old fix must be rejected as stale")
        assert(!isUsable(sample(ageSeconds: 5, accuracy: 3000), now: now), "a 3km-accuracy fix must be rejected as too coarse")
        assert(!isUsable(sample(ageSeconds: 5, accuracy: -1), now: now), "an invalid (negative accuracy) fix must be rejected")

        print("✅ LocationManager.runSelfCheck passed")
    }
}
#endif
