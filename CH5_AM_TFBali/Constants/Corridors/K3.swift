import CoreLocation
import SwiftUI

extension Corridor {
    static let k3 = Corridor(
        id: "K3",
        name: "Terminal Ubung - ICON Mall Sanur (via Dalung)",
        color: Color(red: 0.05, green: 0.15, blue: 0.45),
        headwayMinutes: 22,
        directions: [
            RouteDirection(
                label: "Terminal UBUNG → ICON Mall Sanur",
                stops: [
                    stop("Terminal UBUNG", -8.635028, 115.206202),
                    stop("RS Manuaba", -8.643773, 115.209371),
                    stop("Sutomo", -8.648117, 115.210260),
                    stop("Puri Agung Jrokuta", -8.651789, 115.210918),
                    stop("Gajah Mada", -8.655374, 115.212803),
                    stop("Kantor Walikota Denpasar", -8.655834, 115.216230),
                    stop("Surapati", -8.656227, 115.219035),
                    stop("RSAD Udayana", -8.663585, 115.218231),
                    stop("Simpang Sudirman", -8.669558, 115.218471),
                    stop("Bank Indonesia Renon", -8.668063, 115.221830),
                    stop("Dishub Provinsi Bali", -8.666915, 115.225711),
                    stop("Kantor Samsat", -8.667028, 115.229387),
                    stop("Dinas Pariwisata Bali (arah Timur)", -8.670212, 115.230766),
                    stop("Kantor Gubernur Bali (arah Timur)", -8.669196, 115.234727),
                    stop("Simpang Renon 1 (Dermaster)", -8.673181, 115.239489),
                    stop("Simpang Renon 2 (Renon Plaza)", -8.673415, 115.243973),
                    stop("SD N 2 Sanur (Arah Timur)", -8.674421, 115.254817),
                    stop("Simpang Sanur Hangtuah", -8.674310, 115.259957),
                    stop("Pantai Sindhu 1", -8.681207, 115.259409),
                    stop("ICON Mall Sanur", -8.686875, 115.262701),
                ],
                // Approaching Dinas Pariwisata the bus turns around inside the department's own
                // grounds; the routed path never enters them. The loop is Pafras's coordinates,
                // the run east from Kantor Samsat is the routed path.
                manualOverride: [
                    // Approaching Simpang Renon 1 the routed path jogs north and back before the
                    // stop. Pafras's two points keep it straight along the road; the rest of the
                    // run from Kantor Gubernur was already right.
                    13: [
                            CLLocationCoordinate2D(latitude: -8.669196, longitude: 115.234727),
                            CLLocationCoordinate2D(latitude: -8.669246, longitude: 115.234725),
                            CLLocationCoordinate2D(latitude: -8.669279, longitude: 115.235696),
                            CLLocationCoordinate2D(latitude: -8.669674, longitude: 115.235691),
                            CLLocationCoordinate2D(latitude: -8.670157, longitude: 115.235704),
                            CLLocationCoordinate2D(latitude: -8.670312, longitude: 115.235800),
                            CLLocationCoordinate2D(latitude: -8.670327, longitude: 115.235834),
                            CLLocationCoordinate2D(latitude: -8.670357, longitude: 115.235855),
                            CLLocationCoordinate2D(latitude: -8.670364, longitude: 115.235897),
                            CLLocationCoordinate2D(latitude: -8.670390, longitude: 115.236011),
                            CLLocationCoordinate2D(latitude: -8.670412, longitude: 115.236048),
                            CLLocationCoordinate2D(latitude: -8.670434, longitude: 115.236085),
                            CLLocationCoordinate2D(latitude: -8.670446, longitude: 115.236467),
                            CLLocationCoordinate2D(latitude: -8.670505, longitude: 115.238475),
                            CLLocationCoordinate2D(latitude: -8.670820, longitude: 115.238461),
                            CLLocationCoordinate2D(latitude: -8.671924, longitude: 115.238409),
                            CLLocationCoordinate2D(latitude: -8.673226, longitude: 115.238378),
                            CLLocationCoordinate2D(latitude: -8.673209, longitude: 115.238687),
                            CLLocationCoordinate2D(latitude: -8.673229, longitude: 115.239049),
                            CLLocationCoordinate2D(latitude: -8.673181, longitude: 115.239489)
                    ],
                    11: [
                            CLLocationCoordinate2D(latitude: -8.667028, longitude: 115.229387),
                            CLLocationCoordinate2D(latitude: -8.667056, longitude: 115.229370),
                            CLLocationCoordinate2D(latitude: -8.667139, longitude: 115.231594),
                            CLLocationCoordinate2D(latitude: -8.667174, longitude: 115.232325),
                            CLLocationCoordinate2D(latitude: -8.667194, longitude: 115.232344),
                            CLLocationCoordinate2D(latitude: -8.667323, longitude: 115.232417),
                            CLLocationCoordinate2D(latitude: -8.667466, longitude: 115.232462),
                            CLLocationCoordinate2D(latitude: -8.668114, longitude: 115.232417),
                            CLLocationCoordinate2D(latitude: -8.669003, longitude: 115.232365),
                            CLLocationCoordinate2D(latitude: -8.670294, longitude: 115.232310),
                            CLLocationCoordinate2D(latitude: -8.670292, longitude: 115.232282),
                            CLLocationCoordinate2D(latitude: -8.670234, longitude: 115.230442),
                            CLLocationCoordinate2D(latitude: -8.669836, longitude: 115.230343),
                            CLLocationCoordinate2D(latitude: -8.669536, longitude: 115.230416),
                            CLLocationCoordinate2D(latitude: -8.669805, longitude: 115.230469),
                            CLLocationCoordinate2D(latitude: -8.670063, longitude: 115.230561),
                            CLLocationCoordinate2D(latitude: -8.670174, longitude: 115.230694),
                            CLLocationCoordinate2D(latitude: -8.670212, longitude: 115.230766)
                    ]
                ]
            ),
            RouteDirection(
                label: "ICON Mall Sanur → Terminal UBUNG (via Dalung)",
                stops: [
                    stop("ICON Mall Sanur", -8.686875, 115.262701),
                    stop("Pantai Sindhu 2 (Grandlucky Sanur)", -8.680493, 115.259016),
                    stop("Simpang Sanur HangTuah", -8.674310, 115.259957),
                    stop("SD N 2 Sanur (Arah Barat)", -8.674518, 115.255272),
                    stop("Simpang Renon 3 (Warung Puri Suranadi)", -8.673671, 115.243537),
                    stop("Simpang Renon 4 (SD N 11 Sumerta)", -8.673518, 115.240072),
                    stop("Kantor Gubernur Bali (arah Barat)", -8.669361, 115.234706),
                    stop("Dinas Pariwisata Bali (arah Barat)", -8.670277, 115.230693),
                    stop("Kejaksaan Tinggi Bali", -8.671002, 115.228411),
                    stop("Disdik Bali", -8.671264, 115.221623),
                    stop("Dewi Sartika", -8.669740, 115.217010),
                    stop("Diponegoro 1 (Buccheri)", -8.665718, 115.215458),
                    stop("Diponegoro 2 (Nasi Kuning Hj. Siti Azis)", -8.661744, 115.215033),
                    stop("Hasanudin", -8.658654, 115.213517),
                    stop("Thamrin", -8.656316, 115.210142),
                    stop("Puri Kawan Jrokuta", -8.651324, 115.208780),
                    stop("RS Manuaba (Alfamart)", -8.641566, 115.209016),
                    stop("Simpang Ubung (Aston)", -8.639127, 115.205886),
                    stop("Simpang Gunung Catur (Mitra10)", -8.636478, 115.190635),
                    stop("Gatsu (Danamon)", -8.637195, 115.175488),
                    stop("Pos Pengamanan Terpadu Dalung (Puter Balik)", -8.629848, 115.174779),
                    stop("Gatsu (Deva Store)", -8.637074, 115.175274),
                    stop("Simpang Gunung Catur (Phillips)", -8.636383, 115.190356),
                    stop("Simpang Ubung (Bata)", -8.638939, 115.206611),
                    stop("Terminal UBUNG", -8.635028, 115.206202),
                ]
            ),
        ]
    )
}
