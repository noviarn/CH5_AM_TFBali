//
//  TripEstimator.swift
//  CH5_AM_TFBali
//
//  Created by Novia Rahman Nisa on 15/08/26.
//
import Foundation
import CoreLocation

// MARK: - Result type

struct PlaceTripEstimate {
    let duration: String        // formatted, e.g. "3h 20m"
    let busRideCount: Int       // number of distinct route legs taken
    let distanceKm: Double      // distance from user to their nearest boarding stop
}

// MARK: - Internal path representation

/// One leg of a multi-leg trip: ride this direction from boardIndex to alightIndex.
private struct RouteLeg {
    let direction: RouteDirection
    let boardIndex: Int
    let alightIndex: Int
}

// MARK: - Estimator

enum TripEstimator {
    
    /// Average speed assumptions used to convert distance into a time estimate,
    /// since Corridor/RouteDirection data has no built-in travel-time field.
    private static let averageBusSpeedKmh: Double = 20
    private static let averageWalkingSpeedKmh: Double = 4.5
    private static let transferPenaltyMinutes: Double = 5 // wait time per transfer
    
    static func estimateTrip(
        to place: Place,
        from userLocation: CLLocationCoordinate2D,
        corridors: [Corridor]
    ) -> PlaceTripEstimate? {
        
        let placeLocation = CLLocationCoordinate2D(latitude: place.latitude, longitude: place.longitude)
        
        // 1. Find nearest boarding stop to the user, across all directions in all corridors.
        guard let (startStop, startDistance) = nearestStop(to: userLocation, corridors: corridors) else {
            return nil
        }
        
        // 2. Find nearest alighting stop to the place.
        guard let (endStop, _) = nearestStop(to: placeLocation, corridors: corridors) else {
            return nil
        }
        
        // 3. Search for a path of legs connecting startStop -> endStop,
        //    allowing transfers at stops that share the same coordinate across directions.
        guard let legs = findPath(from: startStop, to: endStop, corridors: corridors) else {
            return nil
        }
        
        // 4. Sum estimated time across all legs + transfer penalties.
        let totalMinutes = legs.reduce(0.0) { partial, leg in
            partial + travelTimeMinutes(for: leg)
        } + Double(max(legs.count - 1, 0)) * transferPenaltyMinutes
        
        return PlaceTripEstimate(
            duration: formattedDuration(minutes: totalMinutes),
            busRideCount: legs.count,
            distanceKm: startDistance
        )
    }
    
    // MARK: - Nearest stop lookup
    
    private static func nearestStop(
        to coordinate: CLLocationCoordinate2D,
        corridors: [Corridor]
    ) -> (stop: BusStop, distanceKm: Double)? {
        let target = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        
        var best: (BusStop, Double)?
        for corridor in corridors {
            for direction in corridor.directions {
                for stop in direction.stops {
                    let stopLocation = CLLocation(latitude: stop.coordinate.latitude, longitude: stop.coordinate.longitude)
                    let distanceKm = target.distance(from: stopLocation) / 1000
                    if best == nil || distanceKm < best!.1 {
                        best = (stop, distanceKm)
                    }
                }
            }
        }
        return best
    }
    
    // MARK: - Path search (BFS across directions, transferring at shared-coordinate stops)
    
    private static func findPath(
        from start: BusStop,
        to end: BusStop,
        corridors: [Corridor]
    ) -> [RouteLeg]? {
        // Flatten all directions for easy lookup.
        let allDirections = corridors.flatMap { $0.directions }
        
        // BFS queue: each entry is (current stop, legs taken so far, visited direction IDs to avoid loops)
        var queue: [(stop: BusStop, legs: [RouteLeg])] = [(start, [])]
        var visitedStopKeys: Set<String> = [key(for: start.coordinate)]
        
        while !queue.isEmpty {
            let (currentStop, legs) = queue.removeFirst()
            
            if legs.count > 3 { continue } // cap transfers to keep search bounded
            
            if key(for: currentStop.coordinate) == key(for: end.coordinate) {
                return legs
            }
            
            // Try every direction that contains a stop matching currentStop's coordinate.
            for direction in allDirections {
                guard let boardIndex = direction.stops.firstIndex(where: {
                    key(for: $0.coordinate) == key(for: currentStop.coordinate)
                }) else { continue }
                
                // Ride forward to every subsequent stop on this direction — each is a possible alight point.
                for alightIndex in (boardIndex + 1)..<direction.stops.count {
                    let alightStop = direction.stops[alightIndex]
                    let alightKey = key(for: alightStop.coordinate)
                    if visitedStopKeys.contains(alightKey) { continue }
                    
                    let leg = RouteLeg(direction: direction, boardIndex: boardIndex, alightIndex: alightIndex)
                    visitedStopKeys.insert(alightKey)
                    queue.append((alightStop, legs + [leg]))
                }
            }
        }
        
        return nil // no path found within the transfer cap
    }
    
    private static func key(for coordinate: CLLocationCoordinate2D) -> String {
        // Rounds to ~11m precision so nearly-identical coordinates are treated as the same stop.
        String(format: "%.4f,%.4f", coordinate.latitude, coordinate.longitude)
    }
    
    // MARK: - Time + formatting helpers
    
    private static func travelTimeMinutes(for leg: RouteLeg) -> Double {
        let stops = leg.direction.stops[leg.boardIndex...leg.alightIndex]
        var distanceKm = 0.0
        for i in 0..<(stops.count - 1) {
            let a = CLLocation(latitude: stops[i].coordinate.latitude, longitude: stops[i].coordinate.longitude)
            let b = CLLocation(latitude: stops[i + 1].coordinate.latitude, longitude: stops[i + 1].coordinate.longitude)
            distanceKm += a.distance(from: b) / 1000
        }
        return (distanceKm / averageBusSpeedKmh) * 60
    }
    
    private static func formattedDuration(minutes: Double) -> String {
        let totalMinutes = Int(minutes.rounded())
        let hours = totalMinutes / 60
        let mins = totalMinutes % 60
        if hours > 0 {
            return mins > 0 ? "\(hours)h \(mins)m" : "\(hours)h"
        }
        return "\(mins)m"
    }
}
