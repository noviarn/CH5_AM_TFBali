import SwiftUI

extension Corridor {
    static let shuttleSanur = Corridor(
        id: "SHUTTLE_SANUR",
        name: "Shuttle Bus Sanur",
        color: Color(red: 0.65, green: 0.85, blue: 1.0),
        headwayMinutes: 20,
        directions: [
            RouteDirection(
                label: "Parkir Mertasari → Jl. Wira (Segara Ayu)",
                stops: [
                    stop("Parkir Mertasari", -8.711290, 115.249271),
                    stop("Mercure Resort", -8.709010, 115.253955),
                    stop("Sudamala Resort", -8.707615, 115.256147),
                    stop("Bhinneka", -8.704892, 115.258348),
                    stop("SPKLU Sanur", -8.705109, 115.259996),
                    stop("Duyung Barat", -8.702546, 115.261555),
                    stop("Andaz", -8.699300, 115.262941),
                    stop("The 101 Sanur", -8.695331, 115.263659),
                    stop("Soya", -8.690005, 115.263723),
                    stop("ICON Mall Beach", -8.686875, 115.262701),
                    stop("Pasar Sindhu", -8.685310, 115.260576),
                    stop("Jl. Wira (Segara Ayu)", -8.681325, 115.260554),
                ]
            ),
            RouteDirection(
                label: "Jl. Wira (Segara Ayu) → Parkir Mertasari",
                stops: [
                    stop("Jl. Wira (Segara Ayu)", -8.681325, 115.260554),
                    stop("Pasar Sindhu", -8.685247, 115.260658),
                    stop("ICON Mall Beach", -8.686875, 115.262701),
                    stop("Soya", -8.690005, 115.263723),
                    stop("The 101 Sanur", -8.695331, 115.263659),
                    stop("Hyatt Regency Sanur", -8.701859, 115.262186),
                    stop("Massimo Gelato", -8.704843, 115.260810),
                    stop("Art Shop Cemara", -8.706405, 115.259401),
                    stop("Prama", -8.707713, 115.256803),
                    stop("Mercure Resort", -8.709010, 115.253955),
                    stop("Parkir Mertasari", -8.711290, 115.249271),
                ]
            ),
        ]
    )
}
