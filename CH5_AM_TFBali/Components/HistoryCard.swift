//
//  HistoryCard.swift
//  CH5_AM_TFBali
//
//  Created by Novia Rahman Nisa on 16/08/26.
//

import SwiftUI

struct HistoryCard: View {
    let date: Date
    let isAlternate: Bool
    
    var body: some View {
        ZStack {
            Image(isAlternate ? "orange-history-note" : "purple-history-note")
            
            HStack(spacing: 4) {
                Image(systemName: "calendar")
                    .font(.system(.caption))
                Text(date, format: .dateTime.day().month(.wide).year())
                    .font(.system(.caption, design: .rounded))
            }
            .frame(width: 125)
            .padding(.vertical, 6)
            .background(Color.creamText)
            .clipShape(Capsule())
            .foregroundStyle(Color.deepPrimaryPurple)
            .offset(y: 55)
        }
        .shadow(color: Color.black.opacity(0.25), radius: 4, x: 4, y: 4)
    }
}

#Preview {
    HStack(spacing: 15) {
        HistoryCard(date: .now, isAlternate: false)
        HistoryCard(date: .now, isAlternate: true)
    }
    .padding()
}
