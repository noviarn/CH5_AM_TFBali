//
//  CategoryPageView.swift
//  CH5_AM_TFBali
//
//  Created by Novia Rahman Nisa on 17/08/26.
//

import SwiftUI
import SwiftData

struct CategoryPlaceView: View {
    @Query private var allPlaces: [Place]
    
    let category: Category
    
    private var places: [Place] {
        allPlaces.filter { $0.category.persistentModelID == category.persistentModelID }
    }
    
    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 25) {
                Text(category.name)
                    .font(.system(.title, design: .rounded))
                    .fontWeight(.bold)
                    .foregroundStyle(Color.black)
                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: 15),
                        GridItem(.flexible(), spacing: 15)
                    ],
                    spacing: 20
                ) {
                    ForEach(places) { place in
                        PlaceCard(
                            place: place,
                        )
                    }
                }
            }
            .padding(.horizontal, 20)
            //            .padding(.top, 20)
            //            .padding(.bottom, 30)
        }
        .background(Color.appBackground.ignoresSafeArea())
        //        .background {
        //            ZStack {
        //                Color.white
        //                Circle()
        //                    .fill(Color.primaryOrange.opacity(0.15))
        //                    .frame(width: 800, height: 800)
        //                    .offset(y: -380)
        //                Circle()
        //                    .fill(Color.primaryOrange.opacity(0.25))
        //                    .frame(width: 700, height: 700)
        //                    .offset(y: -380)
        //                Circle()
        //                    .fill(Color.primaryOrange.opacity(0.35))
        //                    .frame(width: 600, height: 600)
        //                    .offset(y: -380)
        //                Circle()
        //                    .fill(
        //                        LinearGradient(
        //                            colors: [
        //                                Color.tertiaryOrange,
        //                                Color.secondaryOrange,
        //                                Color.primaryOrange
        //                            ],
        //                            startPoint: .top,
        //                            endPoint: .bottom
        //                        )
        //                    )
        //                    .frame(width: 450, height: 450)
        //                    .offset(y: -350)
        //            }
        //            .ignoresSafeArea()
        //        }
    }
}

#Preview {
    let container = makeCategoryPreviewContainer()
    let sampleCategory = try! container.mainContext.fetch(FetchDescriptor<Category>()).first!
    
    CategoryPlaceView(category: sampleCategory)
        .modelContainer(container)
}

@MainActor
private func makeCategoryPreviewContainer() -> ModelContainer {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Category.self, Place.self, configurations: config)
    let context = container.mainContext
    
    let beach = Category(name: "Beach", image: "placeholder-default")
    context.insert(beach)
    
    context.insert(Place(
        name: "Sanur Beach",
        desc: "Explore beach, forest, and waterfall.",
        images: ["placeholder-default"],
        category: beach,
        latitude: -8.6905,
        longitude: 115.2624,
        isPopular: true,
        locationName: "Bali",
        thingsToDo: [
            Activities(text: "Lorem ipsum dolor sit amet, consectetur adipiscing elit", icon: "placeholdertext.fill")
        ]
    ))
    
    context.insert(Place(
        name: "Kuta Beach",
        desc: "A lively beach known for surfing and sunsets.",
        images: ["placeholder-default"],
        category: beach,
        latitude: -8.7183,
        longitude: 115.1686,
        isPopular: false,
        locationName: "Bali",
        thingsToDo: [
            Activities(text: "Lorem ipsum dolor sit amet, consectetur adipiscing elit", icon: "placeholdertext.fill")
        ]
    ))
    
    return container
}
