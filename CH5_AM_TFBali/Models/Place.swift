//
//  Place.swift
//  CH5_AM_TFBali
//
//  Created by Novia Rahman Nisa on 15/08/26.
//
import SwiftData

//@Model
//class Place {
//    var name: String
//    var desc: String
//    var image: String
//    @Relationship var category: Category
//    var latitude: Double
//    var longitude: Double
//    var isPopular: Bool
//
//    init(
//        name: String,
//        desc: String,
//        image: String,
//        category: Category,
//        latitude: Double,
//        longitude: Double,
//        isPopular: Bool = false
//    ) {
//        self.name = name
//        self.desc = desc
//        self.image = image
//        self.category = category
//        self.latitude = latitude
//        self.longitude = longitude
//        self.isPopular = isPopular
//    }
//}

struct Activities: Codable, Hashable {
    var text: String
    var icon: String
}

@Model
class Place {
    var name: String
    var desc: String
    var images: [String]
    @Relationship var category: Category
    var latitude: Double
    var longitude: Double
    var isPopular: Bool
    var locationName: String
    var thingsToDo: [Activities]
    var funFactTitle: String?
    var funFact: String?
    var illustration: String
    //    var funFactImage: String?
    
    init(
        name: String,
        desc: String,
        images: [String],
        category: Category,
        latitude: Double,
        longitude: Double,
        isPopular: Bool = false,
        locationName: String = "",
        thingsToDo: [Activities] = [],
        funFactTitle: String? = nil,
        funFact: String? = nil,
        illustration: String = "placeholder-default"
        //        funFactImage: String? = nil
    ) {
        self.name = name
        self.desc = desc
        self.images = images
        self.category = category
        self.latitude = latitude
        self.longitude = longitude
        self.isPopular = isPopular
        self.locationName = locationName
        self.thingsToDo = thingsToDo
        self.funFactTitle = funFactTitle
        self.funFact = funFact
        self.illustration = illustration
        //        self.funFactImage = funFactImage
    }
}

extension Place {
    var image: String { images.first ?? "placeholder-default" }
}
