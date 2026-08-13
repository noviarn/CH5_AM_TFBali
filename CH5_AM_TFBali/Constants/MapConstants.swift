import MapKit

enum MapConstants {
    static let baliCenter = CLLocationCoordinate2D(latitude: -8.6705, longitude: 115.2126)
    static let defaultSpan = MKCoordinateSpan(latitudeDelta: 0.5, longitudeDelta: 0.5)
    static let kutaCenter = CLLocationCoordinate2D(latitude: -8.7245, longitude: 115.1685)

    static let defaultLocations: [LocationPin] = [
        LocationPin(name: "Bali", coordinate: CLLocationCoordinate2D(latitude: -8.6705, longitude: 115.2126)),
        LocationPin(name: "Ubud", coordinate: CLLocationCoordinate2D(latitude: -8.5069, longitude: 115.2625)),
        LocationPin(name: "Kuta Beach", coordinate: CLLocationCoordinate2D(latitude: -8.7245, longitude: 115.1685))
    ]

    static let kutaLoop = MapRoute(
        name: "Kuta Beach Road Loop",
        waypoints: [
            CLLocationCoordinate2D(latitude: -8.737353, longitude: 115.178169),
            CLLocationCoordinate2D(latitude: -8.737139, longitude: 115.167211),
            CLLocationCoordinate2D(latitude: -8.724389, longitude: 115.171382),
            CLLocationCoordinate2D(latitude: -8.722369, longitude: 115.175475),
            CLLocationCoordinate2D(latitude: -8.722261, longitude: 115.178039),
            CLLocationCoordinate2D(latitude: -8.737353, longitude: 115.178169)
        ]
    )

    static let landmark = Landmark(
        name: "Kuta Area",
        coordinates: [
            CLLocationCoordinate2D(latitude: -8.736593, longitude: 115.175892),
            CLLocationCoordinate2D(latitude: -8.72485576604497, longitude: 115.1709782833711),
            CLLocationCoordinate2D(latitude: -8.7319995038954, longitude: 115.17777043948983)
        ]
    )

    private static let corridor1Coordinates: [CLLocationCoordinate2D] = [
        CLLocationCoordinate2D(latitude: -8.736693612846508, longitude: 115.17815971746676),
        CLLocationCoordinate2D(latitude: -8.734891290829545, longitude: 115.17772530258006),
        CLLocationCoordinate2D(latitude: -8.731792995175487, longitude: 115.17755401080507),
        CLLocationCoordinate2D(latitude: -8.73076260795831, longitude: 115.17723908814422),
        CLLocationCoordinate2D(latitude: -8.727247185938467, longitude: 115.1769483812108),
        CLLocationCoordinate2D(latitude: -8.724335240181466, longitude: 115.1765160108156)
    ]

    private static let corridor2Coordinates: [CLLocationCoordinate2D] = [
        CLLocationCoordinate2D(latitude: -8.737361901472998, longitude: 115.1772004362772),
        CLLocationCoordinate2D(latitude: -8.73841754681739, longitude: 115.17098936475115),
        CLLocationCoordinate2D(latitude: -8.73668486294509, longitude: 115.16733697975403),
        CLLocationCoordinate2D(latitude: -8.733750689193386, longitude: 115.16715623426828),
        CLLocationCoordinate2D(latitude: -8.731918220688186, longitude: 115.16760535935684),
        CLLocationCoordinate2D(latitude: -8.729100574888484, longitude: 115.1686712582908),
        CLLocationCoordinate2D(latitude: -8.725355291464641, longitude: 115.17090121621256),
        CLLocationCoordinate2D(latitude: -8.723764553714153, longitude: 115.17367695767139),
        CLLocationCoordinate2D(latitude: -8.723557820653257, longitude: 115.17518454832774),
        CLLocationCoordinate2D(latitude: -8.722134095706753, longitude: 115.17804581710871)
    ]

    // Randomized selection of stops that serve both directions.
    private static let corridor1TwoWayIndices: Set<Int> = [1, 4]
    private static let corridor2TwoWayIndices: Set<Int> = [0, 3, 6, 8]

    static let busStops: [BusStop] = {
        var stops: [BusStop] = []

        for (index, coordinate) in corridor1Coordinates.enumerated() {
            stops.append(BusStop(
                name: "Corridor 1 Stop \(index + 1)",
                coordinate: coordinate,
                corridor: 1,
                direction: .outbound
            ))
            if corridor1TwoWayIndices.contains(index) {
                stops.append(BusStop(
                    name: "Corridor 1 Stop \(index + 1) (Return)",
                    coordinate: coordinate,
                    corridor: 1,
                    direction: .inbound
                ))
            }
        }

        for (index, coordinate) in corridor2Coordinates.enumerated() {
            stops.append(BusStop(
                name: "Corridor 2 Stop \(index + 1)",
                coordinate: coordinate,
                corridor: 2,
                direction: .outbound
            ))
            if corridor2TwoWayIndices.contains(index) {
                stops.append(BusStop(
                    name: "Corridor 2 Stop \(index + 1) (Return)",
                    coordinate: coordinate,
                    corridor: 2,
                    direction: .inbound
                ))
            }
        }

        return stops
    }()
}
