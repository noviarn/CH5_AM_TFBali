//
//  MapSearchButton.swift
//  CH5_AM_TFBali
//
//  Created by Novia Rahman Nisa on 17/08/26.
//

import SwiftUI

struct SearchSheet: View {
    @Binding var searchText: String
    let onSelectLandmark: (LandmarkPOI) -> Void
    @Environment(\.dismiss) private var dismiss

    /// Every landmark when there's no query yet — a blank search sheet with nothing below
    /// the field reads as broken, so this doubles as "recommended nearby" until the rider
    /// actually types something.
    private var filteredLandmarks: [LandmarkPOI] {
        guard !searchText.isEmpty else { return landmarkPOIs }
        return landmarkPOIs.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)

                    TextField(
                        "Search landmarks...",
                        text: $searchText
                    )

                    Button {
                        // Voice search - TBA
                    } label: {
                        Image(systemName: "mic.fill")
                            .foregroundStyle(Color.secondary)
                    }
                }
                .padding(.horizontal, 15)
                .padding(.vertical, 12)
                .background(Color.gray.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 15))
                .padding()

                if filteredLandmarks.isEmpty {
                    Spacer()
                    Text("No landmarks found")
                        .foregroundStyle(.secondary)
                    Spacer()
                } else {
                    List {
                        Section(searchText.isEmpty ? "Recommended" : "Results") {
                            ForEach(filteredLandmarks) { poi in
                                Button {
                                    onSelectLandmark(poi)
                                    dismiss()
                                } label: {
                                    HStack(spacing: 12) {
                                        Image(systemName: poi.icon)
                                            .foregroundStyle(.secondary)
                                            .frame(width: 24)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(poi.name)
                                                .foregroundStyle(.primary)
                                            Text(poi.category)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Search")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium, .large])
    }
}


struct MapSearchButton: View {
    var onSelectLandmark: (LandmarkPOI) -> Void = { _ in }

    @State private var isExpanded = false
    @State private var showSearchSheet = false
    @State private var searchText = ""

    var body: some View {
        HStack(spacing: 8) {

            if isExpanded {
                // Search icon
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)

                // Search field
                Button {
                    showSearchSheet = true
                } label: {
                    HStack {
                        Text(
                            searchText.isEmpty
                            ? "Search"
                            : searchText
                        )
                        .foregroundStyle(
                            searchText.isEmpty
                            ? .secondary
                            : .primary
                        )

                        Spacer()
                    }
                }

                // Mic button
                Button {
                    // Voice search - TBA
                } label: {
                    Image(systemName: "mic.fill")
                        .foregroundStyle(Color.secondary)
                        .frame(width: 30, height: 30)
                }

            } else {
                // Initial search button
                Button {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        isExpanded = true
                    }
                } label: {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(Color.black)
                }
            }
        }
        .padding(.horizontal, 10)
        .frame(
            width: isExpanded ? 300 : 58,
            height: 58
        )
        .background(.white)
        .clipShape(Capsule())
        .shadow(
            color: .black.opacity(0.15),
            radius: 8,
            x: 0,
            y: 3
        )
        .animation(
            .easeInOut(duration: 0.25),
            value: isExpanded
        )
        .sheet(isPresented: $showSearchSheet) {
            SearchSheet(searchText: $searchText, onSelectLandmark: onSelectLandmark)
        }
    }
}


#Preview {
    MapSearchButton()
}
