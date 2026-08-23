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
    /// Corridor(s) this landmark sits along, e.g. `["K1"]` or `["K2", "K6"]`. Informational
    /// only — display isn't gated by which corridors are currently visible.
    let corridorIDs: [String]
    let summary: String
    let activities: [String]
    let funFactTitle: String?
    let funFact: String?
    let image: String

    init(
        name: String,
        latitude: CLLocationDegrees,
        longitude: CLLocationDegrees,
        category: String,
        corridorIDs: [String],
        summary: String,
        activities: [String] = [],
        funFactTitle: String? = nil,
        funFact: String? = nil,
        image: String = "landmark-placeholder"
    ) {
        self.name = name
        self.coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        self.category = category
        self.corridorIDs = corridorIDs
        self.summary = summary
        self.activities = activities
        self.funFactTitle = funFactTitle
        self.funFact = funFact
        self.image = image
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

    /// How this landmark groups for browsing: a combo like "Park/Statue" files under Park.
    /// Drives both the map's category filter and the search sheet's category chips, which is
    /// why it lives here rather than in whichever view reached for it first.
    var primaryCategory: String {
        category.split(separator: "/").first.map(String.init) ?? category
    }

    /// The `Category.name` this landmark files under in the discovery tab (Categories,
    /// Popular Places). Same grouping as `primaryCategory`, except "Market" maps onto the
    /// seed data's "Local Market" since that's the name `CategorySeedData` actually seeds.
    var placeCategoryName: String {
        primaryCategory == "Market" ? "Local Market" : primaryCategory
    }
}
