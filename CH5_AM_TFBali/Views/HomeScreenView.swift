//
//  HomeScreenView.swift
//  CH5_AM_TFBali
//
//  Created by Novia Rahman Nisa on 14/08/26.
//

import SwiftUI

struct HomeScreenView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground
                    .ignoresSafeArea()
                ScrollView(.vertical, showsIndicators: true) {
                    VStack {
                        VStack(spacing: 20) {
                            Text("Hi! I'm your local guide")
                                .font(.system(.title, design: .rounded))
                                .fontWeight(.bold)
                                .foregroundStyle(.black)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            HStack {
                                Spacer()
                                NavigationLink {
                                    // user's location selection screen tba
                                } label: {
                                    HStack(spacing: 5) {
                                        Image(systemName: "mappin.and.ellipse")
                                            .font(.system(size: 16))
                                        Text("Tuban")
                                            .font(.system(.body, design: .rounded))
                                            .fontWeight(.semibold)
                                    }
                                    .padding(.horizontal, 15)
                                    .padding(.vertical, 8)
                                    .foregroundStyle(.white)
                                    .background(Color.primaryPurple)
                                    .clipShape(Capsule())
                                }
                            }
                            ZStack(alignment: .bottom) {
                                Image("home-image-1")
                                NavigationLink {
                                    // tba
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
                                Spacer()
                                NavigationLink {
                                    // tba
                                } label: {
                                    Text("See all")
                                        .font(.system(.caption, design: .rounded))
                                        .fontWeight(.semibold)
                                        .foregroundStyle(Color.secondaryText)
                                }
                            }
                            HStack(spacing: 20) {
                                ForEach(0..<4, id: \.self) { _ in
                                    NavigationLink {
                                        // tba
                                    } label: {
                                        VStack {
                                            Circle()
                                                .frame(width: 65, height: 65)
                                                .foregroundStyle(Color.primaryPurple)
                                            Text("Category")
                                                .font(.system(.caption, design: .rounded))
                                                .fontWeight(.regular)
                                                .foregroundStyle(Color.black)
                                        }
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.top, 15)
                        VStack(spacing: -15) {
                            HStack {
                                Text("Popular Places")
                                    .font(.system(.title3, design: .rounded))
                                    .fontWeight(.bold)
                                    .foregroundStyle(.primary)
                                Spacer()
                                NavigationLink {
                                    // tba
                                } label: {
                                    Text("See all")
                                        .font(.system(.caption, design: .rounded))
                                        .fontWeight(.semibold)
                                        .foregroundStyle(Color.secondaryText)
                                }
                            }
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 20) {
                                    ForEach(0..<2, id: \.self) { _ in
                                        ZStack(alignment: .leading) {
                                            RoundedRectangle(cornerRadius: 25)
                                                .fill(Color.deepPrimaryPurple)
                                                .frame(width: 330, height: 170)
                                                .offset(y: 25)
                                            Image("placeholder-default")
                                                .resizable()
                                                .frame(width: 110, height: 120)
                                                .clipShape(RoundedRectangle(cornerRadius: 25))
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 25)
                                                        .stroke(Color.secondaryPurple, lineWidth: 4)
                                                )
                                                .offset(x: 20, y: -15)
                                            Text("Popular Title")
                                                .font(.custom("Poppins-Bold", size: 18))
                                                .foregroundStyle(Color.creamText)
                                                .frame(width: 160, alignment: .leading)
                                                .multilineTextAlignment(.leading)
                                                .lineLimit(1)
                                                .offset(x: 145, y: -25)
                                            Text("Lorem ipsum dolor sit amet, consectetur adipiscing elit. Donec at massa sit amet risus hendrerit")
                                                .font(.system(.caption, design: .rounded))
                                                .foregroundStyle(Color.creamText)
                                                .frame(width: 170, alignment: .leading)
                                                .lineLimit(2)
                                                .offset(x: 145, y: 5)
                                            HStack(spacing: 10) {
                                                HStack(spacing: 3) {
                                                    Image(systemName: "clock.fill")
                                                    Text("3h")
                                                }
                                                HStack(spacing: 3) {
                                                    Image(systemName: "bus")
                                                    Text("3 bus rides")
                                                }
                                                HStack(spacing: 3) {
                                                    Image(systemName: "location.fill")
                                                    Text("500m")
                                                }
                                            }
                                            .font(.system(.caption2, design: .rounded))
                                            .foregroundStyle(Color.creamText)
                                            .fixedSize(horizontal: true, vertical: false)
                                            .offset(x: 145, y: 35)
                                            NavigationLink {
                                                // tba
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
                                Spacer()
                                NavigationLink {
                                    // tba
                                } label: {
                                    Image(systemName: "chevron.right")
                                        .font(.system(.title3))
                                        .fontWeight(.semibold)
                                        .foregroundStyle(Color.secondaryText)
                                }
                            }
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 15) {
                                    ForEach(0..<2, id: \.self) { _ in
                                        ZStack {
                                            Image("orange-history-note")
                                            HStack(spacing: 4) {
                                                Image(systemName: "calendar")
                                                    .font(.system(.caption))
                                                Text("15 August 2026")
                                                    .font(.system(.caption, design: .rounded))
                                            }
                                            .frame(width: 125)
                                            .padding(.vertical, 6)
                                            .background(Color.creamText)
                                            .clipShape(Capsule())
                                            .foregroundStyle(Color.deepPrimaryPurple)
                                            .offset(y: 50)
                                        }
                                        
                                        ZStack {
                                            Image("purple-history-note")
                                            HStack(spacing: 4) {
                                                Image(systemName: "calendar")
                                                    .font(.system(.caption))
                                                Text("15 August 2026")
                                                    .font(.system(.caption, design: .rounded))
                                            }
                                            .frame(width: 125)
                                            .padding(.vertical, 6)
                                            .background(Color.creamText)
                                            .clipShape(Capsule())
                                            .foregroundStyle(Color.deepPrimaryPurple)
                                            .offset(y: 50)
                                        }
                                    }
                                }
                            }
                            .scrollClipDisabled()
                        }
                        .padding(.top, 15)
                    }
                    .padding()
                }
            }
        }
    }
}

#Preview {
    HomeScreenView()
}
