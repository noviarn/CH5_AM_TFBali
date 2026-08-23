//
//  PopularPlaceCard.swift
//  CH5_AM_TFBali
//
//  Created by Novia Rahman Nisa on 15/08/26.
//

import SwiftUI

struct PlaceCard: View {
    let place: Place
    
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
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.secondaryPurple, lineWidth: 1)
                        )
                    Text(place.category.name)
                        .font(.system(.footnote, design: .rounded))
                        .foregroundStyle(Color.primaryPurple)
                        .padding(.vertical, 5)
                        .padding(.horizontal, 10)
                        .background(Color.lightPrimaryPurple)
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
                        Text("3h") // tba: wire up TripEstimator result
                    }
                    HStack(spacing: 3) {
                        Image(systemName: "location.fill")
                        Text("500m") // tba: wire up TripEstimator result
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
    }
}

#Preview {
    PlaceCard(
        place: Place(
            name: "Pura Tirta Empul",
            desc: "A holy spring water temple known for ritual purification baths.",
            image: "placeholder-default",
            category: Category(name: "Temple", image: "placeholder-default"),
            latitude: -8.4157,
            longitude: 115.3151
        )
    )
}
