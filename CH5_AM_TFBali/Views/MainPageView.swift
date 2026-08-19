//
//  HomeScreenView.swift
//  CH5_AM_TFBali
//
//  Created by Novia Rahman Nisa on 14/08/26.
//

import SwiftUI
import SwiftData

struct MainPageView: View {
    @Environment(\.modelContext) private var modelContext
    
    @Query(sort: \Category.name) private var categories: [Category]
    @Query(sort: \Place.name) private var places: [Place]
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground
                    .ignoresSafeArea()
                ScrollView(.vertical, showsIndicators: true) {
                    VStack {
                        VStack(spacing: 20) {
                            HStack {
                                Text("Jelaja")
                                    .font(.system(.title, design: .rounded))
                                    .fontWeight(.bold)
                                    .foregroundStyle(.black)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                Spacer()
                                LocationDisplay()
                            }
                            ZStack(alignment: .bottom) {
                                Image("home-image-1")
                                NavigationLink {
                                    //                                    RouteMapView()
                                    RouteNavigationView()
                                } label: {
                                    HStack(spacing: 25) {
                                        Text("Explore Bali by Bus")
                                            .font(.system(.title3, design: .rounded))
                                            .fontWeight(.bold)
                                        Image(systemName: "chevron.right")
                                            .font(.system(.title3))
                                            .fontWeight(.semibold)
                                    }
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 12)
                                    .background(Color.primaryOrange)
                                    .clipShape(RoundedRectangle(cornerRadius: 14))
                                }
                                .padding(.bottom, 20)
                            }
                        }
                        VStack(spacing: 20) {
                            HStack {
                                Text("Categories")
                                    .font(.system(.title3, design: .rounded))
                                    .fontWeight(.bold)
                                    .foregroundStyle(.primary)
                                    .textCase(.uppercase)
                                Spacer()
                            }
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 20) {
                                    ForEach(categories) { category in
                                        CategoryItem(category: category)
                                    }
                                }
                            }
                            .scrollClipDisabled()
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.top, 15)
                        VStack(spacing: -15) {
                            HStack {
                                Text("Popular Places")
                                    .font(.system(.title3, design: .rounded))
                                    .fontWeight(.bold)
                                    .foregroundStyle(.primary)
                                    .textCase(.uppercase)
                                Spacer()
                                NavigationLink {
                                    PopularPlaceView()
                                } label: {
                                    Image(systemName: "chevron.right")
                                        .font(.system(.title3))
                                        .fontWeight(.semibold)
                                        .foregroundStyle(Color.secondaryText)
                                }
                            }
                            //                            ScrollView(.horizontal, showsIndicators: false) {
                            //                                HStack(spacing: 20) {
                            //                                    ForEach(0..<2, id: \.self) { _ in
                            //                                        ZStack(alignment: .leading) {
                            //                                            RoundedRectangle(cornerRadius: 25)
                            //                                                .fill(Color.deepPrimaryPurple)
                            //                                                .frame(width: 330, height: 170)
                            //                                                .offset(y: 25)
                            //                                            Image("placeholder-default")
                            //                                                .resizable()
                            //                                                .frame(width: 110, height: 120)
                            //                                                .clipShape(RoundedRectangle(cornerRadius: 25))
                            //                                                .overlay(
                            //                                                    RoundedRectangle(cornerRadius: 25)
                            //                                                        .stroke(Color.secondaryPurple, lineWidth: 4)
                            //                                                )
                            //                                                .offset(x: 20, y: -15)
                            //                                            Text("Popular Title")
                            //                                                .font(.custom("Poppins-Bold", size: 18))
                            //                                                .foregroundStyle(Color.creamText)
                            //                                                .frame(width: 160, alignment: .leading)
                            //                                                .multilineTextAlignment(.leading)
                            //                                                .lineLimit(1)
                            //                                                .offset(x: 145, y: -25)
                            //                                            Text("Lorem ipsum dolor sit amet, consectetur adipiscing elit. Donec at massa sit amet risus hendrerit")
                            //                                                .font(.system(.caption, design: .rounded))
                            //                                                .foregroundStyle(Color.creamText)
                            //                                                .frame(width: 170, alignment: .leading)
                            //                                                .lineLimit(2)
                            //                                                .offset(x: 145, y: 5)
                            //                                            HStack(spacing: 10) {
                            //                                                HStack(spacing: 3) {
                            //                                                    Image(systemName: "clock.fill")
                            //                                                    Text("3h")
                            //                                                }
                            //                                                HStack(spacing: 3) {
                            //                                                    Image(systemName: "bus")
                            //                                                    Text("3 bus rides")
                            //                                                }
                            //                                                HStack(spacing: 3) {
                            //                                                    Image(systemName: "location.fill")
                            //                                                    Text("500m")
                            //                                                }
                            //                                            }
                            //                                            .font(.system(.caption2, design: .rounded))
                            //                                            .foregroundStyle(Color.creamText)
                            //                                            .fixedSize(horizontal: true, vertical: false)
                            //                                            .offset(x: 145, y: 35)
                            //                                            NavigationLink {
                            //                                                LandmarkDetailView()
                            //                                            } label: {
                            //                                                Text("Go Explore")
                            //                                                    .font(.custom("Poppins-Bold", size: 18))
                            //                                                    .foregroundStyle(Color.deepPrimaryPurple)
                            //                                                    .frame(width: 290)
                            //                                                    .padding(.vertical, 5)
                            //                                                    .background(Color.creamText)
                            //                                                    .clipShape(Capsule())
                            //                                            }
                            //                                            .offset(x: 20, y: 80)
                            //                                        }
                            //                                        .frame(width: 330, height: 220)
                            //                                        .shadow(color: Color.black.opacity(0.25), radius: 4, x: 4, y: 4)
                            //                                    }
                            //                                }
                            //                                .frame(maxWidth: .infinity, alignment: .leading)
                            //                            }
                            //                            .scrollClipDisabled()
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 20) {
                                    ForEach(places) { place in
                                        PopularPlaceCard(place: place)
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .scrollClipDisabled()
                        }
                        .padding(.top, 15)
                        VStack(spacing: 20) {
                            HStack {
                                Text("Where you have been")
                                    .font(.system(.title3, design: .rounded))
                                    .fontWeight(.bold)
                                    .foregroundStyle(.primary)
                                    .textCase(.uppercase)
                                Spacer()
                                NavigationLink {
                                    HistoryPageView()
                                } label: {
                                    Image(systemName: "chevron.right")
                                        .font(.system(.title3))
                                        .fontWeight(.semibold)
                                        .foregroundStyle(Color.secondaryText)
                                }
                            }
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 15) {
                                    ForEach(0..<4, id: \.self) { index in
                                        HistoryCard(
                                            date: .now,
                                            isAlternate: !index.isMultiple(of: 2)
                                        )
                                    }
                                }
                            }
                            .scrollClipDisabled()
                            //                            ScrollView(.horizontal, showsIndicators: false) {
                            //                                HStack(spacing: 15) {
                            //                                    ForEach(0..<4, id: \.self) { index in
                            //                                        ZStack {
                            //                                            Image(
                            //                                                index.isMultiple(of: 2)
                            //                                                ? "orange-history-note"
                            //                                                : "purple-history-note"
                            //                                            )
                            //                                            HStack(spacing: 4) {
                            //                                                Image(systemName: "calendar")
                            //                                                    .font(.system(.caption))
                            //                                                Text("15 August 2026")
                            //                                                    .font(.system(.caption, design: .rounded))
                            //                                            }
                            //                                            .frame(width: 125)
                            //                                            .padding(.vertical, 6)
                            //                                            .background(Color.creamText)
                            //                                            .clipShape(Capsule())
                            //                                            .foregroundStyle(Color.deepPrimaryPurple)
                            //                                            .offset(y: 55)
                            //                                        }
                            //                                    }
                            //                                }
                            //                            }
                            //                            .scrollClipDisabled()
                        }
                        .padding(.top, 15)
                    }
                    .padding()
                }
            }
        }
        .task {
            seedCategoriesIfNeeded(context: modelContext)
            seedPlacesIfNeeded(context: modelContext)
        }
    }
    
    func seedCategoriesIfNeeded(context: ModelContext) {
        do {
            let existing = try context.fetch(FetchDescriptor<Category>())
            guard existing.isEmpty else { return }
            for story in CategorySeedData.all {
                context.insert(story)
            }
            try context.save()
        } catch {
            print("Story seeding error:", error)
        }
    }
    
    func seedPlacesIfNeeded(context: ModelContext) {
        do {
            let existingPlaces = try context.fetch(FetchDescriptor<Place>())
            guard existingPlaces.isEmpty else { return }
            
            let categories = try context.fetch(FetchDescriptor<Category>())
            guard !categories.isEmpty else {
                print("No categories found — seed categories before places")
                return
            }
            
            let places = PlaceSeedData.all(categories: categories)
            places.forEach { context.insert($0) }
            try context.save()
        } catch {
            print("Place seeding error:", error)
        }
    }
}

//#Preview {
//    MainPageView()
//}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    
    let container = try! ModelContainer(
        for: Category.self, Place.self,
        configurations: config
    )
    
    let context = container.mainContext
    
    let temple = Category(name: "Temple", image: "placeholder-default")
    let beach = Category(name: "Beach", image: "placeholder-default")
    
    context.insert(temple)
    context.insert(beach)
    
    context.insert(Place(
        name: "Pura Tirta Empul",
        desc: "A holy spring water temple known for ritual purification baths.",
        image: "placeholder-default",
        category: temple,
        latitude: -8.4157,
        longitude: 115.3151,
        isPopular: true
    ))
    
    context.insert(Place(
        name: "Sanur Beach",
        desc: "A calm, family-friendly beach with a scenic morning walking path.",
        image: "placeholder-default",
        category: beach,
        latitude: -8.6905,
        longitude: 115.2624,
        isPopular: true
    ))
    
    return MainPageView()
        .modelContainer(container)
}
