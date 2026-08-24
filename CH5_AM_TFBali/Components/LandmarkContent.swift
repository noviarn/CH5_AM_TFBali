//
//  LandmarkContent.swift
//  CH5_AM_TFBali
//
//  Created by Novia Rahman Nisa on 20/08/26.
//

import SwiftUI

struct LandmarkContent: View {
    let landmark: LandmarkPOI
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // MARK: - Summary
                VStack(alignment: .leading, spacing: 8) {
                    Text(landmark.summary)
                        .font(.system(.body, design: .rounded))
                        .fontWeight(.regular)
                        .foregroundStyle(Color.black)
                }
                
                Divider()
                
                // MARK: - Things To Do Section
                if !landmark.activities.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("What to Do")
                            .font(.system(.title3, design: .rounded))
                            .fontWeight(.bold)
                            .foregroundStyle(Color.primaryPurple)
                            .textCase(.uppercase)
                        
                        ForEach(landmark.activities, id: \.self) { activity in
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(Color.primaryOrange)
                                    .font(.system(size: 16))
                                
                                //                                Text(activity)
                                //                                    .font(.system(.subheadline, design: .rounded))
                                //                                    .foregroundStyle(Color.primaryPurple)
                            }
                        }
                    }
                }
                
                // MARK: - Fun Fact / Local Insight
                if let funFact = landmark.funFact {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 6) {
                            Image(systemName: "lightbulb.fill")
                                .foregroundStyle(Color.primaryOrange)
                            
                            Text(landmark.funFactTitle ?? "Did You Know?")
                                .font(.system(.subheadline, design: .rounded))
                                .fontWeight(.bold)
                                .foregroundStyle(Color.primaryPurple)
                        }
                        
                        Text(funFact)
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.primaryOrange.opacity(0.1))
                    .cornerRadius(12)
                }
            }
            .padding()
        }
    }
}

#Preview {
    LandmarkContent(
        landmark: LandmarkPOI(
            name: "Badung Market",
            latitude: -8.6586,
            longitude: 115.2117,
            category: "Market",
            corridorIDs: ["K1", "K2"],
            summary: "Denpasar's largest traditional night market featuring local food, fresh produce, and handmade crafts.",
            activities: [
                Activities(text: "Lorem ipsum dolor sit amet, consectetur adipiscing elit", icon: "placeholdertext.fill")
            ],
            funFactTitle: "Historical Market",
            funFact: "Badung Market is one of the oldest running public markets in Bali, operating continuously across day and night shifts."
        )
    )
}
