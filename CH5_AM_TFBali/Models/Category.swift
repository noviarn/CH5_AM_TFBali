//
//  Category.swift
//  CH5_AM_TFBali
//
//  Created by Novia Rahman Nisa on 15/08/26.
//
import SwiftData

@Model
class Category {
    var name: String
    var image: String
    
    init(name: String, image: String) {
        self.name = name
        self.image = image
    }
}
