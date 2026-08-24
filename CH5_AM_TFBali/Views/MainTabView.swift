//
//  MainTabView.swift
//  Jelaja
//
//  Created by Novia Rahman Nisa on 23/08/26.
//

import SwiftUI

enum TabItem: Int, CaseIterable {
    case explore
    case history
    
    var title: String {
        switch self {
        case .explore: return "Explore"
        case .history: return "Memories"
        }
    }
    
    var iconName: String {
        switch self {
        case .explore: return "safari.fill"
        case .history: return "photo"
        }
    }
}

struct MainTabView: View {
    @State private var selectedTab: TabItem = .explore
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Tab 1: Explore / Main Map View
            MainPageView()
                .tabItem {
                    Label(TabItem.explore.title, systemImage: TabItem.explore.iconName)
                }
                .tag(TabItem.explore)
            
            // Tab 2: History List
            HistoryPageView()
                .tabItem {
                    Label(TabItem.history.title, systemImage: TabItem.history.iconName)
                }
                .tag(TabItem.history)
        }
        .tint(Color.accentPurple)
    }
}

#Preview {
    MainTabView()
        .modelContainer(for: [Category.self, Place.self, NavigationSession.self, LandmarkVideo.self], inMemory: true)
}
