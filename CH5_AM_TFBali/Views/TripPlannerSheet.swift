import SwiftUI
import MapKit
import CoreLocation

struct TripPlannerSheet: View {
    @Binding var destinationPin: BusStop?
    let onRouteSelected: (TripRoute) -> Void

    @StateObject private var searchService = DestinationSearchService()
    @StateObject private var locationManager = LocationManager()

    @State private var query = ""
    @State private var phase: Phase = .idle
    @State private var routes: [TripRoute] = []

    enum Phase: Equatable {
        case idle, searching, locationDenied, noResults, noRoute, results
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField("Cari tujuan...", text: $query)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal)
                .onChange(of: query) { _, newValue in
                    searchService.updateQuery(newValue)
                }

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

            Spacer()
        }
        .padding(.top, 12)
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
                onRouteSelected(route)
            } label: {
                RouteCard(route: route)
            }
        }
        .listStyle(.plain)
    }

    private func selectDestination(_ suggestion: MKLocalSearchCompletion) async {
        phase = .searching
        guard let mapItem = await searchService.resolve(suggestion) else {
            phase = .noResults
            return
        }
        let destinationCoordinate = mapItem.location.coordinate
        destinationPin = BusStop(name: mapItem.name ?? suggestion.title, coordinate: destinationCoordinate)

        if locationManager.authorizationStatus == .notDetermined {
            locationManager.requestAuthorization()
        }
        guard locationManager.authorizationStatus != .denied,
              let userCoordinate = await locationManager.currentLocation() else {
            phase = .locationDenied
            return
        }

        let originStraightLine = NearestStopFinder.nearestByStraightLine(to: userCoordinate)
        let destinationStraightLine = NearestStopFinder.nearestByStraightLine(to: destinationCoordinate)
        let originRanked = await NearestStopFinder.rankedByWalkingDistance(candidates: originStraightLine, to: userCoordinate)
        let destinationRanked = await NearestStopFinder.rankedByWalkingDistance(candidates: destinationStraightLine, to: destinationCoordinate)

        let found = RoutePlanner.findRoutes(originCandidates: originRanked, destinationCandidates: destinationRanked)
        routes = found
        phase = found.isEmpty ? .noRoute : .results
    }
}

private struct RouteCard: View {
    let route: TripRoute

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                ForEach(Array(route.legs.enumerated()), id: \.offset) { index, leg in
                    if index > 0 {
                        Image(systemName: "arrow.right").font(.caption2)
                    }
                    Text(leg.corridorID)
                        .font(.caption.bold())
                        .padding(.horizontal, 8).padding(.vertical, 2)
                        .background(Color.gray.opacity(0.2))
                        .clipShape(Capsule())
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
}
