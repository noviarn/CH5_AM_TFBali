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

//extension Category {
//    static func seedDefaultCategories(in context: ModelContext) {
//        let existing = try? context.fetch(FetchDescriptor<Category>())
//        guard existing?.isEmpty ?? true else { return }
//
//        let defaults = [
//            Category(name: "Temple", image: "placeholder-default"),
//            Category(name: "Statue", image: "placeholder-default"),
//            Category(name: "Beach", image: "placeholder-default"),
//            Category(name: "Park", image: "placeholder-default"),
//            Category(name: "Local Market", image: "placeholder-default"),
//            Category(name: "Art", image: "placeholder-default")
//        ]
//        defaults.forEach { context.insert($0) }
//
//        do {
//            try context.save()
//        } catch {
//            print("Failed to save seeded categories: \(error)")
//        }
//    }
//}
