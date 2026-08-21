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
            ScrollView(.vertical, showsIndicators: true) {
                VStack(spacing: 25) {
                    VStack(alignment: .leading, spacing: 15) {
                        Text("Places you’ve explored")
                            .font(.system(.title, design: .rounded))
                            .fontWeight(.bold)
                            .frame(width: 200, alignment: .leading)
                        
                        //                        Text("Take a look back at the places you've explored and the memories you've made along the way.")
                        //                            .font(.system(.subheadline, design: .rounded))
                        //                            .fontWeight(.medium)
                        //                            .multilineTextAlignment(.leading)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    LazyVGrid(
                        columns: [
                            GridItem(.flexible(), spacing: 20),
                            GridItem(.flexible(), spacing: 20)
                        ],
                        spacing: 20
                    ) {
                        ForEach(0..<4, id: \.self) { index in
                            HistoryCard(
                                title: "Exploring",
                                date: "8 August 2026"
                            )
                            .scrollClipDisabled()
                        }
                    }
                }
                .padding()
            }
        }
    }
}

#Preview {
    HistoryPageView()
}
