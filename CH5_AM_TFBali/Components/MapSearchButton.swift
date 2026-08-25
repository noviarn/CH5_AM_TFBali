//
//  MapSearchButton.swift
//  CH5_AM_TFBali
//
//  Created by Novia Rahman Nisa on 17/08/26.
//

import SwiftUI
import MapKit

struct SearchSheet: View {
    @Binding var searchText: String
    let onSelectLandmark: (LandmarkPOI) -> Void
    /// A result outside the curated landmark list — search isn't limited to those 17 places,
    /// this is how anywhere else becomes a reachable destination.
    let onSelectMapItem: (MKMapItem) -> Void
    /// Orders the recommendations by how far they actually are from the rider. Without it the
    /// list was in data-file order, so someone in Kuta was offered Ubud first.
    var userLocation: CLLocationCoordinate2D?
    /// Browse mode keeps this sheet up permanently over the map, so it needs a detent small
    /// enough to leave the map usable. The first/last mile pickers are transient and start at
    /// medium instead.
    var detents: Set<PresentationDetent> = [.medium, .large]
    /// The smallest detent, when there is one. At this size the sheet shrinks to just the
    /// centered search pill and hides the recommendations below.
    var minimizedDetent: PresentationDetent? = nil
    /// Opens with the keyboard already up. The first/last mile pickers are opened *in order
    /// to type* — leaving the field unfocused made that two taps instead of one. Browse mode
    /// leaves this off: that sheet sits over the map to be read, not typed into.
    var autoFocus: Bool = false
    @Environment(\.dismiss) private var dismiss

    @StateObject private var searchService = DestinationSearchService()
    @State private var isResolving = false
    // Opens at medium; the smaller detent (when the set has one) is reached by dragging down.
    @State private var selectedDetent: PresentationDetent = .medium
    @FocusState private var searchFocused: Bool

    /// Every landmark when there's no query yet — a blank search sheet with nothing below
    /// the field reads as broken, so this doubles as "recommended nearby" until the rider
    /// actually types something. Landmarks are shown first and always take the top section:
    /// they're curated and load instantly, where the general search below is neither.
    ///
    /// Nearest first once there's a fix, which is what makes these recommendations rather
    /// than just a list.
    private var filteredLandmarks: [LandmarkPOI] {
        let matches = searchText.isEmpty
            ? landmarkPOIs
            : landmarkPOIs.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        guard let userLocation else { return matches }
        return matches.sorted {
            userLocation.distance(to: $0.coordinate) < userLocation.distance(to: $1.coordinate)
        }
    }

    private func distanceText(to coordinate: CLLocationCoordinate2D) -> String? {
        guard let userLocation else { return nil }
        let metres = userLocation.distance(to: coordinate)
        return metres < 1000
            ? String(format: "%.0f m", metres)
            : String(format: "%.1f km", metres / 1000)
    }

    private var hasNoResults: Bool {
        filteredLandmarks.isEmpty && searchService.suggestions.isEmpty
    }

    private var isMinimized: Bool {
        minimizedDetent != nil && selectedDetent == minimizedDetent && !searchFocused
    }

