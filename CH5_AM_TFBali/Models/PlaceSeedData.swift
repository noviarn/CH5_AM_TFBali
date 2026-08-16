//
//  PlaceSeedData.swift
//  CH5_AM_TFBali
//
//  Created by Novia Rahman Nisa on 15/08/26.
//
enum PlaceSeedData {
    /// Takes categories as input since each Place needs a real Category reference,
    /// not just a name string.
    static func all(categories: [Category]) -> [Place] {
        func category(_ name: String) -> Category? {
            categories.first(where: { $0.name == name })
        }
        
        var places: [Place] = []
        
        if let temple = category("Temple") {
            places.append(
                Place(
                    name: "Pura Tirta Empul",
                    desc: "Lorem ipsum dolor sit amet, consectetur adipisicing elit. Repellat, aspernatur.",
                    image: "placeholder-default",
                    category: temple,
                    latitude: -8.4157,
                    longitude: 115.3151,
                    isPopular: true
                )
            )
        }
        
        if let beach = category("Beach") {
            places.append(
                Place(
                    name: "Sanur Beach",
                    desc: "Lorem ipsum dolor sit amet, consectetur adipisicing elit. Repellat, aspernatur.",
                    image: "placeholder-default",
                    category: beach,
                    latitude: -8.6905,
                    longitude: 115.2624,
                    isPopular: true
                )
            )
        }
        
        if let market = category("Local Market") {
            places.append(
                Place(
                    name: "Ubud Market",
                    desc: "Lorem ipsum dolor sit amet, consectetur adipisicing elit. Repellat, aspernatur.",
                    image: "placeholder-default",
                    category: market,
                    latitude: -8.5069,
                    longitude: 115.2625,
                    isPopular: false
                )
            )
        }
        
        return places
    }
}
