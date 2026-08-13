import SwiftUI
import MapKit

struct MapViewContainer: View {
    @State private var position: MapCameraPosition
    @State private var selectedLocation: LocationPin?

    let locations: [LocationPin]
    let userLocation: CLLocationCoordinate2D?
    let isNavigating: Bool
    let navigationHeading: CLLocationDirection?
    let centerCoordinate: CLLocationCoordinate2D?
    let route: MapRoute?
    /// Progress along `route.combinedWaypoints`, computed once by the owner so the drawn
    /// line, the maneuver list and the checkpoints all agree on where the rider is.
    let routeProgress: RouteProgress?
    let landmark: Landmark?
    let busStops: [BusStop]

    init(
        locations: [LocationPin],
        userLocation: CLLocationCoordinate2D? = nil,
        isNavigating: Bool = false,
        navigationHeading: CLLocationDirection? = nil,
        centerCoordinate: CLLocationCoordinate2D? = nil,
        route: MapRoute? = nil,
        routeProgress: RouteProgress? = nil,
        landmark: Landmark? = nil,
        busStops: [BusStop] = []
    ) {
        self.locations = locations
        self.userLocation = userLocation
        self.isNavigating = isNavigating
        self.navigationHeading = navigationHeading
        self.centerCoordinate = centerCoordinate
        self.route = route
        self.routeProgress = routeProgress
        self.landmark = landmark
        self.busStops = busStops

        let center = userLocation ?? centerCoordinate ?? MapConstants.baliCenter
        _position = State(initialValue: .region(
            MKCoordinateRegion(
                center: center,
                span: MapConstants.defaultSpan
            )
        ))
    }

    private var cameraState: NavigationCameraState {
        NavigationCameraState(
            latitude: userLocation?.latitude,
            longitude: userLocation?.longitude,
            heading: navigationHeading,
            isNavigating: isNavigating
        )
    }

    var body: some View {
        Map(position: $position, interactionModes: isNavigating ? [] : .all, selection: $selectedLocation) {
            if let route {
                let remaining = remainingLegs(of: route)

                if remaining.approach.count >= 2 {
                    MapPolyline(MKPolyline(coordinates: remaining.approach, count: remaining.approach.count))
                        .stroke(.blue, style: StrokeStyle(lineWidth: 4, lineCap: .round, dash: [10, 8]))
                }

                if remaining.loop.count >= 2 {
                    MapPolyline(MKPolyline(coordinates: remaining.loop, count: remaining.loop.count))
                        .stroke(.blue, lineWidth: 3)
                }
            }

            if let landmark = landmark {
                ForEach(Array(landmark.coordinates.enumerated()), id: \.offset) { index, coord in
                    Annotation("Landmark \(index + 1)", coordinate: coord) {
                        Image(systemName: "mappin.circle.fill")
                            .font(.title)
                            .foregroundStyle(.red)
                    }
                }
            }

            ForEach(busStops) { stop in
                Annotation(stop.name, coordinate: stop.coordinate) {
                    Image(systemName: "bus.fill")
                        .font(.caption)
                        .foregroundStyle(.white)
                        .padding(6)
                        .background(stop.direction == .outbound ? Color.green : Color.orange, in: Circle())
                }
            }

            if let userLoc = userLocation {
                Annotation("You", coordinate: userLoc) {
                    Image(systemName: "location.circle.fill")
                        .font(.title)
                        .foregroundStyle(.blue)
                }
            }
        }
        .mapStyle(.standard)
        .ignoresSafeArea()
        .onAppear {
            updateCamera(animated: false)
        }
        .onChange(of: cameraState) { previous, current in
            // Outside navigation the camera frames the whole route; re-running it on every
            // GPS tick would fight the user panning around. Only follow while navigating,
            // plus once when the mode flips.
            guard current.isNavigating || previous.isNavigating != current.isNavigating else { return }
            updateCamera()
        }
        .onChange(of: route?.id) { _, _ in
            updateCamera(animated: false)
        }
    }

    /// Matched to the ~1 Hz location stream. Each fix glides to the next instead of the
    /// camera sitting still and then jumping, which is what read as teleporting. The old
    /// code also *discarded* any fix arriving inside its throttle window rather than
    /// deferring it, so bursts of movement were dropped outright.
    private static let cameraAnimationDuration: TimeInterval = 1.1

