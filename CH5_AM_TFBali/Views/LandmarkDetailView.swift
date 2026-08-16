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
                        VStack(alignment: .leading, spacing: 4) {
                            Text(place.category.name)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                            Text(place.name)
                                .font(.title3.weight(.bold))
                            HStack(spacing: 5) {
                                Image(systemName: "mappin.and.ellipse")
                                    .font(.system(size: 16))
                                Text("Sanur, Bali") // tba: no location-name field on Place yet
                                    .font(.system(.body, design: .rounded))
                                    .fontWeight(.regular)
                            }
                            .foregroundStyle(.secondaryText)
                        }
                        Spacer()
                        NavigationLink {
                            // tba
                        } label: {
                            Image(systemName: "arrow.turn.up.right")
                                .font(.system(size: 20))
                                .fontWeight(.heavy)
                                .foregroundStyle(.white)
                                .frame(width: 50, height: 50)
                                .background(Color.primaryRed)
                                .clipShape(Circle())
                        }
                    }
                    Text(place.desc)
                    Text("What to do")
                    HStack {
                        
                    }
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
