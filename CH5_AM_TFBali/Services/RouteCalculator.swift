import MapKit

actor RouteCalculator {
    static let shared = RouteCalculator()

    struct Result {
        let route: MapRoute
        let steps: [DirectionStep]
    }

    private let onRouteThreshold: CLLocationDistance = 60

    /// Builds the drawn route for a planned trip: ride each leg along its corridor's own road
    /// shape, walk the gap at every transfer, then walk the last stretch to `destination`. If
    /// the user isn't already standing on that path, an approach leg to the first boarding
    /// stop is prepended.
    ///
    /// `legs` comes from `RoutePlanner` via `RouteMapView`, which has already decided which
    /// buses to take and where to change — this only has to draw and narrate that decision.
    /// With no legs at all (nothing in the network reaches the destination) it falls back to
    /// a single direct leg so the rider still gets a line to follow.
    func calculateRoute(
        destination: CLLocationCoordinate2D,
        userLocation: CLLocationCoordinate2D? = nil,
        legs: [PlannedLeg] = []
    ) async -> Result {
        var mainCoordinates: [CLLocationCoordinate2D] = []
        var mainSteps: [DirectionStep] = []

        if !legs.isEmpty {
            let ride = await rideLegs(legs, toward: destination)
            mainCoordinates = ride.coordinates
            mainSteps = ride.steps
        }

        if mainCoordinates.count < 2, let userLocation {
            let leg = await calculateLeg(from: userLocation, to: destination)
            mainCoordinates = leg.coordinates
            mainSteps = indexed(leg.steps, along: leg.coordinates, offset: 0)
        }

        var approachCoordinates: [CLLocationCoordinate2D] = []
        var approachSteps: [DirectionStep] = []

        if let userLocation,
           let boarding = legs.first?.boardStop,
           !isOnRoute(userLocation, routeCoordinates: mainCoordinates) {
            let leg = await approachLeg(from: userLocation, to: boarding.coordinate)
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

    /// Below this gap, the alighting stop is close enough to count as "arrived" — not worth
    /// a whole separate directions request for a handful of metres.
    private let finalMileThreshold: CLLocationDistance = 20

    /// Stitches the planned legs into one drawn path: each leg's ridden road shape, a walked
    /// connector wherever the rider changes buses, and the final walk to the destination.
    ///
    /// Every walked stretch is fetched as real pedestrian directions, so a transfer reads as
    /// "walk 120 m to the other stop" rather than a straight line cutting through buildings.
    private func rideLegs(
        _ legs: [PlannedLeg],
        toward destination: CLLocationCoordinate2D
    ) async -> (coordinates: [CLLocationCoordinate2D], steps: [DirectionStep]) {
        var coordinates: [CLLocationCoordinate2D] = []
        var steps: [DirectionStep] = []

        for (index, leg) in legs.enumerated() {
            guard let board = leg.boardStop, let alight = leg.alightStop else { continue }

            // The change between buses: walk from where the last leg dropped the rider to
            // where the next one picks them up. Skipped when both stops share a platform.
            if index > 0,
               let previousAlight = legs[index - 1].alightStop,
               previousAlight.coordinate.distance(to: board.coordinate) > finalMileThreshold {
                let transfer = await finalMileLeg(from: previousAlight.coordinate, to: board.coordinate)
                steps += indexed(transfer.steps, along: transfer.coordinates, offset: coordinates.count)
                coordinates += transfer.coordinates
            }

            coordinates += riddenShape(of: leg, from: board, to: alight)
        }

        if let lastAlight = legs.last?.alightStop,
           lastAlight.coordinate.distance(to: destination) > finalMileThreshold {
            let lastMile = await finalMileLeg(from: lastAlight.coordinate, to: destination)
            steps += indexed(lastMile.steps, along: lastMile.coordinates, offset: coordinates.count)
            coordinates += lastMile.coordinates
        }

        return (coordinates, steps)
    }

    /// The stretch of a leg's corridor shape actually ridden, board stop through alight stop.
    /// Falls back to a straight line between the two when the shape hasn't loaded yet, or
    /// when the slice comes out backwards — better a rough line than none.
    private func riddenShape(
        of leg: PlannedLeg,
        from board: BusStop,
        to alight: BusStop
    ) -> [CLLocationCoordinate2D] {
        guard leg.polyline.count >= 2 else { return [board.coordinate, alight.coordinate] }

        let startIndex = RouteGeometry.nearestIndex(to: board.coordinate, along: leg.polyline)
        let endIndex = RouteGeometry.nearestIndex(to: alight.coordinate, along: leg.polyline)
        guard startIndex < endIndex else { return [board.coordinate, alight.coordinate] }

        return Array(leg.polyline[startIndex...endIndex])
    }

    /// The walk from the alighting stop to the destination itself — tried on foot first since
    /// that's how a bus rider actually covers this stretch, with the same resilience pattern
    /// as `approachLeg` for wherever walking directions come up empty.
    private func finalMileLeg(
        from source: CLLocationCoordinate2D,
        to destination: CLLocationCoordinate2D
    ) async -> (coordinates: [CLLocationCoordinate2D], steps: [DirectionStep]) {
        for transportType in [MKDirectionsTransportType.walking, .automobile] {
            let leg = await calculateLeg(from: source, to: destination, transportType: transportType)
            if leg.coordinates.count >= 2 { return leg }
        }

        print("Final-mile directions unavailable; drawing a direct line to the destination")
        return (
            coordinates: [source, destination],
            steps: [DirectionStep(
                instruction: "Walk to your destination",
                distance: source.distance(to: destination),
                coordinate: destination
            )]
        )
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
