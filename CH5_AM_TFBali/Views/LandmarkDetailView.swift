//
//  LandmarkDetailView.swift
//  CH5_AM_TFBali
//
//  Created by Novia Rahman Nisa on 15/08/26.
//

import SwiftUI

struct LandmarkDetailView: View {
    let place: Place
    
    var body: some View {
        ZStack {
            Color.appBackground
                .ignoresSafeArea()
            Image("temple-landmark-bg")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 300, height: 300)
                .position(x: 135, y: 650)
            ScrollView(.vertical, showsIndicators: true) {
                VStack {
                    Image(place.image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 350, height: 350)
                        .clipShape(
                            RoundedRectangle(cornerRadius: 20)
                        )
                    Spacer()
                    HStack {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(place.category.name)
                                .font(.system(.caption, design: .rounded))
                                .fontWeight(.medium)
                                .foregroundStyle(Color.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(Color.secondaryPurple)
                                .clipShape(RoundedRectangle(cornerRadius: 5))
                            Text(place.name)
                                .font(.system(.title, design: .rounded))
                                .fontWeight(.bold)
                                .foregroundStyle(Color.black)
                            HStack(spacing: 5) {
                                Image(systemName: "mappin.and.ellipse")
                                    .font(.system(size: 12))
                                Text("Sanur, Bali") // tba: no location-name field on Place yet
                                    .font(.system(.caption, design: .rounded))
                                    .fontWeight(.regular)
                            }
                            .foregroundStyle(.secondaryText)
                        }
                        Spacer()
                        NavigationLink {
//                            RouteMapView(destinationPlace: place)
                            RouteMapView(destinationPlace: place, isDirectToPlace: true)
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "arrow.turn.up.right")
                                    .font(.system(size: 16))
                                    .fontWeight(.heavy)
                                Text("Explore")
                                    .font(.system(.body, design: .rounded))
                                    .fontWeight(.semibold)
                            }
                            .foregroundStyle(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(Color.primaryOrange)
                            .clipShape(Capsule())
                        }
                        .simultaneousGesture(TapGesture().onEnded { Haptics.tap() })
                    }
                    .padding(.top, 20)
                    Text(place.desc)
                        .font(.system(.body, design: .rounded))
                        .fontWeight(.regular)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 20)
                    //                    Text("What to do")
                    //                    HStack {
                    //
                    //                    }
                }
                .padding()
            }
        }
    }
}

#Preview {
    LandmarkDetailView(
        place: Place(
            name: "Pura Tirta Empul",
            desc: "A sacred water temple and one of Bali's most important purification places. Locals come here for Melukat, a traditional cleansing ritual believed to bring balance and renewal.",
            image: "placeholder-default",
            category: Category(name: "Temple", image: "placeholder-default"),
            latitude: -8.4157,
            longitude: 115.3151
        )
    )
}
