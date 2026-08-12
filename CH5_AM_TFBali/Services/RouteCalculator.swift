import MapKit

actor RouteCalculator {
    static let shared = RouteCalculator()
    var lastSteps: [DirectionStep] = []

    private let onLoopThreshold: CLLocationDistance = 60

    func calculateRoute(
        waypoints: [CLLocationCoordinate2D],
        userLocation: CLLocationCoordinate2D? = nil,
        landmarks: [CLLocationCoordinate2D] = []
    ) async throws -> (route: MapRoute, steps: [DirectionStep]) {
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

        var approachCoordinates: [CLLocationCoordinate2D] = []
        var approachSteps: [DirectionStep] = []

        if let userLocation, !landmarks.isEmpty, !isOnLoop(userLocation, loopCoordinates: allCoordinates) {
            if let nearest = nearestCoordinate(to: userLocation, in: landmarks) {
                do {
                    let (coordinates, steps) = try await calculateLeg(from: userLocation, to: nearest)
                    approachCoordinates = coordinates
                    approachSteps = steps
                } catch {
                    print("Approach route calculation error: \(error)")
                }
            }
        }

        let combinedSteps = approachSteps + allSteps
        lastSteps = combinedSteps
        let route = MapRoute(
            name: "Kuta Beach Road Loop",
            waypoints: allCoordinates,
            approachWaypoints: approachCoordinates
        )
        return (route, combinedSteps)
    }

    private func calculateLeg(
        from source: CLLocationCoordinate2D,
        to destination: CLLocationCoordinate2D
    ) async throws -> (coordinates: [CLLocationCoordinate2D], steps: [DirectionStep]) {
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: source))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: destination))
        request.transportType = .automobile

        let response = try await MKDirections(request: request).calculate()
        guard let route = response.routes.first else { return ([], []) }
        return (route.polyline.coordinates(), extractSteps(from: route))
    }

    private func isOnLoop(_ location: CLLocationCoordinate2D, loopCoordinates: [CLLocationCoordinate2D]) -> Bool {
        loopCoordinates.contains { $0.distance(to: location) <= onLoopThreshold }
    }

    private func nearestCoordinate(
        to location: CLLocationCoordinate2D,
        in candidates: [CLLocationCoordinate2D]
    ) -> CLLocationCoordinate2D? {
        candidates.min { location.distance(to: $0) < location.distance(to: $1) }
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
