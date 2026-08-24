//
//  HomeScreenView.swift
//  CH5_AM_TFBali
//
//  Created by Novia Rahman Nisa on 14/08/26.
//

import SwiftUI
import SwiftData
import CoreLocation

struct MainPageView: View {
    @Environment(\.modelContext) private var modelContext
    
    @Query(sort: \Category.name) private var categories: [Category]
    @Query(sort: \Place.name) private var places: [Place]
    /// Finished trips, newest first — the strip shows the latest handful, the full list lives
    /// behind `HistoryPageView`.
    @Query(
        filter: #Predicate<NavigationSession> { $0.endedAt != nil },
        sort: \NavigationSession.startedAt,
        order: .reverse
    )
    private var finishedSessions: [NavigationSession]

    private var recentSessions: [NavigationSession] {
        Array(finishedSessions.prefix(6))
    }
    
    var body: some View {
        // No `NavigationStack` here — `ContentView` owns the single stack for the app so it
        // can push a resumed trip onto it (see `ContentView.body`) rather than replacing the
        // root, which left a resumed trip with no "back" to pop to once it stopped.
        ZStack {
            Color.appBackground
                .ignoresSafeArea()
            ScrollView(.vertical, showsIndicators: true) {
                VStack {
                    VStack(spacing: 10) {
                        HStack(alignment: .top) {
                            VStack(spacing: 10) {
                                Text("Jelaja")
                                    .font(.system(.largeTitle, design: .rounded))
                                    .fontWeight(.bold)
                                    .foregroundStyle(.black)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            //                            Spacer()
                            //                            LocationDisplay()
                        }
                        ZStack(alignment: .bottom) {
                            Image("home-image-1")
                            NavigationLink {
                                RouteMapView()
                            } label: {
                                HStack {
                                    Text("Search nearby spots")
                                        .font(.system(.title2, design: .rounded))
                                        .fontWeight(.bold)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.system(.title2))
                                        .fontWeight(.semibold)
                                }
                                .foregroundStyle(.white)
                            }
                            .simultaneousGesture(TapGesture().onEnded { Haptics.tap() })
                            .padding(.horizontal, 20)
                            .padding(.bottom, 20)
                        }
                    }
                    VStack(spacing: 20) {
                        HStack {
                            Text("What's in Bali?")
                                .font(.system(.title2, design: .rounded))
                                .fontWeight(.bold)
                                .foregroundStyle(.primary)
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
                    VStack(spacing: 20) {
                        HStack {
                            Text("Worth to explore")
                                .font(.system(.title2, design: .rounded))
                                .fontWeight(.bold)
                                .foregroundStyle(.primary)
                            Spacer()
                            NavigationLink {
                                PopularPlaceView()
                            } label: {
                                Image(systemName: "chevron.right")
                                    .font(.system(.title3))
                                    .fontWeight(.semibold)
                                    .foregroundStyle(Color.textMuted)
                            }
                            .simultaneousGesture(TapGesture().onEnded { Haptics.tap() })
                        }
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 20) {
                                ForEach(places.prefix(6)) { place in
                                    PlaceCard(place: place)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .scrollClipDisabled()
                    }
                    .padding(.top, 15)
                    VStack(spacing: 20) {
                        HStack {
                            Text("Places you've explored")
                                .font(.system(.title2, design: .rounded))
                                .fontWeight(.bold)
                                .foregroundStyle(.primary)
                            Spacer()
                            NavigationLink {
                                HistoryPageView()
                            } label: {
                                Image(systemName: "chevron.right")
                                    .font(.system(.title3))
                                    .fontWeight(.semibold)
                                    .foregroundStyle(Color.textMuted)
                            }
                            .simultaneousGesture(TapGesture().onEnded { Haptics.tap() })
                        }
                        if recentSessions.isEmpty {
                            Text("Trips you finish will show up here.")
                                .font(.system(.subheadline, design: .rounded))
                                .foregroundStyle(Color.textMuted)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        } else {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 15) {
                                    ForEach(recentSessions) { session in
                                        NavigationLink {
                                            HistoryDetailView(session: session)
                                        } label: {
                                            HistoryCard(
                                                title: HistoryCard.title(for: session),
                                                date: session.startedAt.formatted(.dateTime.day().month(.wide).year())
                                            )
                                        }
                                        .buttonStyle(.plain)
                                        .simultaneousGesture(TapGesture().onEnded { Haptics.tap() })
                                    }
                                }
                            }
                            .scrollClipDisabled()
                        }
                    }
                    .padding(.top, 15)
                }
                .padding(20)
            }
        }
        .task {
            seedCategoriesIfNeeded(context: modelContext)
            removeLoremIpsumPlaces(context: modelContext)
            seedLandmarkPlacesIfNeeded(context: modelContext)
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
    
    /// Deletes any already-persisted `Place` left over from the removed `PlaceSeedData`
    /// placeholder set (3 entries, all sharing the same lorem-ipsum description) — a device
    /// or simulator that ran the app before that seed data was deleted from source still has
    /// these rows sitting in its local store, since seeding only ever inserts.
    func removeLoremIpsumPlaces(context: ModelContext) {
        do {
            let placeholderDesc = "Lorem ipsum dolor sit amet, consectetur adipisicing elit. Repellat, aspernatur."
            let stale = try context.fetch(FetchDescriptor<Place>(predicate: #Predicate { $0.desc == placeholderDesc }))
            guard !stale.isEmpty else { return }
            stale.forEach { context.delete($0) }
            try context.save()
        } catch {
            print("Placeholder place cleanup error:", error)
        }
    }
    
    /// Seeds `landmarkPOIs` (the corridor points of interest) into the discovery tab as
    /// `Place` records — the only source of `Place` data now that the lorem-ipsum
    /// placeholder set (`PlaceSeedData`) has been removed. Checked by name rather than gated
    /// on the `Place` table being empty, so it also fills in a database that's never seeded
    /// landmarks before.
    func seedLandmarkPlacesIfNeeded(context: ModelContext) {
        do {
            let existingNames = Set(try context.fetch(FetchDescriptor<Place>()).map(\.name))
            let categories = try context.fetch(FetchDescriptor<Category>())
            guard !categories.isEmpty else {
                print("No categories found — seed categories before landmark places")
                return
            }
            func category(_ name: String) -> Category? {
                categories.first(where: { $0.name == name })
            }
            
            var didInsert = false
            for poi in landmarkPOIs where !existingNames.contains(poi.name) {
                guard let category = category(poi.placeCategoryName) else {
                    print("No category '\(poi.placeCategoryName)' for landmark '\(poi.name)' — skipping")
                    continue
                }
                context.insert(Place(
                    name: poi.name,
                    desc: poi.summary,
                    images: poi.images,
                    category: category,
                    latitude: poi.coordinate.latitude,
                    longitude: poi.coordinate.longitude,
                    locationName: poi.locationName,
                    thingsToDo: poi.activities,
                    funFactTitle: poi.funFactTitle,
                    funFact: poi.funFact
                ))
                didInsert = true
            }
            if didInsert {
                try context.save()
            }
        } catch {
            print("Landmark place seeding error:", error)
        }
        
        //                do {
        //                    let existingNames = Set(try context.fetch(FetchDescriptor<Place>()).map(\.name))
        //                    let categories = try context.fetch(FetchDescriptor<Category>())
        //                    guard !categories.isEmpty else {
        //                        print("No categories found — seed categories before landmark places")
        //                        return
        //                    }
        //                    func category(_ name: String) -> Category? {
        //                        categories.first(where: { $0.name == name })
        //                    }
        //
        //                    var didInsert = false
        //                    for poi in landmarkPOIs where !existingNames.contains(poi.name) {
        //                        guard let category = category(poi.placeCategoryName) else {
        //                            print("No category '\(poi.placeCategoryName)' for landmark '\(poi.name)' — skipping")
        //                            continue
        //                        }
        //                        context.insert(Place(
        //                            name: poi.name,
        //                                                desc: poi.summary,
        //                                                images: poi.images,
        //                                                category: category,
        //                                                latitude: poi.coordinate.latitude,
        //                                                longitude: poi.coordinate.longitude,
        //                                                locationName: poi.locationName,
        //                                                thingsToDo: poi.activities,
        //                                                funFactTitle: poi.funFactTitle,
        //                                                funFact: poi.funFact
        //                        ))
        //                        didInsert = true
        //                    }
        //                    if didInsert {
        //                        try context.save()
        //                    }
        //                } catch {
        //                    print("Landmark place seeding error:", error)
        //                }
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    
    let container = try! ModelContainer(
        for: Category.self, Place.self,
        configurations: config
    )
    
    return NavigationStack {
        MainPageView()
    }
    .modelContainer(container)
}
