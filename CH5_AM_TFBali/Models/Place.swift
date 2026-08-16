//
//  Place.swift
//  CH5_AM_TFBali
//
//  Created by Novia Rahman Nisa on 15/08/26.
//
import SwiftData

@Model
class Place {
    var name: String
    var desc: String
    var image: String
    @Relationship var category: Category
    var latitude: Double
    var longitude: Double
    var isPopular: Bool
    
    init(
        name: String,
        desc: String,
        image: String,
        category: Category,
        latitude: Double,
        longitude: Double,
        isPopular: Bool = false
    ) {
        self.name = name
        self.desc = desc
        self.image = image
        self.category = category
        self.latitude = latitude
        self.longitude = longitude
        self.isPopular = isPopular
    }
}
