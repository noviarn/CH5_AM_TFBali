let corridors: [Corridor] = [
    .k1, .k2, .k3, .k4, .k5, .k6, .s1, .shuttleSanur,
]

#if DEBUG
enum CorridorDataCheck {
    static func run() {
        var seenIDs: Set<String> = []
        for corridor in corridors {
            assert(!seenIDs.contains(corridor.id), "duplicate corridor id: \(corridor.id)")
            seenIDs.insert(corridor.id)
            assert(!corridor.directions.isEmpty, "\(corridor.id) has no directions")
            for direction in corridor.directions {
                assert(direction.stops.count >= 2, "\(corridor.id) / \(direction.label) has fewer than 2 stops")
            }
            let counts = corridor.directions.map { $0.stops.count }
            print("🚌 \(corridor.id): \(counts) stops per leg — cross-check against source notes")
        }
        print("✅ CorridorDataCheck.run passed — \(corridors.count) corridors, no duplicates, no empty legs")
    }
}
#endif
