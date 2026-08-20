import Foundation
import CoreLocation

/// Reports where a baked corridor polyline disagrees with its stop list, so a corridor can be
/// reviewed without eyeballing the map. Pass a corridor ID to narrow it down:
///
///     /tmp/check CH5_AM_TFBali/Resources/RoutePolylines.json K1
@main
enum CheckPolylines {
    /// Segments checked against the real route with Pafras and confirmed correct, so a rerun
    /// stops reporting them. A corridor is done when its flag count reaches zero.
    static let confirmed: Set<String> = [
        // The bus really does pull into Terminal Ubung, and one gate serves both directions.
        "K1|1|Banjar Tengah Ubung->Terminal UBUNG",
        // Denpasar one-way system; the loop is the actual route.
        "K1|1|Gajah Mada->Hasanudin",
        // Jl. Sudirman is one-way, so the bus rings the block between two stops 120m apart.
        "K2|0|Unud Sudirman 1->Unud Sudirman 2 (Starbucks)",
        "K2|1|Unud Sudirman 1->Unud Sudirman 2 (Starbucks)",
        // Airport: the bus really does loop through the forecourts. The outbound leg still reads
        // 1.91x after its manualOverride, because that loop is the route — only its tail was wrong.
        "K2|0|Terminal Internasional->Terminal Domestik",
        "K2|1|Terminal Domestik->Perum Komplek Burung (Arjuna)",
        // Rings one big block on main roads: east 323m, north 200m, east 236m, south 440m. No
        // small U, no cut-through, stop adds 0m. Assumed correct on the same one-way pattern as
        // the entries above rather than confirmed outright — drop this line if it turns out wrong.
        "K2|1|Teuku Umar (SAS)->Unud Sudirman 1",
        // Reads 2.74x because of the turnaround inside the Dinas Pariwisata grounds, which is the
        // real route and is drawn by manualOverride from Pafras's coordinates.
        "K3|0|Kantor Samsat->Dinas Pariwisata Bali (arah Timur)",
        // K4 checked on the map by Pafras and correct as routed.
        "K4|0|Titi Banda->Tohpati 2 (Ikura Sushi)",
        "K4|1|Titi Banda->Tohpati 2 (Ikura Sushi)",
        "K4|1|Sentral Parkir Monkey Forest->Monkey Forest 1 (Valeria)",
        // Climbs 452m past Sunset Road 3 and comes back down. Pafras thinks the bus really does
        // loop out of Central Parkir this way, but said so tentatively — worth a second look.
        "K5|1|Central Parkir Kuta Luar (Exit Gate)->Sunset Road 3 (Ripcurl)",
        // Dewa Ruci is a stacked interchange; Pafras checked it on the map and the loop is real.
        "K5|2|Dewa Ruci (Mall Bali Galeria)->RS Siloam",
        // K6 runs the same airport stretch as K2 on identical stop coordinates. The first pair
        // carries K2's override (Pafras asked for it); the second is assumed correct on the
        // strength of his K2 answer rather than confirmed for K6 directly.
        "K6|0|Terminal Internasional->Terminal Domestik",
        "K6|1|Terminal Internasional->Terminal Domestik",
        "K6|0|Terminal Domestik->Perum Komplek Burung (Arjuna)",
        "K6|1|Terminal Domestik->Perum Komplek Burung (Arjuna)",
        // 21.66x, the sharpest ratio on the network: the two Dewa Ruci stops sit 42m apart on
        // opposite sides of the road, and the bus turns around after Toms Yamaha to reach the
        // other one. Checked by Pafras.
        "K6|0|Dewa Ruci (Toms Yamaha)->Dewa Ruci (Mall Bali Galeria)",
        // Rest of K6 checked on the map by Pafras and correct as routed.
        "K6|0|Bypass Ngurah Rai 2 (Panasonic)->Perum Komplek Burung",
        "K6|1|Perum Komplek Burung (Arjuna)->Bypass Ngurah Rai 5",
        "K6|1|Sunset Road 2 (Agung Bali)->Abian Base (Indomaret)",
        // Winding hill road up to GWK, plus the small turnaround loop at the terminus that
        // manualOverride draws from Pafras's coordinates.
        "S1|0|Politeknik Negeri Bali (Parking Lot)->Garuda Wisnu Kencana",
    ]

    static func main() {
        let path = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "RoutePolylines.json"
        let filter = CommandLine.arguments.count > 2 ? CommandLine.arguments[2] : nil

        guard let data = FileManager.default.contents(atPath: path),
              let baked = try? JSONDecoder().decode([String: [[Double]]].self, from: data) else {
            print("cannot read \(path)"); return
        }

        for corridor in corridors where filter == nil || corridor.id == filter {
            for (di, direction) in corridor.directions.enumerated() {
                let key = "\(corridor.id)|\(di)"
                guard let raw = baked[key] else { print("\(key): NOT BAKED"); continue }
                let line = raw.map { CLLocationCoordinate2D(latitude: $0[0], longitude: $0[1]) }

                // Each stop snaps to its closest vertex; the stretch between two consecutive
                // snaps is the segment actually drawn for that hop.
                let indices = direction.stops.map { stop in
                    (0..<line.count).min { line[$0].distance(to: stop.coordinate) < line[$1].distance(to: stop.coordinate) }!
                }
                var problems: [String] = []
                var okayed = 0
                var totalRoad: CLLocationDistance = 0

                for j in 0..<(direction.stops.count - 1) {
                    let a = direction.stops[j], b = direction.stops[j + 1]
                    let lo = min(indices[j], indices[j + 1]), hi = max(indices[j], indices[j + 1])
                    let slice = Array(line[lo...hi])
                    let road = zip(slice, slice.dropFirst()).reduce(0.0) { $0 + $1.0.distance(to: $1.1) }
                    let straight = a.coordinate.distance(to: b.coordinate)
                    totalRoad += road
                    let ratio = road / max(straight, 1)
                    let snap = line[indices[j]].distance(to: a.coordinate)

                    var flags: [String] = []
                    if ratio > 1.6 { flags.append(String(format: "DETOUR x%.2f", ratio)) }
                    if snap > 60 { flags.append(String(format: "OFF-LINE %.0fm", snap)) }
                    // A later stop snapping to an earlier vertex means the drawn line doubles back.
                    if indices[j + 1] < indices[j] { flags.append("BACKWARD") }
                    if !flags.isEmpty {
                        if confirmed.contains("\(key)|\(a.name)->\(b.name)") {
                            okayed += 1
                        } else {
                            problems.append("    \(a.name) -> \(b.name): \(Int(road))m vs \(Int(straight))m  \(flags.joined(separator: " "))")
                        }
                    }
                }
                print("\(key) \(direction.stops.count) stops, \(line.count) pts, \(Int(totalRoad / 100) )00m road — \(problems.isEmpty ? "clean" : "\(problems.count) flagged")\(okayed > 0 ? " (\(okayed) confirmed ok)" : "")")
                problems.forEach { print($0) }
            }
        }
    }
}
