//
//  HistoryPageView.swift
//  CH5_AM_TFBali
//
//  Created by Novia Rahman Nisa on 15/08/26.
//

import SwiftUI
import SwiftData

struct HistoryPageView: View {
    /// Finished trips only. A session without `endedAt` is one the app was killed during and
    /// `ContentView` is about to resume — it has no distance or landmarks worth showing yet.
    @Query(
        filter: #Predicate<NavigationSession> { $0.endedAt != nil },
        sort: \NavigationSession.startedAt,
        order: .reverse
    )
    private var sessions: [NavigationSession]

    var body: some View {
        ZStack {
            Color.appBackground
                .ignoresSafeArea()
            ScrollView(.vertical, showsIndicators: true) {
                VStack(spacing: 25) {
                    VStack(alignment: .leading, spacing: 15) {
                        Text("Places you've explored")
                            .font(.system(.title, design: .rounded))
                            .fontWeight(.bold)
                            .frame(width: 200, alignment: .leading)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    if sessions.isEmpty {
                        ContentUnavailableView(
                            "No trips yet",
                            systemImage: "figure.walk.motion",
                            description: Text("Take a bus somewhere and it'll show up here.")
                        )
                        .padding(.top, 40)
                    } else {
                        LazyVGrid(
                            columns: [
                                GridItem(.flexible(), spacing: 20),
                                GridItem(.flexible(), spacing: 20)
                            ],
                            spacing: 20
                        ) {
                            ForEach(sessions) { session in
                                NavigationLink {
                                    HistoryDetailView(session: session)
                                } label: {
                                    HistoryCard(
                                        title: HistoryCard.title(for: session),
                                        date: session.startedAt.formatted(.dateTime.day().month(.wide).year())
                                    )
                                }
                                .buttonStyle(.plain)
                                .simultaneousGesture(TapGesture().onEnded { Haptics.tap() })
                                .scrollClipDisabled()
                            }
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
