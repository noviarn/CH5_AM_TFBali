//
//  HistoryPageView.swift
//  CH5_AM_TFBali
//
//  Created by Novia Rahman Nisa on 15/08/26.
//

import SwiftUI

struct HistoryPageView: View {
    var body: some View {
        ZStack {
            Color.appBackground
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                
                // MARK: - Page Title
                HStack {
                    Text("Places You've Explored")
                        .font(.system(.largeTitle, design: .rounded))
                        .fontWeight(.bold)
                        .foregroundStyle(Color.black)
                    
                    Spacer()
                }
                
                // MARK: - Empty History Content
                VStack {
                    VStack(spacing: 0) {
                        
                        // Camera Illustration
                        Image("history-placeholder")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 150)
                        
                        // Title
                        Text("Your memories will live here")
                            .font(.system(.title3, design: .rounded))
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.primaryPurple)
                            .multilineTextAlignment(.center)
                            .padding(.top, 15)
                        
                        // Description
                        Text("""
                        Explore a place and take your first video.
                        Your daily trips will be saved here.
                        """)
                        .font(.system(.body, design: .rounded))
                        .foregroundStyle(Color.primaryPurple)
                        .fontWeight(.regular)
                        .multilineTextAlignment(.center)
                        .lineSpacing(2)
                        .padding(.top, 15)
                        
                        // Explore Button
                        NavigationLink {
                            RouteMapView()
                        } label: {
                            Text("Explore Nearby")
                                .font(.system(.body, design: .rounded))
                                .fontWeight(.semibold)
                                .foregroundStyle(.white)
                                .padding(.vertical, 10)
                                .padding(.horizontal, 20)
                                .background(Color.primaryOrange)
                                .clipShape(Capsule())
                        }
                        .padding(.top, 25)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 25)
                    .background(
                        Color.secondaryPurple
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 15)
                            .stroke(
                                Color.primaryPurple,
                                style: StrokeStyle(
                                    lineWidth: 1.5,
                                    dash: [7, 7]
                                )
                            )
                    )
                    .clipShape(
                        RoundedRectangle(cornerRadius: 15)
                    )
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .padding(20)
        }
        //        ZStack {
        //            Color.appBackground
        //                .ignoresSafeArea()
        //            ScrollView(.vertical, showsIndicators: true) {
        //                VStack(spacing: 25) {
        //                    VStack(alignment: .leading, spacing: 15) {
        //                        Text("Places you’ve explored")
        //                            .font(.system(.title, design: .rounded))
        //                            .fontWeight(.bold)
        //                            .frame(width: 200, alignment: .leading)
        //
        //                        //                        Text("Take a look back at the places you've explored and the memories you've made along the way.")
        //                        //                            .font(.system(.subheadline, design: .rounded))
        //                        //                            .fontWeight(.medium)
        //                        //                            .multilineTextAlignment(.leading)
        //                    }
        //                    .frame(maxWidth: .infinity, alignment: .leading)
        //                    LazyVGrid(
        //                        columns: [
        //                            GridItem(.flexible(), spacing: 20),
        //                            GridItem(.flexible(), spacing: 20)
        //                        ],
        //                        spacing: 20
        //                    ) {
        //                        ForEach(0..<4, id: \.self) { index in
        //                            HistoryCard(
        //                                title: "Exploring",
        //                                date: "8 August 2026"
        //                            )
        //                            .scrollClipDisabled()
        //                        }
        //                    }
        //                }
        //                .padding()
        //            }
        //        }
    }
}

#Preview {
    HistoryPageView()
}
