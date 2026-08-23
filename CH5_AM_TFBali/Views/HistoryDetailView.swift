//
//  HistoryDetailView.swift
//  CH5_AM_TFBali
//
//  Created by Novia Rahman Nisa on 15/08/26.
//

import SwiftUI

struct DummyPlace: Identifiable {
    let id = UUID()
    let name: String
    let image: String
    let color: Color
}

struct DummyMoment: Identifiable {
    let id = UUID()
    let title: String
    let image: String
}

struct RouteBadge: View {
    let code: String
    let color: Color
    
    var body: some View {
        Text(code)
            .font(.system(.caption, design: .rounded))
            .fontWeight(.medium)
            .foregroundStyle(.white)
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .background(color, in: RoundedRectangle(cornerRadius: 5))
    }
}

private struct StatItem: View {
    let label: String
    let icon: String
    let value: String
    
    var body: some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(.secondary)
            
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(.body, weight: .medium))
                Text(value)
                    .font(.system(.body, design: .rounded))
                    .fontWeight(.semibold)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

struct HistoryDetailView: View {
    @State private var isEditing = false
    @State private var tripTitle = "13 August 2026"
    
    private let places: [DummyPlace] = [
        DummyPlace(
            name: "Dewa Ruci Statue",
            image: "placeholder-default",
            color: .orange
        ),
        DummyPlace(
            name: "Lumintang Park",
            image: "placeholder-default",
            color: .orange
        ),
        DummyPlace(
            name: "Bajra Sandhi\nMonument",
            image: "placeholder-default",
            color: .blue
        ),
        DummyPlace(
            name: "Kuta Beach",
            image: "placeholder-default",
            color: .green
        ),
        DummyPlace(
            name: "Sanur Beach",
            image: "placeholder-default",
            color: .blue
        ),
        DummyPlace(
            name: "Satria Gatotkaca\nPark",
            image: "placeholder-default",
            color: .orange
        ),
        DummyPlace(
            name: "Pura Adat Kuta",
            image: "placeholder-default",
            color: .green
        ),
        DummyPlace(
            name: "Kelan Beach",
            image: "placeholder-default",
            color: .green
        )
    ]
    
    private let moments: [DummyMoment] = [
        DummyMoment(
            title: "Bajra Sandhi Monument",
            image: "placeholder-default"
        )
    ]
    
    var body: some View {
        ZStack {
            Color.appBackground
                .ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 15) {
                    if isEditing {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Change your trip's title?")
                                .font(.system(.caption2, design: .rounded))
                                .fontWeight(.semibold)
                                .foregroundStyle(Color.primaryPurple)
                            TextField("Trip title", text: $tripTitle)
                                .font(.system(.title, design: .rounded))
                                .fontWeight(.bold)
                                .foregroundStyle(Color.black)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(Color.textMuted.opacity(0.15))
                                )
                        }
                    } else {
                        Text(tripTitle)
                            .font(.system(.title, design: .rounded))
                            .fontWeight(.bold)
                            .foregroundStyle(Color.black)
                    }
                    HStack(spacing: 8) {
                        HStack(spacing: 4) {
                            Image(systemName: "calendar")
                                .font(.system(.body, weight: .medium))
                            Text("Aug 13, 2026")
                                .font(.system(.caption, design: .rounded))
                                .fontWeight(.regular)
                        }
                        Text("•")
                            .font(.body)
                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                                .font(.system(.body, weight: .medium))
                            Text("3h 20m")
                                .font(.system(.caption, design: .rounded))
                        }
                        Text("•")
                            .font(.body)
                        HStack(spacing: 5) {
                            Image(systemName: "bus.fill")
                                .font(.system(.body, weight: .medium))
                            RouteBadge(code: "K5B", color: .routeK5B)
                            RouteBadge(code: "K3B", color: .routeK3B)
                            RouteBadge(code: "K4B", color: .routeK4B)
                        }
                    }
                    .foregroundStyle(Color.textMuted)
                    HStack(spacing: 0) {
                        VStack(spacing: 6) {
                            Text("Places Visited")
                                .font(.system(.caption, weight: .semibold))
                            HStack(spacing: 6) {
                                Image(systemName: "mappin.and.ellipse")
                                    .font(.system(.body, weight: .medium))
                                Text("5")
                                    .font(.system(.body, design: .rounded))
                                    .fontWeight(.semibold)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        Divider()
                            .frame(height: 45)
                        VStack(spacing: 6) {
                            Text("Moments")
                                .font(.system(.caption, weight: .semibold))
                            HStack(spacing: 6) {
                                Image(systemName: "video")
                                    .font(.system(.body, weight: .medium))
                                Text("7")
                                    .font(.system(.body, design: .rounded))
                                    .fontWeight(.semibold)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        Divider()
                            .frame(height: 45)
                        VStack(spacing: 6) {
                            Text("Distance")
                                .font(.system(.caption, weight: .semibold))
                            HStack(spacing: 6) {
                                Image(systemName: "point.bottomleft.forward.to.arrow.triangle.uturn.scurvepath.fill")
                                    .font(.system(.body, weight: .medium))
                                Text("17km")
                                    .font(.system(.body, design: .rounded))
                                    .fontWeight(.semibold)
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .padding(.vertical, 12)
                    .foregroundStyle(.primaryPurple)
                    .background(Color.secondaryPurple.opacity(0.45))
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .shadow(
                        color: .black.opacity(0.25),
                        radius: 2,
                        x: 2,
                        y: 2
                    )
                }
                placesSection
                momentsSection
            }
            .padding(.horizontal, 20)
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if isEditing {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isEditing.toggle()
                        }
                    } label: {
                        Image(systemName: "checkmark")
                            .font(.system(.body, design: .rounded))
                            .fontWeight(.semibold)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.primaryOrange)
                    .foregroundStyle(.white)
                    .accessibilityLabel(Text("Done editing"))
                } else {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isEditing.toggle()
                        }
                    } label: {
                        Image(systemName: "pencil")
                            .font(.system(.body, design: .rounded))
                            .fontWeight(.semibold)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.black)
                    .accessibilityLabel(Text("Edit page"))
                }
            }
        }
    }
}

