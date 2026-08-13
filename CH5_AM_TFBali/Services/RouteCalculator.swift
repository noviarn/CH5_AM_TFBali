import MapKit

actor RouteCalculator {
    static let shared = RouteCalculator()

    struct Result {
        let route: MapRoute
        let steps: [DirectionStep]
        let startStop: BusStop?
    }

    private let onLoopThreshold: CLLocationDistance = 60
    private let duplicateVertexThreshold: CLLocationDistance = 1
    /// MapKit throttles bursts of direction requests. A loop is six or seven legs, so pace
    /// them — a throttled leg comes back empty and punches a hole in the route.
    private let legPacing: Duration = .milliseconds(120)

    /// Builds a loop route anchored at the bus stop nearest to `userLocation`, so the
    /// trip starts and ends at that same stop (point A to point A). If the user isn't
    /// already on the loop, an approach leg from their location to that stop is prepended.
    func calculateRoute(
        waypoints: [CLLocationCoordinate2D],
        userLocation: CLLocationCoordinate2D? = nil,
        busStops: [BusStop] = []
    ) async -> Result {
        let startStop = userLocation.flatMap { nearestBusStop(to: $0, in: busStops) }
        let loopWaypoints = anchoredLoopWaypoints(baseWaypoints: waypoints, anchor: startStop)

        var loopCoordinates: [CLLocationCoordinate2D] = []
        var loopSteps: [DirectionStep] = []

        for i in 0..<max(loopWaypoints.count - 1, 0) {
            if i > 0 { try? await Task.sleep(for: legPacing) }
            let leg = await calculateLeg(from: loopWaypoints[i], to: loopWaypoints[i + 1])
            guard !leg.coordinates.isEmpty else {
                print("Route leg \(i) came back empty; skipping")
                continue
            }

            // Each leg repeats the previous leg's last coordinate, so drop it — but the
            // leg's own index 0 still maps onto that shared vertex, which is where its
            // maneuvers are measured from.
            let legStart = loopCoordinates.isEmpty ? 0 : loopCoordinates.count - 1
            if loopCoordinates.isEmpty {
                loopCoordinates.append(contentsOf: leg.coordinates)
            } else {
                loopCoordinates.append(contentsOf: leg.coordinates.dropFirst())
            }

            loopSteps.append(contentsOf: indexed(leg.steps, along: leg.coordinates, offset: legStart))
        }

        var approachCoordinates: [CLLocationCoordinate2D] = []
        var approachSteps: [DirectionStep] = []

        if let userLocation, let startStop, !isOnLoop(userLocation, loopCoordinates: loopCoordinates) {
            let leg = await approachLeg(from: userLocation, to: startStop.coordinate)
            approachCoordinates = leg.coordinates
            approachSteps = indexed(leg.steps, along: leg.coordinates, offset: 0)
        }

        let offset = approachCoordinates.count
        let combinedSteps = monotonic(approachSteps + loopSteps.map { $0.shifted(by: offset) })

        let route = MapRoute(
            name: "Kuta Beach Road Loop",
            waypoints: loopCoordinates,
            approachWaypoints: approachCoordinates
        )
        return Result(route: route, steps: combinedSteps, startStop: startStop)
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

    /// The approach leg is the rider's only cue for reaching the first stop, so it must
    /// always produce something. Driving directions fail outright in the pedestrian lanes
    /// around Kuta, so fall back to walking, then to a straight line.
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

    /// Distance to the loop *line*, not to its vertices — vertices can sit hundreds of
    /// metres apart on a straight stretch, which used to make a rider standing right on the
    /// road look off-route and trigger a pointless approach leg.
    private func isOnLoop(
        _ location: CLLocationCoordinate2D,
        loopCoordinates: [CLLocationCoordinate2D]
    ) -> Bool {
        guard let progress = RouteGeometry.progress(of: location, along: loopCoordinates) else {
            return false
        }
        return progress.offRouteDistance <= onLoopThreshold
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
