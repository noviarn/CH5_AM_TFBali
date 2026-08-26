import SwiftUI

/// Detail sheet for a standalone corridor point of interest — see the note on `LandmarkPOI`.
struct LandmarkPOIDetailView: View {
    @Environment(\.dismiss) private var dismiss
    
    let poi: LandmarkPOI
    var onNavigate: (() -> Void)? = nil
    
    var body: some View {
        ZStack {
            Color.appBackground
                .ignoresSafeArea()
            
            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 15) {
                    
                    // MARK: - Header & Action Button
                    HStack(alignment: .top, spacing: 15) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(poi.name)
                                .font(.system(.title, design: .rounded))
                                .fontWeight(.bold)
                                .foregroundStyle(.black)
                            HStack {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(poi.category)
                                        .font(.system(.subheadline, design: .rounded))
                                        .foregroundStyle(Color.textMuted)
                                    
                                    HStack(spacing: 12) {
                                        HStack(spacing: 4) {
                                            Image(systemName: "mappin.and.ellipse")
                                                .font(.system(size: 13, weight: .semibold))
                                            
                                            Text(poi.locationName)
                                                .font(.system(.caption, design: .rounded))
                                        }
                                        
                                        HStack(spacing: 4) {
                                            Image(systemName: "clock")
                                                .font(.system(size: 13, weight: .semibold))
                                            
                                            Text("1h 22m")
                                                .font(.system(.caption, design: .rounded))
                                        }
                                        
                                        HStack(spacing: 4) {
                                            Image(systemName: "location.fill")
                                                .font(.system(size: 13, weight: .semibold))
                                            
                                            Text("13 km")
                                                .font(.system(.caption, design: .rounded))
                                        }
                                    }
                                    .foregroundStyle(Color.textMuted)
                                }
                                Spacer()
                                // MARK: - Go / Route Button
                                if let onNavigate {
                                    Button {
                                        Haptics.tap()
                                        onNavigate()
                                    } label: {
                                        Image(systemName: "arrow.right")
                                            .font(.system(size: 20, weight: .bold))
                                            .foregroundStyle(.white)
                                            .frame(width: 48, height: 48)
                                            .background(Color.primaryOrange)
                                            .clipShape(Circle())
                                    }
                                }
                            }
                        }
                    }
                    
                    // MARK: - Image Carousel
                    TabView {
                        ForEach(poi.images, id: \.self) { imageName in
                            Image(imageName)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 350, height: 350)
                                .clipped()
                        }
                    }
                    .frame(width: 350, height: 350)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .overlay {
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.black.opacity(0.05), lineWidth: 1)
                    }
                    .tabViewStyle(.page(indexDisplayMode: .automatic))
                    .frame(maxWidth: .infinity)
                    
                    // MARK: - Summary / Description
                    Text(poi.summary)
                        .font(.system(.body, design: .rounded))
                        .foregroundStyle(.black)
                        .fontWeight(.regular)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .lineSpacing(4)
                    
                    // MARK: - What To Do (Activities List)
                    if !poi.activities.isEmpty {
                        VStack(alignment: .leading, spacing: 15) {
                            Text("WHAT TO DO")
                                .font(.system(.subheadline, design: .rounded))
                                .fontWeight(.bold)
                                .foregroundStyle(Color.primaryPurple)
                            
                            ForEach(poi.activities, id: \.self) { activity in
                                HStack(spacing: 16) {
                                    Image(systemName: "star.fill") // Replace with dynamic icon if available
                                        .font(.system(size: 18, weight: .semibold))
                                        .foregroundStyle(.black)
                                        .frame(width: 44, height: 44)
                                        .background(Color.white)
                                        .clipShape(Circle())
                                    
                                    Text(activity.text)
                                        .font(.system(.callout, design: .rounded))
                                        .fontWeight(.semibold)
                                        .foregroundStyle(.white)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.accentPurple)
                                .clipShape(RoundedRectangle(cornerRadius: 15))
                            }
                        }
                        .padding(.top, 10)
                    }
                    
                    // MARK: - Fun Fact Card
                    if let funFact = poi.funFact {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(alignment: .center) {
                                Text(poi.funFactTitle ?? "Did you know?")
                                    .font(.system(.headline, design: .rounded))
                                    .fontWeight(.bold)
                                    .foregroundStyle(.black)
                                
                                Spacer()
                                
                                Image("funfact-placeholder")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 80, height: 60)
                            }
                            
                            Text(funFact)
                                .font(.system(.footnote, design: .rounded))
                                .foregroundStyle(Color.black)
                                .lineSpacing(3)
                        }
                        .padding(16)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .shadow(color: Color.black.opacity(0.25), radius: 4, x: 1, y: 2)
                        .overlay(alignment: .topLeading) {
                            Text("FUNFACT")
                                .font(.system(.body, design: .rounded))
                                .fontWeight(.bold)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(Color.primaryOrange)
                                .clipShape(RoundedRectangle(cornerRadius: 5))
                                .offset(x: 12, y: -10)
                        }
                        .padding(.top, 25)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
            }
        }
    }
}

#Preview {
    LandmarkPOIDetailView(poi: landmarkPOIs[0])
}