// MARK: - Places Section

private extension HistoryDetailView {
    
    var placesSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            
            Text("Places You Passed")
                .font(.system(.title3, design: .rounded))
                .fontWeight(.bold)
                .foregroundStyle(.black)
            
            ZStack {
                
                // Dotted route
                //                dottedRoute
                
                // Places
                LazyVGrid(
                    columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ],
                    spacing: 25
                ) {
                    ForEach(places) { place in
                        placeItem(place)
                    }
                }
            }
        }
        .padding(.top, 18)
    }
    
    //    var dottedRoute: some View {
    //        GeometryReader { geo in
    //            let columnWidth = (geo.size.width - (25 * 2)) / 3  // 3 columns, 2 gaps of 25pt
    //            let col0X = columnWidth / 2
    //            let col1X = columnWidth + 25 + columnWidth / 2
    //            let col2X = (columnWidth + 25) * 2 + columnWidth / 2
    //
    //            let circleRadius: CGFloat = 37.5 // half of 75pt circle
    //            let cellHeight: CGFloat = 75 + 6 + 32 // circle + spacing + text frame height
    //            let rowGap: CGFloat = 25 // LazyVGrid row spacing
    //
    //            let row0Y = circleRadius
    //            let row1Y = cellHeight + rowGap + circleRadius
    //            let row2Y = (cellHeight + rowGap) * 2 + circleRadius
    //
    //            Path { path in
    //                // Row 1: left → right
    //                path.move(to: CGPoint(x: col0X, y: row0Y))
    //                path.addLine(to: CGPoint(x: col1X, y: row0Y))
    //                path.addLine(to: CGPoint(x: col2X, y: row0Y))
    //
    //                // Down right edge
    //                path.move(to: CGPoint(x: col2X, y: row0Y))
    //                path.addCurve(
    //                    to: CGPoint(x: col2X, y: row1Y),
    //                    control1: CGPoint(x: col2X + 55, y: row0Y + 25),
    //                    control2: CGPoint(x: col2X + 55, y: row1Y - 25)
    //                )
    //
    //                // Row 2: right → left
    //                path.move(to: CGPoint(x: col2X, y: row1Y))
    //                path.addLine(to: CGPoint(x: col1X, y: row1Y))
    //                path.addLine(to: CGPoint(x: col0X, y: row1Y))
    //
    //                // Down left edge
    //                path.move(to: CGPoint(x: col0X, y: row1Y))
    //                path.addCurve(
    //                    to: CGPoint(x: col0X, y: row2Y),
    //                    control1: CGPoint(x: col0X - 55, y: row1Y + 25),
    //                    control2: CGPoint(x: col0X - 55, y: row2Y - 25)
    //                )
    //
    //                // Row 3: left → right (partial, matches your original 2-point row)
    //                path.move(to: CGPoint(x: col0X, y: row2Y))
    //                path.addLine(to: CGPoint(x: col1X, y: row2Y))
    //            }
    //            .stroke(
    //                Color.gray,
    //                style: StrokeStyle(lineWidth: 2, dash: [4, 5])
    //            )
    //        }
    //        .frame(height: 330)
    //        .allowsHitTesting(false)
    //    }
    
    func placeItem(_ place: DummyPlace) -> some View {
        VStack(spacing: 6) {
            
            Image(place.image)
                .resizable()
                .scaledToFill()
                .frame(width: 75, height: 75)
                .clipShape(Circle())
                .overlay {
                    Circle()
                        .stroke(
                            place.color,
                            lineWidth: 4
                        )
                }
            
            Text(place.name)
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(.black)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .frame(width: 100, height: 32, alignment: .top)
        }
    }
}

// MARK: - Moments Section

private extension HistoryDetailView {
    
    var momentsSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            
            Text("Your Moments")
                .font(.system(.title3, design: .rounded))
                .fontWeight(.bold)
                .foregroundStyle(.black)
            
            ForEach(moments) { moment in
                momentCard(moment)
            }
        }
        .padding(.top, 25)
        .padding(.bottom, 40)
    }
    
    func momentCard(_ moment: DummyMoment) -> some View {
        ZStack(alignment: .bottomLeading) {
            
            Image(moment.image)
                .resizable()
                .scaledToFill()
                .frame(
                    maxWidth: .infinity,
                    minHeight: 330,
                    maxHeight: 330
                )
                .clipped()
            
            HStack(spacing: 8) {
                Image(systemName: "mappin.circle.fill")
                
                Text(moment.title)
                    .font(.custom("Poppins-Bold", size: 16))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 15)
            .padding(.vertical, 8)
            .background(.white.opacity(0.25))
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
            .padding(20)
            
            // Open button
            VStack {
                HStack {
                    Spacer()
                    
                    Button {
                        // Open moment
                    } label: {
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(.black)
                            .frame(width: 50, height: 50)
                            .background(.white.opacity(0.8))
                            .clipShape(Circle())
                    }
                }
                
                Spacer()
            }
            .padding(20)
        }
        .frame(height: 330)
        .clipShape(
            RoundedRectangle(cornerRadius: 25)
        )
        .shadow(
            color: .black.opacity(0.2),
            radius: 5,
            x: 0,
            y: 4
        )
    }
}

#Preview {
    NavigationStack {
        HistoryDetailView()
    }
}
