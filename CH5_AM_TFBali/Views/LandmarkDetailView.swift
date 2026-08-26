//
//  LandmarkDetailView.swift
//  CH5_AM_TFBali
//
//  Created by Novia Rahman Nisa on 15/08/26.
//

import SwiftUI
import CoreLocation

struct LandmarkDetailView: View {
    let place: Place

    @StateObject private var locationProvider = SearchLocationManager()
    @State private var estimate: PlaceTripEstimate?
    /// Set when a trip started from here ends while this view is covered by it; acted on in
    /// onAppear, once this view is topmost again and can actually pop.

    var body: some View {
        ZStack {
            Color.appBackground
                .ignoresSafeArea()
            
            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 15) {
                    
                    // MARK: - Header
                    HStack(alignment: .top, spacing: 15) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(place.name)
                                .font(.system(.title, design: .rounded))
                                .fontWeight(.bold)
                                .foregroundStyle(.black)
                            
                            Text(place.category.name)
                                .font(.system(.subheadline, design: .rounded))
                                .foregroundStyle(Color.textMuted)
                            
                            HStack(spacing: 12) {
                                HStack(spacing: 4) {
                                    Image(systemName: "mappin.and.ellipse")
                                        .font(.system(size: 13, weight: .semibold))
                                    
                                    Text(place.locationName)
                                        .font(.system(.caption, design: .rounded))
                                }
                                
                                HStack(spacing: 4) {
                                    Image(systemName: "clock")
                                        .font(.system(size: 13, weight: .semibold))

                                    Text(estimate.map { "est. " + $0.duration } ?? "—")
                                        .font(.system(.caption, design: .rounded))
                                }

                                HStack(spacing: 4) {
                                    Image(systemName: "location.fill")
                                        .font(.system(size: 13, weight: .semibold))

                                    Text(estimate.map { Self.distanceText($0.totalDistanceKm) } ?? "—")
                                        .font(.system(.caption, design: .rounded))
                                }
                            }
                            .foregroundStyle(Color.textMuted)
                        }
                        
                        Spacer()
                        
                        // MARK: - Go / Route Button
                        NavigationLink {
                            RouteMapView(
                                destinationPlace: place,
                                isDirectToPlace: true
                            )
                        } label: {
                            Image(systemName: "arrow.right")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(width: 48, height: 48)
                                .background(Color.primaryOrange)
                                .clipShape(Circle())
                        }
                        .simultaneousGesture(TapGesture().onEnded { Haptics.tap() })
                    }
                    
                    // MARK: - Image Carousel
                    TabView {
                        ForEach(place.images, id: \.self) { imageName in
                            Image(imageName)
                                .resizable()
                                .scaledToFill()
                                .frame(
                                    width: 350,
                                    height: 350
                                )
                                .clipped()
                        }
                    }
                    .frame(width: 350, height: 350)
                    .clipShape(
                        RoundedRectangle(cornerRadius: 20)
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(
                                Color.black.opacity(0.05),
                                lineWidth: 1
                            )
                    }
                    .tabViewStyle(.page(indexDisplayMode: .automatic))
                    .frame(maxWidth: .infinity)
                    
                    // MARK: - Description
                    Text(place.desc)
                        .font(.system(.body, design: .rounded))
                        .foregroundStyle(.black)
                        .fontWeight(.regular)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .lineSpacing(4)
                    
                    // MARK: - Things To Do
                    if !place.thingsToDo.isEmpty {
                        VStack(alignment: .leading, spacing: 15) {
                            Text("WHAT TO DO")
                                .font(.system(.subheadline, design: .rounded))
                                .fontWeight(.bold)
                                .foregroundStyle(Color.primaryPurple)
                            
                            ForEach(place.thingsToDo, id: \.self) { activity in
                                HStack(spacing: 16) {
                                    Image(systemName: activity.icon)
                                        .font(.system(size: 18, weight: .semibold))
                                        .foregroundStyle(.black)
                                        .frame(width: 44, height: 44)
                                        .background(Color.white)
                                        .clipShape(Circle())
                                    
                                    Text(activity.text)
                                        .font(.system(.callout, design: .rounded))
                                        .fontWeight(.semibold)
                                        .foregroundStyle(.white)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .frame(
                                    maxWidth: .infinity,
                                    alignment: .leading
                                )
                                .background(Color.accentPurple)
                                .clipShape(
                                    RoundedRectangle(cornerRadius: 15)
                                )
                            }
                        }
                        .padding(.top, 10)
                    }
                    
                    // MARK: - Fun Fact
                    if let funFactTitle = place.funFactTitle,
                       let funFact = place.funFact {
                        
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(alignment: .center) {
                                Text(funFactTitle)
                                    .font(
                                        .system(
                                            .headline,
                                            design: .rounded
                                        )
                                    )
                                    .fontWeight(.bold)
                                    .foregroundStyle(.black)

                                Spacer()

                                Image("funfact-placeholder")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 80, height: 60)
                            }

                            Text(funFact)
                                .font(
                                    .system(
                                        .footnote,
                                        design: .rounded
                                    )
                                )
                                .foregroundStyle(Color.black)
                                .lineSpacing(3)
                        }
                        .padding(16)
                        .background(Color.white)
                        .clipShape(
                            RoundedRectangle(cornerRadius: 16)
                        )
                        .shadow(color: Color.black.opacity(0.25), radius: 4, x: 1, y: 2)
                        .overlay(alignment: .topLeading) {
                            Text("FUNFACT")
                                .font(.system(.body, design: .rounded))
                                .fontWeight(.bold)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(Color.primaryOrange)
                                .clipShape(
                                    RoundedRectangle(cornerRadius: 5)
                                )
                                .offset(x: 12, y: -10)
                        }
                        .padding(.top, 25)
                    }
                }
                .padding(.horizontal, 20)
            }
        }
        .task {
            guard let here = await locationProvider.currentLocation() else { return }
            let target = CLLocationCoordinate2D(latitude: place.latitude, longitude: place.longitude)
            let result = await TripEstimateCache.shared.estimate(to: target, from: here)
            guard !Task.isCancelled else { return }
            estimate = result
        }
    }

    private static func distanceText(_ km: Double) -> String {
        km < 1
            ? String(format: "%.0f m", km * 1000)
            : String(format: "%.1f km", km)
    }
}

#Preview {
    LandmarkDetailView(
        place: Place(
            name: "Arjuna Statue",
            desc: "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat.",
            images: ["arjuna-statue-1", "arjuna-statue-2"],
            category: Category(name: "Statue", image: "placeholder-default"),
            latitude: -8.4157,
            longitude: 115.3151,
            locationName: "Ubud, Bali",
            thingsToDo: [
                Activities(text: "Lorem ipsum dolor sit amet, consectetur adipiscing elit", icon: "placeholdertext.fill"),
                Activities(text: "Lorem ipsum dolor sit amet, consectetur adipiscing elit", icon: "placeholdertext.fill")
            ],
            funFactTitle: "Lorem ipsum dolor sit amet. Ut enim ad minim veniam",
            funFact: "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat."
        )
    )
}
