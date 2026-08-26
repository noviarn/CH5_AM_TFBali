import CoreLocation
import SwiftUI

extension Corridor {
    static let k6 = Corridor(
        id: "K6",
        name: "Central Parkir Kuta - ITDC Nusa Dua",
        color: .routeK6B,
        headwayMinutes: 22,
        directions: [
            RouteDirection(
                label: "Central Parkir Kuta → ITDC Nusa Dua",
                stops: [
                    stop("Central Parkir Kuta", -8.713076, 115.180797),
                    stop("Abian Base", -8.708164, 115.181307),
                    stop("Agung Bali", -8.706850, 115.183263),
                    stop("Sunset Road 3 (Ripcord)", -8.710012, 115.185064),
                    stop("Sunset Road 5", -8.712022, 115.186163),
                    stop("RS Siloam (Ma Gung Hwa)", -8.714486, 115.186367),
                    stop("Dewa Ruci (Toms Yamaha)", -8.721572, 115.185975),
                    stop("Dewa Ruci (Mall Bali Galeria)", -8.721794, 115.185656),
                    stop("Bypass Ngurah Rai 1 (Patasari)", -8.730487, 115.178965),
                    stop("Bypass Ngurah Rai 2 (Panasonic)", -8.738657, 115.180169),
                    stop("Perum Komplek Burung", -8.743987, 115.172745),
                    stop("Terminal Internasional", -8.741886, 115.166149),
                    stop("Terminal Domestik", -8.742077, 115.164303),
                    stop("Perum Komplek Burung (Arjuna)", -8.743816, 115.172422),
                    stop("Kelan (Daihatsu)", -8.750241, 115.182171),
                    stop("Bypass Ngurah Rai 3 (Benoa Square)", -8.761498, 115.178943),
                    stop("Jimbaran 1 (AION Jimbaran)", -8.767520, 115.178296),
                    stop("Jimbaran 2 (Money Changer)", -8.772332, 115.177934),
                    stop("Taman Griya 1 (Coco)", -8.782265, 115.180821),
                    stop("Taman Griya 2 (Pyramid)", -8.783864, 115.188458),
                    stop("Coco Mart Mumbul", -8.784895, 115.194651),
                    stop("Mumbul", -8.785814, 115.202947),
                    stop("Graha Socio (Galago)", -8.788489, 115.209167),
                    stop("Bualu (Mufidah)", -8.792554, 115.214836),
                    stop("Gardu PLN Nusa Dua", -8.797804, 115.221849),
                    stop("ITDC Selatan (Novotel)", -8.807654, 115.226650),
                    stop("ITDC Central Parking", -8.801580, 115.228485),
                ],
                // Same airport run as K2: the routed path overshoots west past Terminal Domestik
                // and doubles back. Identical stop coordinates, so this is K2's override verbatim.
                manualOverride: [
                    11: [
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
                    ]
                ]
            ),
            RouteDirection(
                label: "ITDC Nusa Dua → Central Parkir Kuta",
                stops: [
                    stop("ITDC Central Parking", -8.801580, 115.228485),
                    stop("BNDCC", -8.795539, 115.227213),
                    stop("ITDC Utara (Grand Whiz)", -8.791700, 115.227211),
                    stop("Pratama Nusa Dua", -8.789725, 115.223739),
                    stop("Bualu", -8.792710, 115.214751),
                    stop("Graha Socio (Hotel)", -8.788538, 115.208949),
                    stop("Mumbul (SMK Nusa Dua Pariwisata)", -8.786146, 115.203317),
                    stop("Coco Mart Mumbul (Taman Mumbul)", -8.785116, 115.194333),
                    stop("Taman Griya 3", -8.784085, 115.187505),
                    stop("Taman Griya 4", -8.782305, 115.180389),
                    stop("Jimbaran 3 (Red Dragon)", -8.771481, 115.177787),
                    stop("Jimbaran 4 (Barbershop)", -8.768029, 115.178069),
                    stop("Bypass Ngurah Rai 4 (Carwash)", -8.763665, 115.178533),
                    stop("Kelan (Pura Desa Kelan)", -8.750036, 115.182059),
                    stop("Perum Komplek Burung", -8.743987, 115.172745),
                    stop("Terminal Internasional", -8.741886, 115.166149),
                    stop("Terminal Domestik", -8.742077, 115.164303),
                    stop("Perum Komplek Burung (Arjuna)", -8.743816, 115.172422),
                    stop("Bypass Ngurah Rai 5", -8.738218, 115.179899),
                    stop("Bypass Ngurah Rai 6 (Melawai)", -8.730649, 115.178701),
                    stop("Setiabudi", -8.721216, 115.182291),
                    stop("RS Siloam", -8.715496, 115.185675),
                    stop("Sunset Road 4 (Sosro)", -8.710325, 115.184968),
                    stop("Sunset Road 2 (Agung Bali)", -8.707000, 115.182999),
                    stop("Abian Base (Indomaret)", -8.708118, 115.181374),
                    stop("Central Parkir Kuta", -8.713076, 115.180797),
                ],
                // Same airport run as K2: the routed path overshoots west past Terminal Domestik
                // and doubles back. Identical stop coordinates, so this is K2's override verbatim.
                manualOverride: [
                    15: [
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
                    ]
                ]
            ),
        ]
    )
}
