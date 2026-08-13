import CoreLocation
import SwiftUI

@Observable
final class LocationManager: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()

    @ObservationIgnored
    private(set) var authorizationStatus: CLAuthorizationStatus = .notDetermined

    private(set) var userLocation: CLLocationCoordinate2D?
    private(set) var userHeading: CLLocationDirection?
    private(set) var speed: CLLocationSpeed = 0
    private(set) var isLocationEnabled = false

    /// Course (direction of travel) is steady while moving but meaningless when stopped;
    /// the compass is the reverse. Both used to write to `userHeading`, so whichever
    /// delegate callback fired last won and the map camera swung between them. Keep them
    /// apart and pick per update instead.
    @ObservationIgnored private var courseHeading: CLLocationDirection?
    @ObservationIgnored private var compassHeading: CLLocationDirection?
    @ObservationIgnored private var smoothedHeading: CLLocationDirection?

    /// Below this the course reading is noise and the compass takes over.
    private let courseSpeedThreshold: CLLocationSpeed = 1.0
    /// Fixes worse than this are dropped — they are what make the marker teleport.
    private let maximumHorizontalAccuracy: CLLocationAccuracy = 65
    private let maximumFixAge: TimeInterval = 10
    /// Low-pass weight for heading. Small enough to damp compass jitter, large enough to
    /// keep up with a real turn.
    private let headingSmoothing: CLLocationDirection = 0.3

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        // `.automotiveNavigation` lets Core Location pause updates when it decides you have
        // stopped, then resume with a jump. `.otherNavigation` keeps a continuous stream at
        // walking and bus speeds alike.
        manager.activityType = .otherNavigation
        manager.pausesLocationUpdatesAutomatically = false
        manager.distanceFilter = kCLDistanceFilterNone
        manager.headingFilter = 2
        authorizationStatus = manager.authorizationStatus
    }

    func requestLocation() {
        manager.requestWhenInUseAuthorization()
        manager.startUpdatingLocation()
        if CLLocationManager.headingAvailable() {
            manager.startUpdatingHeading()
        }
    }

    func locationManager(
        _ manager: CLLocationManager,
        didUpdateLocations locations: [CLLocation]
    ) {
        guard let location = locations.last else { return }

        isLocationEnabled = true

        guard isUsable(location) else { return }

        userLocation = location.coordinate
        speed = max(location.speed, 0)

        if location.course >= 0 && speed >= courseSpeedThreshold {
            courseHeading = location.course
        }
        resolveHeading()
    }

    func locationManager(
        _ manager: CLLocationManager,
        didUpdateHeading newHeading: CLHeading
    ) {
        if newHeading.trueHeading >= 0 {
            compassHeading = newHeading.trueHeading
        } else if newHeading.magneticHeading >= 0 {
            compassHeading = newHeading.magneticHeading
        }
        resolveHeading()
    }

    func locationManager(
        _ manager: CLLocationManager,
        didFailWithError error: Error
    ) {
        isLocationEnabled = false
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
    }

    /// Reject fixes that would drag the marker somewhere the rider is not: unknown or wide
    /// accuracy, and cached fixes replayed by Core Location when it starts up.
    private func isUsable(_ location: CLLocation) -> Bool {
        guard location.horizontalAccuracy > 0,
              location.horizontalAccuracy <= maximumHorizontalAccuracy else { return false }
        return abs(location.timestamp.timeIntervalSinceNow) <= maximumFixAge
    }

    private func resolveHeading() {
        let preferred = speed >= courseSpeedThreshold
            ? (courseHeading ?? compassHeading)
            : (compassHeading ?? courseHeading)
        guard let preferred else { return }

        guard let current = smoothedHeading else {
            smoothedHeading = preferred.normalizedCompassHeading
            userHeading = smoothedHeading
            return
        }

        let smoothed = (current + current.shortestTurn(to: preferred) * headingSmoothing)
            .normalizedCompassHeading
        smoothedHeading = smoothed
        userHeading = smoothed
    }
}
