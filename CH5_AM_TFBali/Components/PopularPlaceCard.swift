//
//  PopularPlaceCard.swift
//  CH5_AM_TFBali
//
//  Created by Novia Rahman Nisa on 15/08/26.
//

import SwiftUI

struct PopularPlaceCard: View {
    let place: Place
    
    var body: some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 25)
                .fill(Color.deepPrimaryPurple)
                .frame(width: 330, height: 170)
                .offset(y: 25)
            
            Image(place.image)
                .resizable()
                .frame(width: 110, height: 120)
                .clipShape(RoundedRectangle(cornerRadius: 25))
                .overlay(
                    RoundedRectangle(cornerRadius: 25)
                        .stroke(Color.secondaryPurple, lineWidth: 4)
                )
                .offset(x: 20, y: -15)
            
            Text(place.name)
                .font(.custom("Poppins-Bold", size: 18))
                .foregroundStyle(Color.creamText)
                .frame(width: 160, alignment: .leading)
                .multilineTextAlignment(.leading)
                .lineLimit(1)
                .offset(x: 145, y: -25)
            
            Text(place.desc)
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(Color.creamText)
                .frame(width: 170, alignment: .leading)
                .lineLimit(2)
                .offset(x: 145, y: 5)
            
            HStack(spacing: 10) {
                HStack(spacing: 3) {
                    Image(systemName: "clock.fill")
                    Text("3h") // tba: wire up TripEstimator result
                }
                HStack(spacing: 3) {
                    Image(systemName: "bus")
                    Text("3 bus rides") // tba: wire up TripEstimator result
                }
                HStack(spacing: 3) {
                    Image(systemName: "location.fill")
                    Text("500m") // tba: wire up TripEstimator result
                }
            }
            .font(.system(.caption2, design: .rounded))
            .foregroundStyle(Color.creamText)
            .fixedSize(horizontal: true, vertical: false)
            .offset(x: 145, y: 35)
            NavigationLink {
                LandmarkDetailView(place: place)
            } label: {
                Text("Go Explore")
                    .font(.custom("Poppins-Bold", size: 18))
                    .foregroundStyle(Color.deepPrimaryPurple)
                    .frame(width: 290)
                    .padding(.vertical, 5)
                    .background(Color.creamText)
                    .clipShape(Capsule())
            }
            .offset(x: 20, y: 80)
        }
        .frame(width: 330, height: 220)
        .shadow(color: Color.black.opacity(0.25), radius: 4, x: 4, y: 4)
    }
}

#Preview {
    PopularPlaceCard(
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
