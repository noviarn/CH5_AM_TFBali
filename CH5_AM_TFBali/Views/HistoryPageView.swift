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

                        Text("Take a look back at the places you've explored and the memories you've made along the way.")
                            .font(.system(.subheadline, design: .rounded))
                            .fontWeight(.medium)
                            .multilineTextAlignment(.leading)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    LazyVGrid(
                        columns: [
                            GridItem(.flexible(), spacing: 20),
                            GridItem(.flexible(), spacing: 20)
                        ],
                        spacing: 20
                    ) {
                        ForEach(0..<6, id: \.self) { index in
                            ZStack {
                                Image(
                                    index == 5
                                        ? "purple-history-note"
                                        : [
                                            "orange-history-note",
                                            "purple-history-note",
                                            "purple-history-note",
                                            "orange-history-note",
                                            "orange-history-note"
                                        ][index]
                                )
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
                                .offset(y: 55)
                            }
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
