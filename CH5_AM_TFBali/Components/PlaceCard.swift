//
//  PlaceCard.swift
//  CH5_AM_TFBali
//
//  Created by Novia Rahman Nisa on 16/08/26.
//

import SwiftUI

struct PlaceCard: View {
    let place: Place
    let cardColor: Color
    let textColor: Color
    let strokeColor: Color

    var body: some View {
        ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: 20)
                .fill(cardColor)
                .frame(width: 175, height: 220)
                .offset(y: 35)
            Image(place.image)
                .resizable()
                .scaledToFill()
                .frame(width: 120, height: 90)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(strokeColor, lineWidth: 5)
                )
                .frame(width: 165)
                .offset(y: -5)
            VStack(alignment: .leading, spacing: 0) {
                Spacer().frame(height: 105)
                Text(place.name)
                    .font(.custom("Poppins-Bold", size: 18))
                    .foregroundStyle(textColor)
                    .lineLimit(1)
                Text(place.desc)
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(textColor)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .padding(.top, 3)
                HStack(spacing: 8) {
                    HStack(spacing: 3) {
                        Image(systemName: "clock.fill")
                        Text("3m")
                    }
                    HStack(spacing: 3) {
                        Image(systemName: "bus.fill")
                        Text("5")
                    }
                    HStack(spacing: 3) {
                        Image(systemName: "location.fill")
                        Text("6km")
                    }
                }
                .font(.system(.caption2, design: .rounded))
                .foregroundStyle(textColor)
                .padding(.top, 8)
                NavigationLink {
                    LandmarkDetailView(place: place)
                } label: {
                    Text("Go Explore")
                        .font(.custom("Poppins-Bold", size: 14))
                        .foregroundStyle(cardColor)
                        .frame(width: 135)
                        .padding(.vertical, 6)
                        .background(textColor)
                        .clipShape(Capsule())
                }
                .simultaneousGesture(TapGesture().onEnded { Haptics.tap() })
                .padding(.top, 10)
            }
            .frame(width: 135)
        }
        .frame(width: 165, height: 255)
        .shadow(color: Color.black.opacity(0.25), radius: 4, x: 4, y: 4)
    }
}

#Preview {
    VStack(spacing: 20) {
        PlaceCard(
            place: Place(
                name: "Sanur Beach",
                desc: "Explore beach, forest, and waterfall.",
                image: "placeholder-default",
                category: Category(name: "Beach", image: "placeholder-default"),
                latitude: -8.6905,
                longitude: 115.2624
            ),
            cardColor: Color.deepPrimaryPurple,
            textColor: Color.creamText,
            strokeColor: Color.secondaryPurple
        )

        PlaceCard(
            place: Place(
                name: "Ubud Market",
                desc: "A bustling traditional market.",
                image: "placeholder-default",
                category: Category(name: "Local Market", image: "placeholder-default"),
                latitude: -8.5069,
                longitude: 115.2625
            ),
            cardColor: Color.primaryOrange,
            textColor: Color.white,
            strokeColor: Color.creamText
        )
    }
    .padding()
}
