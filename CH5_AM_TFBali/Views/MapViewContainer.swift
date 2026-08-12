import SwiftUI
import MapKit

struct MapViewContainer: View {
    @State private var position: MapCameraPosition
    @State private var selectedLocation: LocationPin?

    let locations: [LocationPin]
    let userLocation: CLLocationCoordinate2D?

    init(
        locations: [LocationPin],
        userLocation: CLLocationCoordinate2D? = nil,
        centerCoordinate: CLLocationCoordinate2D? = nil
    ) {
        self.locations = locations
        self.userLocation = userLocation

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
            if let userLoc = userLocation {
                Annotation("You", coordinate: userLoc) {
                    Image(systemName: "location.circle.fill")
                        .font(.title)
                        .foregroundStyle(.blue)
                }
            }

            ForEach(locations) { location in
                Annotation(location.name, coordinate: location.coordinate) {
                    Image(systemName: "mappin.circle.fill")
                        .font(.title)
                        .foregroundStyle(.red)
                }
                .tag(location)
            }
        }
        .mapStyle(.standard)
        .ignoresSafeArea()
    }
}
