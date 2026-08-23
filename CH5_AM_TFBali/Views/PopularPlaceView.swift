//
//  PopularPlaceView.swift
//  CH5_AM_TFBali
//
//  Created by Novia Rahman Nisa on 16/08/26.
//

import SwiftUI
import SwiftData

struct PopularPlaceView: View {
    @Query(filter: #Predicate<Place> { $0.isPopular == true })
    
    private var popularPlaces: [Place]
    
    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 30) {
                VStack(spacing: 15) {
                    Text("Popular Places")
                        .font(.system(.title, design: .rounded))
                        .fontWeight(.bold)
                        .foregroundStyle(Color.white)

                    Image("placeholder-default")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 220, height: 150)
                }
                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: 15),
                        GridItem(.flexible(), spacing: 15)
                    ],
                    spacing: 25
                ) {
                    ForEach(popularPlaces) { place in
                        PlaceCard(
                            place: place,
//                            cardColor: Color.primaryPurple,
//                            textColor: Color.creamText,
//                            strokeColor: Color.secondaryPurple
                        )
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 30)
        }
        .background {
            ZStack {
                Color.white
                // lightest purple
                Circle()
                    .fill(Color.primaryPurple.opacity(0.15))
                    .frame(width: 800, height: 800)
                    .offset(y: -380)
                // medium purple
                Circle()
                    .fill(Color.primaryPurple.opacity(0.25))
                    .frame(width: 700, height: 700)
                    .offset(y: -380)
                // darker purple
                Circle()
                    .fill(Color.primaryPurple.opacity(0.35))
                    .frame(width: 600, height: 600)
                    .offset(y: -380)
                // main gradient
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.primaryPurple
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 450, height: 450)
                    .offset(y: -350)
            }
            .ignoresSafeArea()
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
        image: "placeholder-default",
        category: beach,
        latitude: -8.6905,
        longitude: 115.2624,
        isPopular: true
    ))
    
    context.insert(Place(
        name: "Ubud Market",
        desc: "A bustling traditional market.",
        image: "placeholder-default",
        category: market,
        latitude: -8.5069,
        longitude: 115.2625,
        isPopular: true
    ))
    
    context.insert(Place(
        name: "Popular Place",
        desc: "Lorem ipsum dolor sit amet, consectetur adipisicing elit.",
        image: "placeholder-default",
        category: market,
        latitude: -8.5069,
        longitude: 115.2621,
        isPopular: true
    ))
    
    return container
}

