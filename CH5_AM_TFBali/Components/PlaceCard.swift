//
//  PlaceCard.swift
//  CH5_AM_TFBali
//
//  Created by Novia Rahman Nisa on 15/08/26.
//

import SwiftUI
import CoreLocation

struct PlaceCard: View {
    let place: Place
    /// The rider's position, threaded from the parent so the card can show a real distance
    /// and time to this place instead of the old hardcoded values. Nil until a fix arrives.
    var userLocation: CLLocationCoordinate2D? = nil

    @State private var estimate: PlaceTripEstimate?

    private var placeCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: place.latitude, longitude: place.longitude)
    }

    private var locationKey: String {
        userLocation.map { "\($0.latitude),\($0.longitude)" } ?? ""
    }

    var body: some View {
        //        ZStack(alignment: .leading) {
        //            RoundedRectangle(cornerRadius: 25)
        //                .fill(Color.deepPrimaryPurple)
        //                .frame(width: 330, height: 170)
        //                .offset(y: 25)
        //
        //            Image(place.image)
        //                .resizable()
        //                .frame(width: 110, height: 120)
        //                .clipShape(RoundedRectangle(cornerRadius: 25))
        //                .overlay(
        //                    RoundedRectangle(cornerRadius: 25)
        //                        .stroke(Color.secondaryPurple, lineWidth: 4)
        //                )
        //                .offset(x: 20, y: -15)
        //
        //            Text(place.name)
        //                .font(.custom("Poppins-Bold", size: 18))
        //                .foregroundStyle(Color.creamText)
        //                .frame(width: 160, alignment: .leading)
        //                .multilineTextAlignment(.leading)
        //                .lineLimit(1)
        //                .offset(x: 145, y: -25)
        //
        //            Text(place.desc)
        //                .font(.system(.caption, design: .rounded))
        //                .foregroundStyle(Color.creamText)
        //                .frame(width: 170, alignment: .leading)
        //                .lineLimit(2)
        //                .offset(x: 145, y: 5)
        //
        //            HStack(spacing: 10) {
        //                HStack(spacing: 3) {
        //                    Image(systemName: "clock.fill")
        //                    Text("3h") // tba: wire up TripEstimator result
        //                }
        //                HStack(spacing: 3) {
        //                    Image(systemName: "bus")
        //                    Text("3 bus rides") // tba: wire up TripEstimator result
        //                }
        //                HStack(spacing: 3) {
        //                    Image(systemName: "location.fill")
        //                    Text("500m") // tba: wire up TripEstimator result
        //                }
        //            }
        //            .font(.system(.caption2, design: .rounded))
        //            .foregroundStyle(Color.creamText)
        //            .fixedSize(horizontal: true, vertical: false)
        //            .offset(x: 145, y: 35)
        //            NavigationLink {
        //                LandmarkDetailView(place: place)
        //            } label: {
        //                Text("Go Explore")
        //                    .font(.custom("Poppins-Bold", size: 18))
        //                    .foregroundStyle(Color.deepPrimaryPurple)
        //                    .frame(width: 290)
        //                    .padding(.vertical, 5)
        //                    .background(Color.creamText)
        //                    .clipShape(Capsule())
        //            }
        //            .offset(x: 20, y: 80)
        //        }
        //        .frame(width: 330, height: 220)
        //        .shadow(color: Color.black.opacity(0.25), radius: 4, x: 4, y: 4)
        //
        NavigationLink(destination: LandmarkDetailView(place: place)) {
            VStack(alignment: .leading, spacing: 8) {
                ZStack(alignment: .topLeading) {
                    Image(place.image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 150, height: 140)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    //                        .overlay(
                    //                            RoundedRectangle(cornerRadius: 10)
                    //                                .stroke(Color.secondaryPurple, lineWidth: 1)
                    //                        )
                    Text(place.category.name)
                        .font(.system(.footnote, design: .rounded))
                        .foregroundStyle(Color.primaryPurple)
                        .padding(.vertical, 5)
                        .padding(.horizontal, 10)
                        .background(Color.secondaryPurple)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .padding(8)
                }
                Text(place.name)
                    .font(.custom("Poppins-Bold", size: 14))
                    .foregroundStyle(Color.primaryPurple)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(place.desc)
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(Color.primaryPurple)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                HStack(spacing: 10) {
                    HStack(spacing: 3) {
                        Image(systemName: "clock.fill")
                        Text(estimate.map { "est. " + $0.duration } ?? "—")
                    }
                    HStack(spacing: 3) {
                        Image(systemName: "location.fill")
                        Text(estimate.map { Self.distanceText($0.totalDistanceKm) } ?? "—")
                    }
                }
                .font(.system(.caption2, design: .rounded))
                .foregroundStyle(Color.textMuted)
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 15)
            .frame(width: 170)
            .background {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.white)
                    .shadow(
                        color: Color.black.opacity(0.25),
                        radius: 2,
                        x: 2,
                        y: 2
                    )
            }
        }
        .buttonStyle(.plain)
        .task(id: locationKey) {
            guard let userLocation else { estimate = nil; return }
            let target = placeCoordinate
            // Off the main actor: the path search is pure geometry and shouldn't stall scrolling.
            estimate = await Task.detached {
                TripEstimator.estimateTrip(to: target, from: userLocation, corridors: corridors)
            }.value
        }
    }

    private static func distanceText(_ km: Double) -> String {
        km < 1
            ? String(format: "%.0f m", km * 1000)
            : String(format: "%.1f km", km)
    }
}

#Preview {
    PlaceCard(
        place: Place(
            name: "Arjuna Statue",
            desc: "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Donec at semper dui.",
            images: ["arjuna-statue-1"],
            category: Category(name: "Statue", image: "placeholder-default"),
            latitude: -8.4157,
            longitude: 115.3151,
            locationName: "Ubud, Bali",
            thingsToDo: [
                Activities(text: "Lorem ipsum dolor sit amet, consectetur adipiscing elit", icon: "placeholdertext.fill")
            ]
        )
    )
}
