import MapKit

enum MapConstants {
    static let baliCenter = CLLocationCoordinate2D(latitude: -8.6705, longitude: 115.2126)
    static let defaultSpan = MKCoordinateSpan(latitudeDelta: 0.5, longitudeDelta: 0.5)
    static let kutaCenter = CLLocationCoordinate2D(latitude: -8.7245, longitude: 115.1685)

    /// Fixed trip destination (point B). Static for now — a future version will let the
    /// rider pick this instead of hardcoding it.
    static let pointB = CLLocationCoordinate2D(latitude: -8.78171503569006, longitude: 115.17845175016674)

    static let defaultLocations: [LocationPin] = [
        LocationPin(name: "Bali", coordinate: CLLocationCoordinate2D(latitude: -8.6705, longitude: 115.2126)),
        LocationPin(name: "Ubud", coordinate: CLLocationCoordinate2D(latitude: -8.5069, longitude: 115.2625)),
        LocationPin(name: "Kuta Beach", coordinate: CLLocationCoordinate2D(latitude: -8.7245, longitude: 115.1685))
    ]

    /// Placeholder route shown before a real GPS-anchored route is calculated — a straight
    /// line from the northernmost stop down to point B. Routing itself no longer follows a
    /// declared road shape (`RouteCalculator` asks MKDirections directly), so this exists
    /// purely for the pre-fix map preview.
    static let previewRoute = MapRoute(
        name: "Route Preview",
        waypoints: [
            CLLocationCoordinate2D(latitude: -8.750200427121872, longitude: 115.18193067582983),
            pointB
        ]
    )

    static let landmark = Landmark(
        name: "Route Landmarks",
        coordinates: [
            CLLocationCoordinate2D(latitude: -8.752466453281887, longitude: 115.18159494371356),
            CLLocationCoordinate2D(latitude: -8.758576829337834, longitude: 115.17846187960814),
            CLLocationCoordinate2D(latitude: -8.771010769036952, longitude: 115.17726695436197),
            CLLocationCoordinate2D(latitude: -8.778784513306325, longitude: 115.17808914198463)
        ]
    )

    /// Descriptions for `landmark.coordinates`, in the same order — index 0 is "Landmark 1".
    /// Placeholder copy: real titles/summaries for this area haven't been written yet.
    static let landmarkInfo: [LandmarkInfo] = [
        LandmarkInfo(
            title: "Landmark 1",
            category: "Waypoint",
            summary: "A waypoint near the northern end of the route.",
            icon: "mappin.and.ellipse"
        ),
        LandmarkInfo(
            title: "Landmark 2",
            category: "Waypoint",
            summary: "A waypoint along the route, north of the midpoint.",
            icon: "signpost.right.fill"
        ),
        LandmarkInfo(
            title: "Landmark 3",
            category: "Waypoint",
            summary: "A waypoint along the route, south of the midpoint.",
            icon: "building.2.fill"
        ),
        LandmarkInfo(
            title: "Landmark 4",
            category: "Waypoint",
            summary: "A waypoint near the southern end of the route, close to point B.",
            icon: "flag.checkered"
        )
    ]

    /// Each group below is declared in the order the bus serves it, so the bearing from one
    /// stop to the next is the direction of travel through that stop.
    private static let northboundCoordinates: [CLLocationCoordinate2D] = [
        CLLocationCoordinate2D(latitude: -8.778752715178294, longitude: 115.17746247390953),
        CLLocationCoordinate2D(latitude: -8.77135533913966, longitude: 115.1776067901764),
        CLLocationCoordinate2D(latitude: -8.763402396331813, longitude: 115.17843172222166),
        CLLocationCoordinate2D(latitude: -8.75535039091714, longitude: 115.17975084225267)
    ]

    private static let southboundCoordinates: [CLLocationCoordinate2D] = [
        CLLocationCoordinate2D(latitude: -8.752617589427258, longitude: 115.18127312467522),
        CLLocationCoordinate2D(latitude: -8.75506396807008, longitude: 115.18034780464426),
        CLLocationCoordinate2D(latitude: -8.765620075285431, longitude: 115.17860159289394),
        CLLocationCoordinate2D(latitude: -8.772630414945029, longitude: 115.17801719773689)
    ]

    /// Stops served in both directions — each generates two `BusStop` entries at the same
    /// coordinate, like the northbound/southbound stops but co-located, so `TransitPlanner`
    /// collapses the pair into a single visit the same way it already does for any stop.
    private static let bothwaysCoordinates: [CLLocationCoordinate2D] = [
        CLLocationCoordinate2D(latitude: -8.750200427121872, longitude: 115.18193067582983),
        CLLocationCoordinate2D(latitude: -8.75878578140657, longitude: 115.17935759180737),
        CLLocationCoordinate2D(latitude: -8.781631299463383, longitude: 115.17968474431844)
    ]

    static let busStops: [BusStop] = {
        var stops: [BusStop] = []

        for (index, coordinate) in northboundCoordinates.enumerated() {
            stops.append(BusStop(
                name: "Northbound Stop \(index + 1)",
                coordinate: coordinate,
                corridor: 1,
                direction: .outbound,
                serviceBearing: travelBearing(along: northboundCoordinates, at: index)
            ))
        }

        for (index, coordinate) in southboundCoordinates.enumerated() {
            stops.append(BusStop(
                name: "Southbound Stop \(index + 1)",
                coordinate: coordinate,
                corridor: 1,
                direction: .inbound,
                serviceBearing: travelBearing(along: southboundCoordinates, at: index)
            ))
        }

        for (index, coordinate) in bothwaysCoordinates.enumerated() {
            // Declared north-to-south, so the run of the list is the inbound direction and
            // the outbound service through the same platform is its reverse.
            let inboundBearing = travelBearing(along: bothwaysCoordinates, at: index)

            stops.append(BusStop(
                name: "Bothways Stop \(index + 1)",
                coordinate: coordinate,
                corridor: 1,
                direction: .outbound,
                serviceBearing: (inboundBearing + 180).normalizedCompassHeading
            ))
            stops.append(BusStop(
                name: "Bothways Stop \(index + 1) (Return)",
                coordinate: coordinate,
                corridor: 1,
                direction: .inbound,
                serviceBearing: inboundBearing
            ))
        }

        return stops
    }()

    /// Bearing the bus holds through the stop at `index` — toward the next stop it serves,
    /// or, at the end of the line, continuing the heading it arrived on.
    private static func travelBearing(
        along coordinates: [CLLocationCoordinate2D],
        at index: Int
    ) -> CLLocationDirection {
        guard coordinates.count >= 2 else { return 0 }
        if index + 1 < coordinates.count {
            return coordinates[index].bearing(to: coordinates[index + 1])
        }
        return coordinates[index - 1].bearing(to: coordinates[index])
    }

    /// The stops worth boarding for a trip heading roughly toward `bearing`. Without this
    /// the rider gets sent to whichever platform is physically closest, which half the time
    /// is the one across the road going the other way.
    ///
    /// Falls back to every stop when there is no bearing yet (no GPS fix) or when nothing
    /// matches, so routing never ends up with an empty stop list.
    static func busStops(serving bearing: CLLocationDirection?) -> [BusStop] {
        guard let bearing else { return busStops }
        let serving = busStops.filter { $0.serves(bearing: bearing) }
        return serving.isEmpty ? busStops : serving
    }
}
