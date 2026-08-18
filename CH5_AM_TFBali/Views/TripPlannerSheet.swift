import SwiftUI
import MapKit
import CoreLocation

struct TripPlannerSheet: View {
    @Binding var destinationPin: BusStop?
    @Binding var sheetDetent: PresentationDetent
    let onRouteSelected: (TripRoute) -> Void

    @FocusState private var searchFocused: Bool

    @StateObject private var searchService = DestinationSearchService()
    @StateObject private var locationManager = LocationManager()

    @State private var query = ""
    @State private var phase: Phase = .idle
    @State private var routes: [TripRoute] = []
    @State private var searchGeneration = 0

    enum Phase: Equatable {
        case idle, searching, locationDenied, noResults, noRoute, results
    }

    private let maxWalkMeters: CLLocationDistance = 2000

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            searchField

            if locationManager.hasReducedAccuracy {
                Label("Lokasi presisi mati — titik awal bisa meleset. Aktifkan di Pengaturan › Privasi › Lokasi.", systemImage: "location.slash")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
            }

            Group {
                switch phase {
                case .idle:
                    if !searchService.suggestions.isEmpty {
                        suggestionList
                    }
                case .searching:
                    ProgressView().frame(maxWidth: .infinity)
                case .locationDenied:
                    Text("Aktifkan akses lokasi di Pengaturan untuk pakai fitur pencarian rute.")
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)
                case .noResults:
                    Text("Gak ada hasil untuk \"\(query)\".")
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)
                case .noRoute:
                    Text("Rute belum ditemukan dari sini.")
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)
                case .results:
                    routeList
                }
            }
            .transition(.opacity)
            .animation(.easeInOut(duration: 0.22), value: phase)

            Spacer()
        }
        // Vertical position of the search bar inside the collapsed sheet: raise this to push
        // the bar down, lower it to pull it up. Sized against RouteMapView.collapsedSheetHeight.
        .padding(.top, 23)
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 17))
                .foregroundStyle(.secondary)
            TextField("Cari tujuan", text: $query)
                .textFieldStyle(.plain)
                .focused($searchFocused)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.words)
                .submitLabel(.search)
                .onChange(of: query) { _, newValue in
                    phase = .idle
                    searchService.updateQuery(newValue)
                }
                .onChange(of: searchFocused) { _, isFocused in
                    // Tapping the field lifts the sheet, the way Apple Maps does — otherwise the
                    // field sits at the very bottom with the results hidden below the fold.
                    guard isFocused else { return }
                    withAnimation { sheetDetent = .medium }
                }
            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 17))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        // Capsule, not a rounded rect — it echoes the sheet's own corner curve, the way
        // Apple Maps' field does.
        .frame(height: 44)
        .glassEffect(.regular, in: .capsule)
        .contentShape(Capsule())
        // Whole capsule is the tap target, not just the text — tapping it lifts the sheet and
        // starts editing, the way Apple Maps' collapsed search bar behaves.
        .onTapGesture {
            withAnimation { sheetDetent = .medium }
            searchFocused = true
        }
        .padding(.horizontal)
    }

    private var suggestionList: some View {
        List(searchService.suggestions, id: \.self) { suggestion in
            Button {
                Task { await selectDestination(suggestion) }
            } label: {
                VStack(alignment: .leading) {
                    Text(suggestion.title)
                    Text(suggestion.subtitle).font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .listStyle(.plain)
    }

    private var routeList: some View {
        List(routes) { route in
            Button {
                searchFocused = false
                onRouteSelected(route)
            } label: {
                RouteCard(route: route)
            }
        }
        .listStyle(.plain)
    }

    private func selectDestination(_ suggestion: MKLocalSearchCompletion) async {
        searchGeneration += 1
        let myGeneration = searchGeneration
        phase = .searching

        guard let mapItem = await searchService.resolve(suggestion) else {
            guard myGeneration == searchGeneration else { return }
            phase = .noResults
            return
        }
        guard myGeneration == searchGeneration else { return }
        let destinationCoordinate = mapItem.location.coordinate
        destinationPin = BusStop(name: mapItem.name ?? suggestion.title, coordinate: destinationCoordinate)

        if locationManager.authorizationStatus == .notDetermined {
            locationManager.requestAuthorization()
        }
        guard locationManager.authorizationStatus != .denied,
              let userCoordinate = await locationManager.currentLocation() else {
            guard myGeneration == searchGeneration else { return }
            phase = .locationDenied
            return
        }
        guard myGeneration == searchGeneration else { return }

        let originStraightLine = NearestStopFinder.nearestByStraightLine(to: userCoordinate)
        let destinationStraightLine = NearestStopFinder.nearestByStraightLine(to: destinationCoordinate)
        async let originRankedTask = NearestStopFinder.rankedByWalkingDistance(candidates: originStraightLine, to: userCoordinate)
        async let destinationRankedTask = NearestStopFinder.rankedByWalkingDistance(candidates: destinationStraightLine, to: destinationCoordinate)
        let (originRankedRaw, destinationRankedRaw) = await (originRankedTask, destinationRankedTask)
        guard myGeneration == searchGeneration else { return }

        let originRanked = originRankedRaw.filter { $0.walkingDistance <= maxWalkMeters }
        let destinationRanked = destinationRankedRaw.filter { $0.walkingDistance <= maxWalkMeters }

        let found = RoutePlanner.findRoutes(originCandidates: originRanked, destinationCandidates: destinationRanked)
        routes = found
        phase = found.isEmpty ? .noRoute : .results
    }
}

private struct RouteCard: View {
    let route: TripRoute

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(route.legs.enumerated()), id: \.offset) { _, leg in
                HStack(spacing: 6) {
                    Text(leg.corridorID)
                        .font(.caption.bold())
                        .padding(.horizontal, 8).padding(.vertical, 2)
                        .background(Color.gray.opacity(0.2))
                        .clipShape(Capsule())
                    Text(directionLabel(for: leg))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text("\(leg.boardStop.name) → \(leg.alightStop.name)")
                        .font(.caption2)
                        .lineLimit(1)
                }
            }
            Text("\(Int(route.walkToFirstStop))m jalan → naik → \(Int(route.walkFromLastStop))m jalan ke tujuan")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(route.transferCount == 0 ? "Langsung" : "\(route.transferCount)x transfer")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    private func directionLabel(for leg: TripLeg) -> String {
        guard let corridor = corridors.first(where: { $0.id == leg.corridorID }),
              let index = corridor.directions.firstIndex(where: { $0.id == leg.directionID }) else {
            return ""
        }
        if corridor.directions.count == 2 {
            return index == 0 ? "Pergi" : "Pulang"
        }
        return "Leg \(index + 1)"
    }
}