    /// Capsule to echo the sheet's own rounded shape.
    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField(
                "Search anywhere...",
                text: $searchText
            )
            .focused($searchFocused)
            .onChange(of: searchText) { _, newValue in
                searchService.updateQuery(newValue)
            }

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
        .clipShape(Capsule())
        .padding(.horizontal, 16)
    }

    var body: some View {
        // One tree, deliberately: the field must keep the same structural identity whether
        // the sheet is minimized or open. Putting it in two branches of an if/else gave it
        // two identities, so tapping it while minimized rebuilt the TextField mid-tap and
        // threw the focus away — which is what made typing take two taps.
        VStack(spacing: 0) {
            searchField
                .padding(.top, 8)
                .padding(.bottom, 4)

            if !isMinimized {
                if searchText.isEmpty {
                    SearchRecommendations(userLocation: userLocation) { poi in
                        onSelectLandmark(poi)
                        dismiss()
                    }
                } else if hasNoResults {
                    Spacer()
                    Text("No results found")
                        .foregroundStyle(.secondary)
                    Spacer()
                } else {
                    List {
                        if !filteredLandmarks.isEmpty {
                            Section("Landmarks") {
                                ForEach(filteredLandmarks) { poi in
                                    Button {
                                        Haptics.selection()
                                        onSelectLandmark(poi)
                                        dismiss()
                                    } label: {
                                        HStack(spacing: 12) {
                                            Image(systemName: poi.icon)
                                                .foregroundStyle(.secondary)
                                                .frame(width: 24)
                                            VStack(alignment: .leading, spacing: 1) {
                                                Text(poi.name)
                                                    .foregroundStyle(.primary)
                                                    .lineLimit(1)
                                                Text(poi.category)
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                            }

                                            Spacer(minLength: 8)

                                            if let distance = distanceText(to: poi.coordinate) {
                                                Text(distance)
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        if !searchService.suggestions.isEmpty {
                            Section("Other places") {
                                ForEach(searchService.suggestions, id: \.self) { suggestion in
                                    Button {
                                        Haptics.selection()
                                        resolveAndSelect(suggestion)
                                    } label: {
                                        HStack(spacing: 12) {
                                            Image(systemName: "mappin.circle")
                                                .foregroundStyle(.secondary)
                                                .frame(width: 24)
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(suggestion.title)
                                                    .foregroundStyle(.primary)
                                                if !suggestion.subtitle.isEmpty {
                                                    Text(suggestion.subtitle)
                                                        .font(.caption)
                                                        .foregroundStyle(.secondary)
                                                        .lineLimit(1)
                                                }
                                            }
                                        }
                                    }
                                    .disabled(isResolving)
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                    .environment(\.defaultMinListRowHeight, 44)
                    .scrollContentBackground(.hidden)
                }
            }
        }
        .presentationDetents(detents, selection: $selectedDetent)
        .presentationDragIndicator(.visible)
        .onAppear {
            // `searchText` belongs to the caller and survives the sheet closing, but this
            // sheet — and with it `searchService` — is rebuilt on every presentation. So a
            // restored query has never actually been run, and the sheet would claim "No
            // results found" for a search it never made. Re-run it.
            if !searchText.isEmpty {
                searchService.updateQuery(searchText)
            }
        }
        .task {
            guard autoFocus else { return }
            // Focus set during the sheet's first layout pass is dropped, so this waits a
            // beat for the presentation to settle before asking for the keyboard.
            try? await Task.sleep(for: .milliseconds(350))
            selectedDetent = .large
            searchFocused = true
        }
        .onChange(of: searchFocused) { _, focused in
            // Typing from the minimized pill: grow the sheet so the field lands at the top
            // with room for results, instead of floating centered in the tiny detent.
            if focused, selectedDetent == minimizedDetent {
                selectedDetent = .large
            }
        }
    }

    private func resolveAndSelect(_ suggestion: MKLocalSearchCompletion) {
        isResolving = true
        Task {
            let item = await searchService.resolve(suggestion)
            isResolving = false
            guard let item else { return }
            onSelectMapItem(item)
            dismiss()
        }
    }
}


struct MapSearchButton: View {
    var onSelectLandmark: (LandmarkPOI) -> Void = { _ in }
    var onSelectMapItem: (MKMapItem) -> Void = { _ in }
    var userLocation: CLLocationCoordinate2D?

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
                    Haptics.tap()
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
                    Haptics.tap()
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
            SearchSheet(
                searchText: $searchText,
                onSelectLandmark: onSelectLandmark,
                onSelectMapItem: onSelectMapItem,
                userLocation: userLocation
            )
        }
    }
}


#Preview {
    MapSearchButton()
}
