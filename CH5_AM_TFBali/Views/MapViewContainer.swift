import SwiftUI
import MapKit

struct MapViewContainer: View {
    @State private var position: MapCameraPosition
    @State private var selectedLocation: LocationPin?

    let locations: [LocationPin]
    let userLocation: CLLocationCoordinate2D?
    let route: MapRoute?
    let landmark: Landmark?

    init(
        locations: [LocationPin],
        userLocation: CLLocationCoordinate2D? = nil,
        centerCoordinate: CLLocationCoordinate2D? = nil,
        route: MapRoute? = nil,
        landmark: Landmark? = nil
    ) {
        self.locations = locations
        self.userLocation = userLocation
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
    }
}
