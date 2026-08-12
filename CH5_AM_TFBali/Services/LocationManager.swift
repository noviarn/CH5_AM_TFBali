import CoreLocation
import SwiftUI

@Observable
final class LocationManager: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()

    @ObservationIgnored
    private(set) var authorizationStatus: CLAuthorizationStatus = .notDetermined

    private(set) var userLocation: CLLocationCoordinate2D?
    private(set) var userHeading: CLLocationDirection?
    private(set) var isLocationEnabled = false

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        manager.activityType = .automotiveNavigation
        manager.headingFilter = 5
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
        if let location = locations.last {
            userLocation = location.coordinate
            if location.course >= 0 {
                userHeading = location.course
            }
        }
        isLocationEnabled = true
    }

    func locationManager(
        _ manager: CLLocationManager,
        didUpdateHeading newHeading: CLHeading
    ) {
        if newHeading.trueHeading >= 0 {
            userHeading = newHeading.trueHeading
        } else if newHeading.magneticHeading >= 0 {
            userHeading = newHeading.magneticHeading
        }
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
}
