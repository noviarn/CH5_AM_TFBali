import Combine
import CoreLocation

/// A one-shot "where is the user right now" lookup for the trip planner search flow —
/// distinct from `LocationManager`, which streams continuous fixes for live turn-by-turn
/// navigation. Kept as a separate type since the two have incompatible needs (one-shot
/// continuation vs. a running heading/speed feed) and both are in use at once.
@MainActor
final class SearchLocationManager: NSObject, CLLocationManagerDelegate, ObservableObject {
    enum Status {
        case notDetermined, denied, authorized
    }

    private let manager = CLLocationManager()
    private var continuations: [CheckedContinuation<CLLocationCoordinate2D?, Never>] = []
    private var isRequestingLocation = false

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

        switch authorizationStatus {
        case .denied:
            return nil
        case .notDetermined:
            return await withCheckedContinuation { continuation in
                continuations.append(continuation)
                manager.requestWhenInUseAuthorization()
            }
        case .authorized:
            return await withCheckedContinuation { continuation in
                continuations.append(continuation)
                requestCurrentLocationIfNeeded()
            }
        }
    }

    private func requestCurrentLocationIfNeeded() {
        guard !isRequestingLocation else { return }
        isRequestingLocation = true
        manager.requestLocation()
    }

    private func finishPendingRequests(with coordinate: CLLocationCoordinate2D?) {
        let pending = continuations
        continuations.removeAll()
        isRequestingLocation = false
        pending.forEach { $0.resume(returning: coordinate) }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in
            finishPendingRequests(with: locations.last?.coordinate)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            finishPendingRequests(with: nil)
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            objectWillChange.send()
            switch authorizationStatus {
            case .authorized:
                requestCurrentLocationIfNeeded()
            case .denied:
                finishPendingRequests(with: nil)
            case .notDetermined:
                break
            }
        }
    }
}

#if DEBUG
extension SearchLocationManager {
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

        print("✅ SearchLocationManager.runSelfCheck passed")
    }
}
#endif
