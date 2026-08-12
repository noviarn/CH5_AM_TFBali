import MapKit

actor RouteCalculator {
    static let shared = RouteCalculator()
    var lastSteps: [DirectionStep] = []

    func calculateRoute(waypoints: [CLLocationCoordinate2D]) async throws -> (route: MapRoute, steps: [DirectionStep]) {
        var allCoordinates: [CLLocationCoordinate2D] = []
        var allSteps: [DirectionStep] = []

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

                    let steps = extractSteps(from: route)
                    allSteps.append(contentsOf: steps)
                }
            } catch {
                print("Route calculation error: \(error)")
                throw error
            }
        }

        lastSteps = allSteps
        return (MapRoute(name: "Kuta Beach Road Loop", waypoints: allCoordinates), allSteps)
    }

    private func extractSteps(from route: MKRoute) -> [DirectionStep] {
        var steps: [DirectionStep] = []

        for step in route.steps {
            let instruction = step.instructions.isEmpty ? "Continue" : step.instructions
            let distance = step.distance
            let coordinate = step.polyline.firstCoordinate

            steps.append(DirectionStep(
                instruction: instruction,
                distance: distance,
                coordinate: coordinate
            ))
        }

        return steps
    }
}

extension MKPolyline {
    var firstCoordinate: CLLocationCoordinate2D {
        guard pointCount > 0 else {
            return CLLocationCoordinate2D(latitude: 0, longitude: 0)
        }
        var coord = CLLocationCoordinate2D()
        getCoordinates(&coord, range: NSRange(location: 0, length: 1))
        return coord
    }
}

extension MKPolyline {
    func coordinates() -> [CLLocationCoordinate2D] {
        var coords = [CLLocationCoordinate2D](repeating: CLLocationCoordinate2D(), count: pointCount)
        getCoordinates(&coords, range: NSRange(location: 0, length: pointCount))
        return coords
    }
}
