import MapKit

actor LandmarkProximityDetector {
    static let shared = LandmarkProximityDetector()
    private let proximityThreshold: CLLocationDistance = 100

    func detectNearbyLandmarks(
        userLocation: CLLocationCoordinate2D?,
        landmark: Landmark?,
        routeDirection: CLLocationDirection? = nil
    ) -> (distance: CLLocationDistance, side: String, name: String)? {
        guard let userLoc = userLocation, let landmark = landmark else { return nil }

        var closestLandmark: (index: Int, distance: CLLocationDistance) = (0, .infinity)

        for (index, coord) in landmark.coordinates.enumerated() {
            let distance = userLoc.distance(to: coord)
            if distance < closestLandmark.distance {
                closestLandmark = (index, distance)
            }
        }

        guard closestLandmark.distance <= proximityThreshold else { return nil }

        let side = determineSide(
            userLocation: userLoc,
            landmarkLocation: landmark.coordinates[closestLandmark.index],
            heading: routeDirection
        )

        return (
            distance: closestLandmark.distance,
            side: side,
            name: "Landmark \(closestLandmark.index + 1)"
        )
    }

    private func determineSide(
        userLocation: CLLocationCoordinate2D,
        landmarkLocation: CLLocationCoordinate2D,
        heading: CLLocationDirection?
    ) -> String {
        let bearing = userLocation.bearing(to: landmarkLocation)
        let defaultHeading = heading ?? 0

        let diff = (bearing - defaultHeading).truncatingRemainder(dividingBy: 360)
        return diff < 180 ? "left" : "right"
    }
}

extension CLLocationCoordinate2D {
    func distance(to other: CLLocationCoordinate2D) -> CLLocationDistance {
        let loc1 = CLLocation(latitude: latitude, longitude: longitude)
        let loc2 = CLLocation(latitude: other.latitude, longitude: other.longitude)
        return loc1.distance(from: loc2)
    }

    func bearing(to other: CLLocationCoordinate2D) -> CLLocationDirection {
        let lat1 = latitude * .pi / 180
        let lon1 = longitude * .pi / 180
        let lat2 = other.latitude * .pi / 180
        let lon2 = other.longitude * .pi / 180

        let dlon = lon2 - lon1
        let y = sin(dlon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dlon)

        let bearing = atan2(y, x) * 180 / .pi
        return bearing.truncatingRemainder(dividingBy: 360)
    }
}
