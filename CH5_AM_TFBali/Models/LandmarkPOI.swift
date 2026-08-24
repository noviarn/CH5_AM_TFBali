import MapKit

/// A point of interest along a corridor — Rama Shinta Garden, Badung Market, and the like.
/// Standalone from the nav-engine `Landmark` (the fixed-loop video-marking checkpoint set):
/// these are shown on the map for browsing regardless of which corridor is toggled on or
/// whether a trip is under way, and carry no marking/recording behavior of their own.
struct LandmarkPOI: Identifiable {
    let id = UUID()
    let name: String
    let coordinate: CLLocationCoordinate2D
    let category: String
    let locationName: String
    /// Corridor(s) this landmark sits along, e.g. `["K1"]` or `["K2", "K6"]`. Informational
    /// only — display isn't gated by which corridors are currently visible.
    let corridorIDs: [String]
    let summary: String
    let activities: [Activities]
    let funFactTitle: String?
    let funFact: String?
    let images: [String]

    init(
        name: String,
        latitude: CLLocationDegrees,
        longitude: CLLocationDegrees,
        category: String,
        locationName: String = "",
        corridorIDs: [String],
        summary: String,
        activities: [Activities] = [],
        funFactTitle: String? = nil,
        funFact: String? = nil,
        images: [String] = ["landmark-placeholder"]
    ) {
        self.name = name
        self.coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        self.category = category
        self.locationName = locationName
        self.corridorIDs = corridorIDs
        self.summary = summary
        self.activities = activities
        self.funFactTitle = funFactTitle
        self.funFact = funFact
        self.images = images
    }

    /// A best-effort glyph from the category string, since the source data gives categories
    /// as free text ("Park/Statue", "K2 & K6"-style combos) rather than a fixed enum.
    var icon: String {
        if category.contains("Temple") { return "building.columns.fill" }
        if category.contains("Beach") { return "beach.umbrella.fill" }
        if category.contains("Market") { return "cart.fill" }
        if category.contains("Statue") { return "figure.stand" }
        if category.contains("Park") { return "tree.fill" }
        return "mappin.circle.fill"
    }

    /// The `Category.name` this landmark files under in the discovery tab (Categories,
    /// Popular Places). Maps free-text sources onto the fixed set from `CategorySeedData`:
    /// a combo like "Park/Statue" takes its first term, and "Market" maps onto the seed
    /// data's "Local Market" since that's the name actually seeded.
    var placeCategoryName: String {
        let primary = category.split(separator: "/").first.map(String.init) ?? category
        return primary == "Market" ? "Local Market" : primary
    }
}
