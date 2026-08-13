import SwiftUI
import MapKit

struct MapViewContainer: View {
    @State private var position: MapCameraPosition
    @State private var selectedLocation: LocationPin?
    @State private var lastCameraUpdate: Date = .distantPast

    let locations: [LocationPin]
    let userLocation: CLLocationCoordinate2D?
    let isNavigating: Bool
    let navigationHeading: CLLocationDirection?
    let centerCoordinate: CLLocationCoordinate2D?
    let route: MapRoute?
    let landmark: Landmark?
    let busStops: [BusStop]

    init(
        locations: [LocationPin],
        userLocation: CLLocationCoordinate2D? = nil,
        isNavigating: Bool = false,
        navigationHeading: CLLocationDirection? = nil,
        centerCoordinate: CLLocationCoordinate2D? = nil,
        route: MapRoute? = nil,
        landmark: Landmark? = nil,
        busStops: [BusStop] = []
    ) {
        self.locations = locations
        self.userLocation = userLocation
        self.isNavigating = isNavigating
        self.navigationHeading = navigationHeading
        self.centerCoordinate = centerCoordinate
        self.route = route
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
            if let route = route {
                let remainingApproach = remainingCoordinates(route.approachWaypoints)
                if remainingApproach.count >= 2 {
                    MapPolyline(MKPolyline(coordinates: remainingApproach, count: remainingApproach.count))
                        .stroke(.blue, style: StrokeStyle(lineWidth: 1.5, lineCap: .round, dash: [10, 8]))
                }

                let remainingLoop = remainingCoordinates(route.waypoints)
                if remainingLoop.count >= 2 {
                    MapPolyline(MKPolyline(coordinates: remainingLoop, count: remainingLoop.count))
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
        .onChange(of: cameraState) { _, _ in
            scheduleCameraUpdate()
        }
    }

    private static let cameraUpdateInterval: TimeInterval = 0.4
    private static let routeSnapThreshold: CLLocationDistance = 150

    /// Trims a route's coordinates down to what's still ahead of the user, so the
    /// drawn line retreats behind them as they progress — like Google Maps nav.
    private func remainingCoordinates(_ coordinates: [CLLocationCoordinate2D]) -> [CLLocationCoordinate2D] {
        guard isNavigating, let userLocation, coordinates.count > 1 else { return coordinates }

        let nearestIndex = coordinates.indices.min {
            userLocation.distance(to: coordinates[$0]) < userLocation.distance(to: coordinates[$1])
        } ?? 0

        guard userLocation.distance(to: coordinates[nearestIndex]) <= Self.routeSnapThreshold else {
            return coordinates
        }

        return Array(coordinates[nearestIndex...])
    }

    private func scheduleCameraUpdate() {
        let now = Date()
        guard now.timeIntervalSince(lastCameraUpdate) >= Self.cameraUpdateInterval else { return }
        lastCameraUpdate = now
        updateCamera()
    }

    private func updateCamera(animated: Bool = true) {
        let nextPosition = isNavigating ? navigationCameraPosition() : overviewCameraPosition()

        if animated {
            withAnimation(.linear(duration: Self.cameraUpdateInterval)) {
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
