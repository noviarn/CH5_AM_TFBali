//
//  HistoryCard.swift
//  CH5_AM_TFBali
//
//  Created by Novia Rahman Nisa on 16/08/26.
//

import SwiftUI

struct HistoryCard: View {
    let history: HistoryItem
    
    //    let title: String
    //    let date: String
    //    var thumbnailData: Data? = nil
    
    var body: some View {
        ZStack(alignment: .bottom) {
            
            // MARK: - Full Background Image / Video Screenshot
            if let data = history.thumbnailData, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 180, height: 135)
                    .clipped()
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .overlay(Image(systemName: "photo").foregroundStyle(.secondary).font(.system(size: 60)))
            }
            
            // MARK: - Transparent Bottom Overlay
            VStack(alignment: .leading, spacing: 6) {
                
                Text(history.title)
                    .font(.custom("Poppins-Bold", size: 18))
                    .foregroundStyle(.black)
                    .lineLimit(1)
                
                HStack(spacing: 8) {
                    Image(systemName: "calendar")
                        .font(.system(size: 16))
                    
                    Text(history.date, format: .dateTime.day().month(.wide).year())
                        .font(.system(.caption, design: .rounded))
                }
                .foregroundStyle(.secondary)
                .fontWeight(.regular)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 15)
            .padding(.vertical, 10)
            .background(
                Color.white.opacity(0.9)
            )
        }
        .frame(width: 180, height: 160)
        .clipShape(
            RoundedRectangle(cornerRadius: 10)
        )
        .shadow(
            color: .black.opacity(0.2),
            radius: 8,
            x: 0,
            y: 5
        )
    }
}

#Preview {
    HStack(spacing: 15) {
        HistoryCard(
            history: HistoryItem(
                title: "Exploring",
                date: Date()
            )
        )
    }
    .padding()
}
