import MapKit

actor RouteCalculator {
    static let shared = RouteCalculator()
    var lastSteps: [DirectionStep] = []

    private let onLoopThreshold: CLLocationDistance = 60
    private let duplicateVertexThreshold: CLLocationDistance = 1

    /// Builds a loop route anchored at the bus stop nearest to `userLocation`, so the
    /// trip starts and ends at that same stop (point A to point A). If the user isn't
    /// already on the loop, an approach leg from their location to that stop is prepended.
    func calculateRoute(
        waypoints: [CLLocationCoordinate2D],
        userLocation: CLLocationCoordinate2D? = nil,
        busStops: [BusStop] = []
    ) async throws -> (route: MapRoute, steps: [DirectionStep], startStop: BusStop?) {
        let startStop = userLocation.flatMap { nearestBusStop(to: $0, in: busStops) }
        let loopWaypoints = anchoredLoopWaypoints(baseWaypoints: waypoints, anchor: startStop)

        var allCoordinates: [CLLocationCoordinate2D] = []
        var allSteps: [DirectionStep] = []

        for i in 0..<(loopWaypoints.count - 1) {
            let (coordinates, steps) = try await calculateLeg(from: loopWaypoints[i], to: loopWaypoints[i + 1])
            if i == 0 {
                allCoordinates.append(contentsOf: coordinates)
            } else {
                allCoordinates.append(contentsOf: coordinates.dropFirst())
            }
            allSteps.append(contentsOf: steps)
        }

        var approachCoordinates: [CLLocationCoordinate2D] = []
        var approachSteps: [DirectionStep] = []

        if let userLocation, let startStop, !isOnLoop(userLocation, loopCoordinates: allCoordinates) {
            do {
                let (coordinates, steps) = try await calculateLeg(from: userLocation, to: startStop.coordinate)
                approachCoordinates = coordinates
                approachSteps = steps
            } catch {
                print("Approach route calculation error: \(error)")
            }
        }

        let combinedSteps = approachSteps + allSteps
        lastSteps = combinedSteps
        let route = MapRoute(
            name: "Kuta Beach Road Loop",
            waypoints: allCoordinates,
            approachWaypoints: approachCoordinates
        )
        return (route, combinedSteps, startStop)
    }

    /// Rotates the loop's vertices to begin at the one nearest `anchor`, then wraps the
    /// whole array in the anchor coordinate so the resulting path is anchor -> ...loop... -> anchor.
    private func anchoredLoopWaypoints(
        baseWaypoints: [CLLocationCoordinate2D],
        anchor: BusStop?
    ) -> [CLLocationCoordinate2D] {
        guard let anchor else { return baseWaypoints }

        var vertices = baseWaypoints
        if let first = vertices.first, let last = vertices.last,
           vertices.count > 1, first.distance(to: last) <= duplicateVertexThreshold {
            vertices.removeLast()
        }
        guard !vertices.isEmpty else { return baseWaypoints }

        let nearestIndex = vertices.indices.min {
            anchor.coordinate.distance(to: vertices[$0]) < anchor.coordinate.distance(to: vertices[$1])
        } ?? 0
        let rotated = Array(vertices[nearestIndex...] + vertices[..<nearestIndex])

        return [anchor.coordinate] + rotated + [rotated[0], anchor.coordinate]
    }

    private func nearestBusStop(
        to location: CLLocationCoordinate2D,
        in stops: [BusStop]
    ) -> BusStop? {
        stops.min { location.distance(to: $0.coordinate) < location.distance(to: $1.coordinate) }
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

    private func extractSteps(from route: MKRoute) -> [DirectionStep] {
        var steps: [DirectionStep] = []

        for step in route.steps {
            // MapKit prefixes every leg with a placeholder "depart" step (no instruction,
            // zero distance). With multiple concatenated legs these pile up and stall
            // progress tracking on a dead entry, so skip them.
            guard !step.instructions.isEmpty || step.distance > 0 else { continue }

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