    /// Splits the combined-path progress back into the two drawn legs, trimming each to
    /// what is still ahead so the line retreats behind the rider — like Google Maps nav.
    private func remainingLegs(
        of route: MapRoute
    ) -> (approach: [CLLocationCoordinate2D], loop: [CLLocationCoordinate2D]) {
        guard isNavigating, let routeProgress else {
            return (route.approachWaypoints, route.waypoints)
        }

        let approachCount = route.approachWaypoints.count
        let segment = routeProgress.index

        if segment + 1 < approachCount {
            return (
                approach: RouteGeometry.remaining(
                    route.approachWaypoints,
                    fromSegment: segment,
                    projected: routeProgress.projected
                ),
                loop: route.waypoints
            )
        }

        // Past the join, so the approach is done. Clamp for the shared segment that
        // straddles both legs.
        let loopSegment = max(segment - approachCount, 0)
        return (
            approach: [],
            loop: RouteGeometry.remaining(
                route.waypoints,
                fromSegment: loopSegment,
                projected: routeProgress.projected
            )
        )
    }

    private func updateCamera(animated: Bool = true) {
        let nextPosition = isNavigating ? navigationCameraPosition() : overviewCameraPosition()

        if animated {
            withAnimation(.linear(duration: Self.cameraAnimationDuration)) {
                position = nextPosition
            }
        } else {
            position = nextPosition
        }
    }

    private func overviewCameraPosition() -> MapCameraPosition {
        if let route {
            var rect = route.polyline.boundingMapRect
            if let approachRect = route.approachPolyline?.boundingMapRect, !approachRect.isNull {
                rect = rect.union(approachRect)
            }
            if !rect.isNull && !rect.isEmpty {
                var region = MKCoordinateRegion(rect)
                region.span.latitudeDelta = max(region.span.latitudeDelta * 1.8, 0.01)
                region.span.longitudeDelta = max(region.span.longitudeDelta * 1.8, 0.01)
                return .region(region)
            }
        }

        let center = userLocation ?? centerCoordinate ?? MapConstants.baliCenter
        return .region(
            MKCoordinateRegion(
                center: center,
                span: MapConstants.defaultSpan
            )
        )
    }

    private func navigationCameraPosition() -> MapCameraPosition {
        guard let userLocation else {
            return overviewCameraPosition()
        }

        let heading = navigationHeading ?? 0
        let center = coordinate(
            from: userLocation,
            distance: 90,
            heading: heading
        )

        let camera = MapCamera(
            centerCoordinate: center,
            distance: 550,
            heading: heading,
            pitch: 65
        )

        return .camera(camera)
    }

    private func coordinate(
        from coordinate: CLLocationCoordinate2D,
        distance: CLLocationDistance,
        heading: CLLocationDirection
    ) -> CLLocationCoordinate2D {
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let destination = location.distance(
            from: distance,
            bearingDegrees: heading
        )
        return destination.coordinate
    }
}

private struct NavigationCameraState: Equatable {
    let latitude: CLLocationDegrees?
    let longitude: CLLocationDegrees?
    let heading: CLLocationDirection?
    let isNavigating: Bool
}

private extension CLLocation {
    func distance(
        from meters: CLLocationDistance,
        bearingDegrees: CLLocationDirection
    ) -> CLLocation {
        let earthRadius = 6_371_000.0
        let angularDistance = meters / earthRadius
        let bearing = bearingDegrees * .pi / 180

        let latitudeRadians = coordinate.latitude * .pi / 180
        let longitudeRadians = coordinate.longitude * .pi / 180

        let destinationLatitude = asin(
            sin(latitudeRadians) * cos(angularDistance) +
            cos(latitudeRadians) * sin(angularDistance) * cos(bearing)
        )

        let destinationLongitude = longitudeRadians + atan2(
            sin(bearing) * sin(angularDistance) * cos(latitudeRadians),
            cos(angularDistance) - sin(latitudeRadians) * sin(destinationLatitude)
        )

        return CLLocation(
            latitude: destinationLatitude * 180 / .pi,
            longitude: destinationLongitude * 180 / .pi
        )
    }
}
