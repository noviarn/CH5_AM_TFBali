/// Points of interest along the K1-K6/S1 corridors, standalone from the nav-engine
/// checkpoint landmarks. See the note on `LandmarkPOI`.
let landmarkPOIs: [LandmarkPOI] = [
    LandmarkPOI(
        name: "Rama Shinta Garden",
        latitude: -8.555365050317222, longitude: 115.17125844063727,
        category: "Park/Statue",
        corridorIDs: ["K1"],
        summary: "A roadside garden featuring a giant Rama and Shinta sculpture inspired by the Ramayana. It's a quick stop, but the characters connect to stories you'll encounter throughout Balinese dance, art, and religious culture.",
        funFactTitle: "You'll meet these two again",
        funFact: "Rama, Shinta, and Hanoman aren't just characters from one monument—they appear throughout Balinese performances, sculptures, and temple art. Once you know the story, you'll start spotting them everywhere.",
        images: ["rama-shinta-garden-1", "rama-shinta-garden-2", "rama-shinta-garden-3"]
    ),
    LandmarkPOI(
        name: "Taman Puspem Badung",
        latitude: -8.600407921922164, longitude: 115.1853294875161,
        category: "Park",
        corridorIDs: ["K1"],
        summary: "Badung's government center is surrounded by open spaces, gardens, and Balinese-inspired architecture. Unlike a typical office complex, the grounds have become a place where locals exercise, relax, and spend time with family.",
        activities: [
            Activities(text: "Walk around the Puspem complex and see its large-scale Balinese-inspired architecture", icon: "placeholdertext.fill"),
            Activities(text: "Visit Balai Budaya Giri Nata Mandala when it's open to the public or hosting an event", icon: "placeholdertext.fill"),
            Activities(text: "Relax or exercise in the open areas around the government complex, like many locals do", icon: "placeholdertext.fill")
            //            ["Walk around the Puspem complex and see its large-scale Balinese-inspired architecture.", "placeholdertext.fill"],
            //            "Visit Balai Budaya Giri Nata Mandala when it's open to the public or hosting an event.",
            //            "Relax or exercise in the open areas around the government complex, like many locals do."
        ],
        funFactTitle: "Before this became Puspem, it was an emergency office.",
        funFact: "Badung's original government center in Denpasar was destroyed in the 1999 riots, forcing the government to move between temporary locations. One of those temporary offices was here in Sempidi—where Balai Budaya Giri Nata Mandala stands today."
    ),
    LandmarkPOI(
        name: "Majapahit Temple",
        latitude: -8.666051665316028, longitude: 115.20679491151411,
        category: "Temple",
        corridorIDs: ["K1"],
        summary: "A historic Hindu temple in Denpasar whose architecture stands out from the more familiar Balinese temple style. Its dominant red-brick structures and East Javanese-inspired forms make it feel surprisingly different from many temples around Bali.",
        funFactTitle: "Someone actually went to Majapahit to copy a building.",
        funFact: "When the King of Badung wanted a Majapahit-style shrine for wayang performance, he sent a builder named I Pasek to Majapahit to measure the original architecture, then used those measurements to build the Candi Raras Majapahit you see here today.",
        images: ["majapahit-temple-1", "majapahit-temple-2", "majapahit-temple-3"]
    ),
    LandmarkPOI(
        name: "Sanur Beach",
        latitude: -8.673386444060952, longitude: 115.26348162503426,
        category: "Beach",
        corridorIDs: ["K5"],
        summary: "A laid-back stretch of coastline known for calm waters, sunrise views, traditional fishing boats, and a slower atmosphere than Bali's more famous western beaches.",
        activities: [
            Activities(text: "Catch the sunrise along the beachfront", icon: "placeholdertext.fill"),
            Activities(text: "Walk or cycle along the coastal path", icon: "placeholdertext.fill"),
            Activities(text: "Look for traditional jukung fishing boats and the fishermen returning from the sea", icon: "placeholdertext.fill")
            //            "Catch the sunrise along the beachfront.",
            //            "Walk or cycle along the coastal path.",
            //            "Look for traditional jukung fishing boats and the fishermen returning from the sea."
        ],
        funFactTitle: "That giant hotel changed Bali's skyline.",
        funFact: "The towering Bali Beach Hotel in Sanur became a major exception to Bali's low-rise landscape and is closely associated with the development of the island's famous building-height restrictions of around 15 metres."
    ),
    LandmarkPOI(
        name: "Sindhu Night Market",
        latitude: -8.684876763461771, longitude: 115.25981362318157,
        category: "Market",
        corridorIDs: ["K5"],
        summary: "A lively evening market in Sanur filled with local food, snacks, drinks, and casual crowds. It's one of those places where you can see Sanur shift from a beach destination into a more everyday local neighborhood at night.",
        activities: [
            Activities(text: "Have dinner at the food stalls, choosing from Balinese and Indonesian dishes", icon: "placeholdertext.fill")
            //            "Have dinner at the food stalls, choosing from Balinese and Indonesian dishes."
        ],
        funFactTitle: "Sanur gets touristy. This part stays local.",
        funFact: "Sindhu Market still serves everyday local life alongside its nighttime food scene. Come hungry, walk around first, and graze from several stalls instead of treating it like a regular restaurant."
    ),
    LandmarkPOI(
        name: "Patung Titi Banda",
        latitude: -8.64232816122597, longitude: 115.25710503721974,
        category: "Statue",
        corridorIDs: ["K5"],
        summary: "Standing at one of Denpasar's busiest crossroads, this giant monument brings a scene from the Ramayana into the middle of everyday city life. Rama stands above his monkey army as they build the legendary bridge to Alengka.",
        funFactTitle: "Don't just look at Rama, count his army.",
        funFact: "The monument depicts 18 monkey warriors, including famous characters such as Hanoman, Sugriwa, Nala, and Anggada, helping to construct the bridge to Alengka."
    ),
    LandmarkPOI(
        name: "Lapangan Niti Mandala Renon - Monumen Perjuangan Rakyat Bali",
        latitude: -8.671099898314099, longitude: 115.23389448270628,
        category: "Park/Statue",
        corridorIDs: ["K3"],
        summary: "A huge green gathering space at the heart of Denpasar, with the striking Bajra Sandhi Monument rising from its center. Come in the morning or evening and you'll see the field turn into one of the city's favorite places to exercise and hang out.",
        activities: [
            Activities(text: "Walk around the large open field and enjoy the public park atmosphere", icon: "placeholdertext.fill"),
            Activities(text: "Visit the Bajra Sandhi Monument and museum to see its historical exhibits and dioramas", icon: "placeholdertext.fill"),
            Activities(text: "Join the morning/evening exercise crowd—especially popular on weekends", icon: "placeholdertext.fill")
            //            "Walk around the large open field and enjoy the public park atmosphere.",
            //            "Visit the Bajra Sandhi Monument and museum to see its historical exhibits and dioramas.",
            //            "Join the morning/evening exercise crowd—especially popular on weekends."
        ],
        funFactTitle: "This massive Bajra Sandhi monument started with a student.",
        funFact: "In 1981, architecture student Ida Bagus Gede Yadnya won the design competition for Bajra Sandhi, beating designs submitted by more experienced architects.",
        images: ["lapangan-niti-mandala-1", "lapangan-niti-mandala-2", "lapangan-niti-mandala-3"]
    ),
    LandmarkPOI(
        name: "Badung Market",
        latitude: -8.656003524510558, longitude: 115.21257684113934,
        category: "Market",
        corridorIDs: ["K3"],
        summary: "One of Denpasar's busiest traditional markets, where everyday Balinese life unfolds between piles of produce, offerings, spices, snacks, and household goods. Cross the river and you'll find Kumbasari Market, making the area feel like one giant traditional shopping district.",
        activities: [
            Activities(text: "Explore the traditional market and browse fresh produce, spices, flowers, offerings, and local goods", icon: "placeholdertext.fill"),
            Activities(text: "Try local food and traditional snacks from the market stalls", icon: "placeholdertext.fill"),
            Activities(text: "Walk across to Kumbasari Market via the bridge over Tukad Badung and explore both sides of the market district", icon: "placeholdertext.fill")
            //            "Explore the traditional market and browse fresh produce, spices, flowers, offerings, and local goods.",
            //            "Try local food and traditional snacks from the market stalls.",
            //            "Walk across to Kumbasari Market via the bridge over Tukad Badung and explore both sides of the market district."
        ],
        funFactTitle: "That river isn't just scenery.",
        funFact: "During the 1906 Puputan Badung, Dutch forces used Tukad Badung as a logistics route while advancing toward Puri Pemecutan. Today, the same river runs quietly beside one of Denpasar's busiest markets.",
        images: ["badung-market-1", "badung-market-2", "badung-market-3"]
    ),
    LandmarkPOI(
        name: "Puri Agung Pemecutan, Badung Palace (ada Monumen Ida Cokorda Pemecutan IX)",
        latitude: -8.65758230467784, longitude: 115.21010004662973,
        category: "Temple",
        corridorIDs: ["K3"],
        summary: "One of Denpasar's historic royal palaces, once the seat of the powerful Pemecutan Kingdom. Today, the palace and the nearby Ida Cokorda Pemecutan IX monument offer a glimpse into the royal history behind modern Denpasar.",
        funFactTitle: "The palace burned, but one part survived.",
        funFact: "During the 1906 Puputan Badung, the old palace was destroyed by fire, yet its Bale Kulkul survived and remains as one of the physical remnants of the old palace.",
        images: ["puri-agung-pemecutan-1", "puri-agung-pemecutan-2", "puri-agung-pemecutan-3"]
    ),
    LandmarkPOI(
        name: "Satria Gatotkaca Park",
        latitude: -8.744140533317902, longitude: 115.17883579956927,
        category: "Statue",
        corridorIDs: ["K2", "K6"],
        summary: "A small landmark park in Tuban, near I Gusti Ngurah Rai International Airport. Its centerpiece is a dramatic sculpture depicting Gatotkaca in battle with Karna from the Mahabharata.",
        activities: [
            Activities(text: "Take photos of the Gatotkaca and Karna sculpture", icon: "placeholdertext.fill"),
            Activities(text: "Visit around evening to see the park's lighting and fountains", icon: "placeholdertext.fill")
            //            "Take photos of the Gatotkaca and Karna sculpture.",
            //            "Visit around evening to see the park's lighting and fountains."
        ],
        funFact: "Locals often call it \"Patung Kuda\" (Horse Statue) because the monument includes six horses pulling Karna's war chariot."
    ),
    LandmarkPOI(
        name: "Lapangan Puputan Badung",
        latitude: -8.656705302595817, longitude: 115.21764810248865,
        category: "Park",
        corridorIDs: ["K2"],
        // Source data left description/activities/fun-fact blank for this one — placeholder
        // until real copy is written.
        summary: "A public square in central Denpasar.",
        images: ["lapangan-puputan-badung-1", "lapangan-puputan-badung-2", "lapangan-puputan-badung-3"]
    ),
    LandmarkPOI(
        name: "Pura Desa Adat Kuta",
        latitude: -8.722107653279675, longitude: 115.17676159572538,
        category: "Temple",
        corridorIDs: ["K2"],
        summary: "An active Hindu temple serving the traditional community of Kuta.",
        activities: [
            Activities(text: "dmire the architecture and respectfully observe local religious traditions", icon: "placeholdertext.fill")
            //            "Admire the architecture and respectfully observe local religious traditions."
        ],
        funFact: "The temple continues to host important ceremonies for the Kuta community.",
        images: ["pura-desa-adat-kuta-1", "pura-desa-adat-kuta-2", "pura-desa-adat-kuta-3", "pura-desa-adat-kuta-4"]
    ),
    LandmarkPOI(
        name: "Arjuna Statue",
        latitude: -8.509012760414372, longitude: 115.27113000302433,
        category: "Statue",
        corridorIDs: ["K4"],
        summary: "A prominent Ubud roadside sculpture commonly identified as Arjuna from the Mahabharata.",
        activities: [
            Activities(text: "Take photos and admire its intricate mythological details", icon: "placeholdertext.fill")
            //            "Take photos and admire its intricate mythological details."
        ],
        funFact: "The statue's identity is debated: some sources identify it as Arjuna, while others call it Dewa Indra.",
        images: ["arjuna-statue-1", "arjuna-statue-2"]
    ),
    LandmarkPOI(
        name: "Titi Banda Statue",
        latitude: -8.64899990715981, longitude: 115.25505582456064,
        category: "Statue",
        corridorIDs: ["K4"],
        summary: "A monumental Ramayana sculpture depicting Rama and his monkey army building the bridge to Lanka.",
        activities: [
            Activities(text: "Photograph the monument and explore its Ramayana symbolism", icon: "placeholdertext.fill")
            //            "Photograph the monument and explore its Ramayana symbolism."
        ],
        funFact: "The scene includes 18 monkey figures, including five principal commanders."
    ),
    LandmarkPOI(
        name: "Lumintang Park",
        latitude: -8.635762683458093, longitude: 115.21291239387253,
        category: "Park",
        corridorIDs: ["K4"],
        summary: "A large public park with recreational, sports, family and children's facilities.",
        activities: [
            Activities(text: "Jogging", icon: "placeholdertext.fill"),
            Activities(text: "Visit the playground", icon: "placeholdertext.fill"),
            Activities(text: "Watch the dancing fountain", icon: "placeholdertext.fill")
            //            "Jogging",
            //            "Visit the playground",
            //            "Watch the dancing fountain."
        ],
        funFact: "The dancing fountain combines water, lights and music on weekend evenings.",
        images: ["lumintang-park-1", "lumintang-park-2"]
    ),
    LandmarkPOI(
        name: "Taman Bundaran Ngurah Rai",
        latitude: -8.744916333786607, longitude: 115.18255275339769,
        category: "Park",
        corridorIDs: ["K6"],
        summary: "A landscaped park surrounding the Ngurah Rai monument near Bali's airport.",
        activities: [
            Activities(text: "Take photos", icon: "placeholdertext.fill"),
            Activities(text: "Learn about Bali's independence history", icon: "placeholdertext.fill")
            //            "Take photos",
            //            "Learn about Bali's independence history."
        ],
        funFact: "The monument has been a landmark at the Tuban junction since around the 1980s."
    ),
    LandmarkPOI(
        name: "Dewa Ruci Statue",
        latitude: -8.721616525230269, longitude: 115.1827303130245,
        category: "Statue",
        corridorIDs: ["K6"],
        summary: "A monumental sculpture depicting Bima's battle with a serpent during his spiritual quest.",
        activities: [
            Activities(text: "Photograph the sculpture and learn about the Dewa Ruci story and its symbolism", icon: "placeholdertext.fill")
            //            "Photograph the sculpture and learn about the Dewa Ruci story and its symbolism."
        ],
        funFact: "Created by I Wayan Winten in 1996, it was made from concrete rather than wood.",
        images: ["dewa-ruci-1", "dewa-ruci-2"]
    ),
]
