import CoreLocation
import SwiftUI

extension Corridor {
    static let k2 = Corridor(
        id: "K2",
        name: "Terminal Ubung - Bandara I Gusti Ngurah Rai",
        color: Color(red: 0.30, green: 0.60, blue: 0.95),
        headwayMinutes: 20,
        directions: [
            RouteDirection(
                label: "Terminal UBUNG → Bandara I Gusti Ngurah Rai",
                stops: [
                    stop("Terminal UBUNG", -8.635028, 115.206202),
                    stop("Dharma Negara Alaya", -8.637327, 115.212056),
                    stop("Gatsu 1 (Happy Puppy)", -8.635710, 115.218067),
                    stop("Nangka Selatan 1 (Hotel Nuansa Indah)", -8.637590, 115.222728),
                    stop("Nangka Selatan 2 (Gang Sandat)", -8.640183, 115.222207),
                    stop("Nangka Selatan 3 (Kertasari)", -8.644859, 115.219791),
                    stop("Banjar Tansiat", -8.648817, 115.217531),
                    stop("Gor Ngurah Rai Luar", -8.649160, 115.223455),
                    stop("SMA N 7 Denpasar", -8.651201, 115.224534),
                    stop("Melati", -8.654547, 115.222620),
                    stop("Pasar Kreneng", -8.656000, 115.224283),
                    stop("Banjar Kayumas", -8.656579, 115.220744),
                    stop("RSAD Udayana", -8.663585, 115.218231),
                    stop("Unud Sudirman 1", -8.671669, 115.218275),
                    stop("Unud Sudirman 2 (Starbucks)", -8.672713, 115.217947),
                    stop("Dewi Sartika", -8.669740, 115.217010),
                    stop("Teuku Umar 1 (Cicilia Florist)", -8.669519, 115.213174),
                    stop("Teuku Umar 3 (Indoraya)", -8.671964, 115.208908),
                    stop("Teuku Umar 5 (Siantar Ponsel)", -8.675147, 115.207539),
                    stop("Teuku Umar 7 (Amaris Hotel)", -8.680738, 115.202751),
                    stop("Banjar Buagan Selatan (Ubi Cilembu)", -8.684077, 115.195351),
                    stop("Abian Timbul", -8.688022, 115.192387),
                    stop("Simpang Soputan", -8.691075, 115.189915),
                    stop("Pulau Galang (Agung)", -8.694503, 115.187778),
                    stop("Imam Bonjol Kelod 2 (Imam Bonjol Square)", -8.700153, 115.185246),
                    stop("Imam Bonjol Kelod 3 (Dunlop)", -8.703027, 115.184876),
                    stop("Abian Base (Indomaret)", -8.708100, 115.181378),
                    stop("Central Parkir Kuta Luar", -8.713402, 115.181173),
                    stop("Raya Kuta 1 (BCA)", -8.717918, 115.180971),
                    stop("Raya Kuta 2 (SPBU Pertamina)", -8.720887, 115.180042),
                    stop("Camat Kuta", -8.725514, 115.178021),
                    stop("Tuban 1 (Joger)", -8.727256, 115.176915),
                    stop("Tuban 2 (The Keranjang)", -8.731766, 115.177520),
                    stop("Tuban 3 (BMKG)", -8.739166, 115.178483),
                    stop("Tuban 4 (Krisna Wisata Kuliner)", -8.741887, 115.178885),
                    stop("Perum Komplek Burung", -8.743987, 115.172745),
                    stop("Terminal Internasional", -8.741886, 115.166149),
                    stop("Terminal Domestik", -8.742077, 115.164303),
                ],
                // Leaving Gor Ngurah Rai the routed path climbs a block up Jl. Trijata and comes
                // straight back down. The stop is on the kerb of the main road and the bus stays
                // on it, so segment 7 is drawn by hand with that block loop cut out.
                manualOverride: [
                    // Between the airport terminals the routed path runs west past Terminal
                    // Domestik and doubles back. Pafras's points cut straight down to it; the
                    // loop through the forecourts before that is the real route and is kept.
                    36: [
                            CLLocationCoordinate2D(latitude: -8.741935, longitude: 115.166151),
                            CLLocationCoordinate2D(latitude: -8.741952, longitude: 115.165765),
                            CLLocationCoordinate2D(latitude: -8.741925, longitude: 115.165747),
                            CLLocationCoordinate2D(latitude: -8.741837, longitude: 115.165697),
                            CLLocationCoordinate2D(latitude: -8.741660, longitude: 115.165652),
                            CLLocationCoordinate2D(latitude: -8.741533, longitude: 115.165721),
                            CLLocationCoordinate2D(latitude: -8.741194, longitude: 115.165821),
                            CLLocationCoordinate2D(latitude: -8.741117, longitude: 115.165817),
                            CLLocationCoordinate2D(latitude: -8.740963, longitude: 115.165747),
                            CLLocationCoordinate2D(latitude: -8.741022, longitude: 115.165518),
                            CLLocationCoordinate2D(latitude: -8.741209, longitude: 115.165351),
                            CLLocationCoordinate2D(latitude: -8.741292, longitude: 115.165236),
                            CLLocationCoordinate2D(latitude: -8.741319, longitude: 115.165151),
                            CLLocationCoordinate2D(latitude: -8.741331, longitude: 115.164952),
                            CLLocationCoordinate2D(latitude: -8.741385, longitude: 115.164881),
                            CLLocationCoordinate2D(latitude: -8.741582, longitude: 115.164736),
                            CLLocationCoordinate2D(latitude: -8.742028, longitude: 115.164691),
                            CLLocationCoordinate2D(latitude: -8.742073, longitude: 115.164400),
                            CLLocationCoordinate2D(latitude: -8.742077, longitude: 115.164303)
                    ],
                    // Turning off Jl. P.B. Sudirman towards Dewi Sartika, the routed path cuts
                    // through the shop lanes behind Matahari Duta Plaza. The bus stays on the main
                    // road. Nothing shifts it — the stop itself only adds 3m, and forcing the route
                    // further north up Sudirman still cut through — so the turn is Pafras's points.
                    14: [
                            CLLocationCoordinate2D(latitude: -8.672713, longitude: 115.217947),
                            CLLocationCoordinate2D(latitude: -8.671987, longitude: 115.218079),
                            CLLocationCoordinate2D(latitude: -8.670936, longitude: 115.218183),
                            CLLocationCoordinate2D(latitude: -8.670213, longitude: 115.218102),
                            CLLocationCoordinate2D(latitude: -8.669910, longitude: 115.218032),
                            CLLocationCoordinate2D(latitude: -8.669774, longitude: 115.217973),
                            CLLocationCoordinate2D(latitude: -8.669741, longitude: 115.217782),
                            CLLocationCoordinate2D(latitude: -8.669700, longitude: 115.217404),
                            CLLocationCoordinate2D(latitude: -8.669740, longitude: 115.217010)
                    ],
                    // Leaving Terminal Kreneng the bus turns around inside the terminal and comes
                    // out on Jl. Cempaka heading west; the routed path instead escapes south down
                    // Jl. Lely. Apple's map has no usable Cempaka exit — car, walking and four
                    // forced via-points all still went down Lely — so the Cempaka stretch is
                    // Pafras's own coordinates, with the run to Banjar Kayumas routed normally.
                    10: [
                            CLLocationCoordinate2D(latitude: -8.656000, longitude: 115.224283),
                            CLLocationCoordinate2D(latitude: -8.655825, longitude: 115.224086),
                            CLLocationCoordinate2D(latitude: -8.655738, longitude: 115.223513),
                            CLLocationCoordinate2D(latitude: -8.655657, longitude: 115.222854),
                            CLLocationCoordinate2D(latitude: -8.655627, longitude: 115.222486),
                            CLLocationCoordinate2D(latitude: -8.656281, longitude: 115.222310),
                            CLLocationCoordinate2D(latitude: -8.656592, longitude: 115.222242),
                            CLLocationCoordinate2D(latitude: -8.656729, longitude: 115.222226),
                            CLLocationCoordinate2D(latitude: -8.656719, longitude: 115.222139),
                            CLLocationCoordinate2D(latitude: -8.656683, longitude: 115.221798),
                            CLLocationCoordinate2D(latitude: -8.656519, longitude: 115.220753)
                    ],
                    7: [
                            CLLocationCoordinate2D(latitude: -8.649160, longitude: 115.223455),
                            CLLocationCoordinate2D(latitude: -8.649247, longitude: 115.223657),
                            CLLocationCoordinate2D(latitude: -8.649218, longitude: 115.224256),
                            CLLocationCoordinate2D(latitude: -8.649310, longitude: 115.224375),
                            CLLocationCoordinate2D(latitude: -8.649438, longitude: 115.224452),
                            CLLocationCoordinate2D(latitude: -8.651200, longitude: 115.224445)
                    ]
                ]
            ),
            RouteDirection(
                label: "Bandara I Gusti Ngurah Rai → Terminal UBUNG",
                stops: [
                    stop("Terminal Domestik", -8.742077, 115.164303),
                    stop("Perum Komplek Burung (Arjuna)", -8.743816, 115.172422),
                    stop("Tuban 5 (Krisna Oleh-Oleh)", -8.742390, 115.178876),
                    stop("Tuban 6 (Yonif 741 Barat)", -8.739862, 115.178524),
                    stop("Tuban 7 (Bandung Collection)", -8.731547, 115.177411),
                    stop("Raya Kuta 3 (BPD Kuta)", -8.724110, 115.176659),
                    stop("Raya Kuta 4 (Alfamart)", -8.719895, 115.180241),
                    stop("Raya Kuta 5 (Indobat)", -8.717300, 115.181009),
                    stop("Central Parkir Kuta Luar (Exit Gate)", -8.712697, 115.181087),
                    stop("Abian Base (Balenong)", -8.708141, 115.181280),
                    stop("Imam Bonjol Kelod (TSM)", -8.702626, 115.184702),
                    stop("Pulau Galang (Cat)", -8.696691, 115.186157),
                    stop("Simpang Soputan (Sinar)", -8.692240, 115.188700),
                    stop("Abian Timbul (Nadi)", -8.687161, 115.192894),
                    stop("Teuku Umar (Rodalink)", -8.680398, 115.203137),
                    stop("Teuku Umar (Electronic)", -8.674776, 115.207535),
                    stop("Teuku Umar (Erafone)", -8.671717, 115.208970),
                    stop("Teuku Umar (SAS)", -8.669304, 115.212566),
                    stop("Unud Sudirman 1", -8.671669, 115.218275),
                    stop("Unud Sudirman 2 (Starbucks)", -8.672713, 115.217947),
                    stop("Dewi Sartika", -8.669740, 115.217010),
                    stop("Diponegoro 1 (Buccheri)", -8.665718, 115.215458),
                    stop("Diponegoro 2 (Nasi Kuning Hj. Siti Azis)", -8.661744, 115.215033),
                    stop("Inna Bali Heritage", -8.654883, 115.216979),
                    stop("Pasar Satria", -8.649974, 115.217382),
                    stop("GOR Ngurah Rai Luar", -8.649160, 115.223455),
                    stop("SMAN 7 Denpasar", -8.651201, 115.224534),
                    stop("Melati", -8.654547, 115.222620),
                    stop("Banjar Kayumas", -8.656579, 115.220744),
                    stop("Bali Post (Kepundung)", -8.649795, 115.220842),
                    stop("Suli 1", -8.648656, 115.223031),
                    stop("Suli 2 (Notaris)", -8.642062, 115.224282),
                    stop("Gatsu 1 (Maybank Finance)", -8.635869, 115.217917),
                    stop("SMP N 10 Denpasar", -8.637038, 115.213416),
                    stop("Terminal UBUNG", -8.635028, 115.206202),
                ],
                // Same fix as the outbound leg's segment 7: Jl. Trijata is one-way, so both
                // directions serve the identical Gor Ngurah Rai Luar stop and ride the identical
                // stretch of road, block loop and all.
                manualOverride: [
                    // Same Dewi Sartika turn as the outbound leg, identical stop coordinates.
                    19: [
                            CLLocationCoordinate2D(latitude: -8.672713, longitude: 115.217947),
                            CLLocationCoordinate2D(latitude: -8.671987, longitude: 115.218079),
                            CLLocationCoordinate2D(latitude: -8.670936, longitude: 115.218183),
                            CLLocationCoordinate2D(latitude: -8.670213, longitude: 115.218102),
                            CLLocationCoordinate2D(latitude: -8.669910, longitude: 115.218032),
                            CLLocationCoordinate2D(latitude: -8.669774, longitude: 115.217973),
                            CLLocationCoordinate2D(latitude: -8.669741, longitude: 115.217782),
                            CLLocationCoordinate2D(latitude: -8.669700, longitude: 115.217404),
                            CLLocationCoordinate2D(latitude: -8.669740, longitude: 115.217010)
                    ],
                    // Heading for Gatsu 1 the routed path turns west about 100m too early, off the
                    // main road. Pafras's points carry it further north to the proper turn; the
                    // climb up from Suli 2 and the run along Gatot Subroto were already right.
                    31: [
                            CLLocationCoordinate2D(latitude: -8.642064, longitude: 115.224288),
                            CLLocationCoordinate2D(latitude: -8.641692, longitude: 115.224416),
                            CLLocationCoordinate2D(latitude: -8.641412, longitude: 115.224498),
                            CLLocationCoordinate2D(latitude: -8.641261, longitude: 115.224526),
                            CLLocationCoordinate2D(latitude: -8.640233, longitude: 115.224665),
                            CLLocationCoordinate2D(latitude: -8.639071, longitude: 115.224870),
                            CLLocationCoordinate2D(latitude: -8.638283, longitude: 115.224994),
                            CLLocationCoordinate2D(latitude: -8.637019, longitude: 115.225167),
                            CLLocationCoordinate2D(latitude: -8.636644, longitude: 115.225202),
                            CLLocationCoordinate2D(latitude: -8.636530, longitude: 115.225198),
                            CLLocationCoordinate2D(latitude: -8.635575, longitude: 115.225165),
                            CLLocationCoordinate2D(latitude: -8.635494, longitude: 115.223798),
                            CLLocationCoordinate2D(latitude: -8.635526, longitude: 115.223399),
                            CLLocationCoordinate2D(latitude: -8.635571, longitude: 115.223149),
                            CLLocationCoordinate2D(latitude: -8.635622, longitude: 115.223139),
                            CLLocationCoordinate2D(latitude: -8.635662, longitude: 115.223105),
                            CLLocationCoordinate2D(latitude: -8.635688, longitude: 115.223038),
                            CLLocationCoordinate2D(latitude: -8.635684, longitude: 115.223007),
                            CLLocationCoordinate2D(latitude: -8.635643, longitude: 115.222956),
                            CLLocationCoordinate2D(latitude: -8.635581, longitude: 115.222939),
                            CLLocationCoordinate2D(latitude: -8.635599, longitude: 115.222857),
                            CLLocationCoordinate2D(latitude: -8.635651, longitude: 115.222553),
                            CLLocationCoordinate2D(latitude: -8.635761, longitude: 115.221652),
                            CLLocationCoordinate2D(latitude: -8.635779, longitude: 115.221322),
                            CLLocationCoordinate2D(latitude: -8.635770, longitude: 115.218338),
                            CLLocationCoordinate2D(latitude: -8.635784, longitude: 115.218129),
                            CLLocationCoordinate2D(latitude: -8.635867, longitude: 115.218108),
                            CLLocationCoordinate2D(latitude: -8.635899, longitude: 115.218073),
                            CLLocationCoordinate2D(latitude: -8.635921, longitude: 115.217923)
                    ],
                    25: [
                            CLLocationCoordinate2D(latitude: -8.649160, longitude: 115.223455),
                            CLLocationCoordinate2D(latitude: -8.649247, longitude: 115.223657),
                            CLLocationCoordinate2D(latitude: -8.649218, longitude: 115.224256),
                            CLLocationCoordinate2D(latitude: -8.649310, longitude: 115.224375),
                            CLLocationCoordinate2D(latitude: -8.649438, longitude: 115.224452),
                            CLLocationCoordinate2D(latitude: -8.651200, longitude: 115.224445)
                    ]
                ]
            ),
        ]
    )
}
