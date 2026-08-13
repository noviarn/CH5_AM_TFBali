import MapKit

actor RouteCalculator {
    static let shared = RouteCalculator()

    struct Result {
        let route: MapRoute
        let steps: [DirectionStep]
    }

    private let onRouteThreshold: CLLocationDistance = 60

    /// Routes from the bus stop nearest `userLocation` (point A, bus-stop-first) to the
    /// fixed `destination` (point B) via a single MKDirections leg — no declared road shape
    /// to follow, so MapKit picks the real road directly. If the user isn't already on that
    /// path, an approach leg from their location to the anchor stop is prepended.
    func calculateRoute(
        destination: CLLocationCoordinate2D,
        userLocation: CLLocationCoordinate2D? = nil,
        busStops: [BusStop] = []
    ) async -> Result {
        let anchor = userLocation.flatMap { nearestBusStop(to: $0, in: busStops) } ?? busStops.first

        var mainCoordinates: [CLLocationCoordinate2D] = []
        var mainSteps: [DirectionStep] = []

        if let anchor {
            let leg = await calculateLeg(from: anchor.coordinate, to: destination)
            mainCoordinates = leg.coordinates
            mainSteps = indexed(leg.steps, along: leg.coordinates, offset: 0)
        }

        var approachCoordinates: [CLLocationCoordinate2D] = []
        var approachSteps: [DirectionStep] = []

        if let userLocation, let anchor, !isOnRoute(userLocation, routeCoordinates: mainCoordinates) {
            let leg = await approachLeg(from: userLocation, to: anchor.coordinate)
            approachCoordinates = leg.coordinates
            approachSteps = indexed(leg.steps, along: leg.coordinates, offset: 0)
        }

        let offset = approachCoordinates.count
        let combinedSteps = monotonic(approachSteps + mainSteps.map { $0.shifted(by: offset) })

        let route = MapRoute(
            name: "Bus Corridor Route",
            waypoints: mainCoordinates,
            approachWaypoints: approachCoordinates
        )
        return Result(route: route, steps: combinedSteps)
    }

    private func nearestBusStop(
        to location: CLLocationCoordinate2D,
        in stops: [BusStop]
    ) -> BusStop? {
        stops.min { location.distance(to: $0.coordinate) < location.distance(to: $1.coordinate) }
    }

    /// The approach leg is the rider's only cue for reaching the first stop, so it must
    /// always produce something. Driving directions can fail outright on pedestrian-only
    /// lanes, so fall back to walking, then to a straight line.
    private func approachLeg(
        from source: CLLocationCoordinate2D,
        to destination: CLLocationCoordinate2D
    ) async -> (coordinates: [CLLocationCoordinate2D], steps: [DirectionStep]) {
        for transportType in [MKDirectionsTransportType.automobile, .walking] {
            let leg = await calculateLeg(from: source, to: destination, transportType: transportType)
            if leg.coordinates.count >= 2 { return leg }
        }

        print("Approach directions unavailable; drawing a direct line to the stop")
        return (
            coordinates: [source, destination],
            steps: [DirectionStep(
                instruction: "Head to the nearest bus stop",
                distance: source.distance(to: destination),
                coordinate: destination
            )]
        )
    }

    /// Walking directions between two transfer stops. Unlike the approach leg this never
    /// falls back to driving — a transfer between corridors is on foot by definition — but
    /// still falls back to a straight line if MapKit has no pedestrian route in the area.
    func walkingTransferLeg(
        from source: CLLocationCoordinate2D,
        to destination: CLLocationCoordinate2D
    ) async -> (coordinates: [CLLocationCoordinate2D], steps: [DirectionStep]) {
        let leg = await calculateLeg(from: source, to: destination, transportType: .walking)
        if leg.coordinates.count >= 2 { return leg }

        print("Walking transfer directions unavailable; drawing a direct line between stops")
        return (
            coordinates: [source, destination],
            steps: [DirectionStep(
                instruction: "Walk to the next stop",
                distance: source.distance(to: destination),
                coordinate: destination
            )]
        )
    }

    private func calculateLeg(
        from source: CLLocationCoordinate2D,
        to destination: CLLocationCoordinate2D,
        transportType: MKDirectionsTransportType = .automobile
    ) async -> (coordinates: [CLLocationCoordinate2D], steps: [DirectionStep]) {
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: source))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: destination))
        request.transportType = transportType

        do {
            let response = try await MKDirections(request: request).calculate()
            guard let route = response.routes.first else { return ([], []) }
            return (route.polyline.coordinates(), extractSteps(from: route))
        } catch {
            print("Route leg failed: \(error.localizedDescription)")
            return ([], [])
        }
    }

    /// Distance to the route *line*, not to its vertices — vertices can sit hundreds of
    /// metres apart on a straight stretch, which used to make a rider standing right on the
    /// road look off-route and trigger a pointless approach leg.
    private func isOnRoute(
        _ location: CLLocationCoordinate2D,
        routeCoordinates: [CLLocationCoordinate2D]
    ) -> Bool {
        guard let progress = RouteGeometry.progress(of: location, along: routeCoordinates) else {
            return false
        }
        return progress.offRouteDistance <= onRouteThreshold
    }

    /// Anchors each maneuver to its position along the leg it came from. Searching the whole
    /// route instead would snap maneuvers onto the wrong lap wherever the loop crosses itself.
    private func indexed(
        _ steps: [DirectionStep],
        along coordinates: [CLLocationCoordinate2D],
        offset: Int
    ) -> [DirectionStep] {
        steps.map { step in
            DirectionStep(
                instruction: step.instruction,
                distance: step.distance,
                coordinate: step.coordinate,
                pathIndex: offset + RouteGeometry.nearestIndex(to: step.coordinate, along: coordinates)
            )
        }
    }

    /// Progress reads the step list as a forward-only sequence, so clamp any maneuver that
    /// projected slightly behind its predecessor.
    private func monotonic(_ steps: [DirectionStep]) -> [DirectionStep] {
        var highest = 0
        return steps.map { step in
            highest = max(highest, step.pathIndex)
            return step.pathIndex == highest ? step : step.shifted(by: highest - step.pathIndex)
        }
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

    func coordinates() -> [CLLocationCoordinate2D] {
        var coords = [CLLocationCoordinate2D](repeating: CLLocationCoordinate2D(), count: pointCount)
        getCoordinates(&coords, range: NSRange(location: 0, length: pointCount))
        return coords
    }
}
