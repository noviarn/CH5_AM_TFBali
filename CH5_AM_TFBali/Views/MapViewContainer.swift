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
    let landmark: Landmark?

    init(
        locations: [LocationPin],
        userLocation: CLLocationCoordinate2D? = nil,
        isNavigating: Bool = false,
        navigationHeading: CLLocationDirection? = nil,
        centerCoordinate: CLLocationCoordinate2D? = nil,
        route: MapRoute? = nil,
        landmark: Landmark? = nil
    ) {
        self.locations = locations
        self.userLocation = userLocation
        self.isNavigating = isNavigating
        self.navigationHeading = navigationHeading
        self.centerCoordinate = centerCoordinate
        self.route = route
        self.landmark = landmark

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
        Map(position: $position, selection: $selectedLocation) {
            if let route = route {
                MapPolyline(route.polyline)
                    .stroke(.blue, lineWidth: 3)
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
            updateCamera()
        }
    }

    private func updateCamera(animated: Bool = true) {
        let nextPosition = isNavigating ? navigationCameraPosition() : overviewCameraPosition()

        if animated {
            withAnimation(.easeInOut(duration: 0.6)) {
                position = nextPosition
            }
        } else {
            position = nextPosition
        }
    }

    private func overviewCameraPosition() -> MapCameraPosition {
        if let route {
            let rect = route.polyline.boundingMapRect
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
            distance: 140,
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
