import MapKit

actor RouteCalculator {
    static let shared = RouteCalculator()

    func calculateRoute(waypoints: [CLLocationCoordinate2D]) async throws -> MapRoute {
        var allCoordinates: [CLLocationCoordinate2D] = []

        for i in 0..<(waypoints.count - 1) {
            let request = MKDirections.Request()
            request.source = MKMapItem(placemark: MKPlacemark(coordinate: waypoints[i]))
            request.destination = MKMapItem(placemark: MKPlacemark(coordinate: waypoints[i + 1]))
            request.transportType = .automobile

            let directions = MKDirections(request: request)

            do {
                let response = try await directions.calculate()
                if let route = response.routes.first {
                    let routeCoordinates = route.polyline.coordinates()
                    if i == 0 {
                        allCoordinates.append(contentsOf: routeCoordinates)
                    } else {
                        allCoordinates.append(contentsOf: routeCoordinates.dropFirst())
                    }
                }
            } catch {
                print("Route calculation error: \(error)")
                throw error
            }
        }

        return MapRoute(name: "Kuta Beach Road Loop", waypoints: allCoordinates)
    }
}

extension MKPolyline {
    func coordinates() -> [CLLocationCoordinate2D] {
        var coords = [CLLocationCoordinate2D](repeating: CLLocationCoordinate2D(), count: pointCount)
        getCoordinates(&coords, range: NSRange(location: 0, length: pointCount))
        return coords
    }
}
