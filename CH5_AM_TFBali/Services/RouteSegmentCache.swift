import Foundation
import CoreLocation

/// Persists fetched stop-to-stop road segments to disk, keyed by the coordinate pair itself
/// rather than which corridor/leg they came from — so re-opening the map, toggling a corridor
/// off and back on, or a later app launch doesn't refetch a segment MapKit has already
/// resolved. A physical stop-to-stop road shape doesn't change between app launches.
///
/// Caching per segment rather than per whole leg matters: a 40-stop leg only needs a single
/// segment to hit the directions rate limit for the *entire leg* to previously never get
/// cached at all (every attempt had at least one fallback somewhere). Per-segment caching
/// saves whatever succeeds immediately, so a leg fills in — and stops needing network calls
/// for the parts it already has — incrementally across attempts instead of needing one
/// flawless all-or-nothing run.
actor RouteSegmentCache {
    static let shared = RouteSegmentCache()

    private struct Coordinate: Codable {
        let latitude: Double
        let longitude: Double
    }

    private let fileURL: URL = {
        let directory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        return directory.appendingPathComponent("CorridorPolylines.json")
    }()

    private var entries: [String: [CLLocationCoordinate2D]]?

    static func key(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> String {
        // 6 decimal places is ~0.1 m precision — plenty to identify "this exact stop pair"
        // while keeping the key stable against float formatting noise.
        String(format: "%.6f,%.6f-%.6f,%.6f", from.latitude, from.longitude, to.latitude, to.longitude)
    }

    func coordinates(for key: String) async -> [CLLocationCoordinate2D]? {
        await loadIfNeeded()[key]
    }

    func store(key: String, coordinates: [CLLocationCoordinate2D]) async {
        var current = await loadIfNeeded()
        current[key] = coordinates
        entries = current
        persist(current)
    }

    private func loadIfNeeded() async -> [String: [CLLocationCoordinate2D]] {
        if let entries { return entries }

        // Shipped baseline — real road shapes captured once and committed to the repo, so a
        // fresh install already has them with zero MapKit calls. Anything fetched live during
        // this install (below) overrides it, since a re-fetch is just as valid and may be
        // newer than whatever was last committed to the bundled seed.
        var result = Self.decode(Bundle.main.url(forResource: "CorridorPolylines", withExtension: "json"))
        result.merge(Self.decode(fileURL)) { _, fresh in fresh }

        entries = result
        return result
    }

    private static func decode(_ url: URL?) -> [String: [CLLocationCoordinate2D]] {
        guard
            let url,
            let data = try? Data(contentsOf: url),
            let decoded = try? JSONDecoder().decode([String: [Coordinate]].self, from: data)
        else {
            return [:]
        }
        return decoded.mapValues { $0.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) } }
    }

    private func persist(_ entries: [String: [CLLocationCoordinate2D]]) {
        let encodable = entries.mapValues { $0.map { Coordinate(latitude: $0.latitude, longitude: $0.longitude) } }
        guard let data = try? JSONEncoder().encode(encodable) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
