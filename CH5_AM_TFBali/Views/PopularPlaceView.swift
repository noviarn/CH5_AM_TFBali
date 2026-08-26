//
//  PopularPlaceView.swift
//  CH5_AM_TFBali
//
//  Created by Novia Rahman Nisa on 16/08/26.
//

import SwiftUI
import SwiftData
import CoreLocation

struct PopularPlaceView: View {
    @Query(filter: #Predicate<Place> { $0.isPopular == true })

    private var popularPlaces: [Place]

    @StateObject private var locationProvider = SearchLocationManager()
    @State private var userLocation: CLLocationCoordinate2D?

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 25) {
                
                // MARK: - Section Title
                Text("Worth to explore")
                    .font(.system(.title, design: .rounded))
                    .fontWeight(.bold)
                    .foregroundStyle(Color.black)
                
                // MARK: - Places Grid
                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: 15),
                        GridItem(.flexible(), spacing: 15)
                    ],
                    spacing: 20
                ) {
                    ForEach(popularPlaces) { place in
                        PlaceCard(place: place, userLocation: userLocation)
                    }
                }
            }
            .padding(.horizontal, 20)
        }
        .background(Color.appBackground.ignoresSafeArea())
        .task {
            if userLocation == nil {
                userLocation = await locationProvider.currentLocation()
            }
        }
    }
}

#Preview {
    let container = makePreviewContainer()
    PopularPlaceView()
        .modelContainer(container)
}

@MainActor
private func makePreviewContainer() -> ModelContainer {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Category.self, Place.self, configurations: config)
    let context = container.mainContext
    
    let beach = Category(name: "Beach", image: "placeholder-default")
    let market = Category(name: "Local Market", image: "placeholder-default")
    context.insert(beach)
    context.insert(market)
    
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
        ],
        illustration: "landmark-placeholder"
    ))
    
    context.insert(Place(
        name: "Ubud Market",
        desc: "A bustling traditional market.",
        images: ["placeholder-default"],
        category: market,
        latitude: -8.5069,
        longitude: 115.2625,
        isPopular: true,
        locationName: "Bali",
        thingsToDo: [
            Activities(text: "Lorem ipsum dolor sit amet, consectetur adipiscing elit", icon: "placeholdertext.fill")
        ],
        illustration: "landmark-placeholder"
    ))
    
    context.insert(Place(
        name: "Popular Place",
        desc: "Lorem ipsum dolor sit amet, consectetur adipisicing elit.",
        images: ["placeholder-default"],
        category: market,
        latitude: -8.5069,
        longitude: 115.2621,
        isPopular: true,
        locationName: "Bali",
        thingsToDo: [
            Activities(text: "Lorem ipsum dolor sit amet, consectetur adipiscing elit", icon: "placeholdertext.fill")
        ],
        illustration: "landmark-placeholder"
    ))
    
    return container
}

