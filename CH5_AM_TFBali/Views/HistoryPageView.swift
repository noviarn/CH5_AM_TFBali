//
//  HistoryPageView.swift
//  CH5_AM_TFBali
//
//  Created by Novia Rahman Nisa on 15/08/26.
//

import SwiftUI
import SwiftData

struct HistoryPageView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]
    
    private var historyItems: [HistoryItem] {
        (profiles.first?.historyItems ?? []).sorted { $0.date > $1.date }
    }
    
    var body: some View {
        ZStack {
            Color.appBackground
                .ignoresSafeArea()
            
            VStack(alignment: .leading, spacing: 20) {
                Text("Places You've Explored")
                    .font(.system(.largeTitle, design: .rounded))
                    .fontWeight(.bold)
                    .foregroundStyle(Color.black)
                
                if historyItems.isEmpty {
                    emptyState
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVGrid(
                            columns: [
                                GridItem(.flexible(), spacing: 20),
                                GridItem(.flexible(), spacing: 20)
                            ], spacing: 20
                        ) {
                            ForEach(historyItems) { item in
                                NavigationLink {
                                    // some detail destination
                                } label: {
                                    HistoryCard(history: item)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .scrollClipDisabled()
                }
            }
            .padding(20)
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 0) {
            Image("history-placeholder")
                .resizable()
                .scaledToFit()
                .frame(width: 150)
            
            Text("Your memories will live here")
                .font(.system(.title3, design: .rounded))
                .fontWeight(.semibold)
                .foregroundStyle(Color.primaryPurple)
                .multilineTextAlignment(.center)
                .padding(.top, 15)
            
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
        .background(Color.secondaryPurple)
        .overlay(
            RoundedRectangle(cornerRadius: 15)
                .stroke(
                    Color.primaryPurple,
                    style: StrokeStyle(lineWidth: 1.5, dash: [7, 7])
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 15))
    }
}

#Preview {
    HistoryPageView()
}
