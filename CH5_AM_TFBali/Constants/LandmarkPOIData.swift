/// Points of interest along the K1-K6/S1 corridors, standalone from the nav-engine
/// checkpoint landmarks. See the note on `LandmarkPOI`.
let landmarkPOIs: [LandmarkPOI] = [
    LandmarkPOI(
        name: "Rama Shinta Garden",
        latitude: -8.555365050317222, longitude: 115.17125844063727,
        category: "Park/Statue",
        locationName: "Mengwitani",
        corridorIDs: ["K1"],
        summary: "A roadside garden featuring a giant Rama and Shinta sculpture inspired by the Ramayana. It's a quick stop, but the characters connect to stories you'll encounter throughout Balinese dance, art, and religious culture.",
        activities: [
            Activities(text: "Admire the Rama & Shinta statues surrounded by lush gardens", icon: "binoculars.fill"),
            Activities(text: "Take a slow walk through the garden", icon: "figure.walk"),
            Activities(text: "Capture the statues framed by the greenery", icon: "camera.fill")
        ],
        funFactTitle: "You'll meet these two again",
        funFact: "Rama, Shinta, and Hanoman aren't just characters from one monument—they appear throughout Balinese performances, sculptures, and temple art. Once you know the story, you'll start spotting them everywhere.",
        images: ["rama-shinta-garden-1", "rama-shinta-garden-2", "rama-shinta-garden-3"],
        illustration: "park-illustration"
    ),
    LandmarkPOI(
        name: "Taman Puspem Badung",
        latitude: -8.600407921922164, longitude: 115.1853294875161,
        category: "Park",
        locationName: "Sempidi",
        corridorIDs: ["K1"],
        summary: "Badung's government center is surrounded by open spaces, gardens, and Balinese-inspired architecture. Unlike a typical office complex, the grounds have become a place where locals exercise, relax, and spend time with family.",
        activities: [
            Activities(text: "Admire the large-scale Balinese-inspired architecture around the Puspem complex", icon: "binoculars.fill"),
            Activities(text: "Visit Balai Budaya Giri Nata Mandala when it’s open or hosting an event", icon: "figure.walk"),
            Activities(text: "Capture the striking architecture and open spaces", icon: "camera.fill")
        ],
        funFactTitle: "Before this became Puspem, it was an emergency office.",
        funFact: "Badung's original government center in Denpasar was destroyed in the 1999 riots, forcing the government to move between temporary locations. One of those temporary offices was here in Sempidi—where Balai Budaya Giri Nata Mandala stands today.",
        images: ["taman-puspem-bandung-1", "taman-puspem-bandung-2", "taman-puspem-bandung-3"],
        isPopular: true,
        illustration: "park-illustration"
    ),
    LandmarkPOI(
        name: "Majapahit Temple",
        latitude: -8.666051665316028, longitude: 115.20679491151411,
        category: "Temple",
        locationName: "Pemecutan Kaja",
        corridorIDs: ["K1"],
        summary: "A historic Hindu temple in Denpasar whose architecture stands out from the more familiar Balinese temple style. Its dominant red-brick structures and East Javanese-inspired forms make it feel surprisingly different from many temples around Bali. ",
        activities: [
            Activities(text: "Admire the intricate details of the temple’s distinctive red-brick architecture", icon: "binoculars.fill"),
            Activities(text: "Explore the temple grounds and its surroundings", icon: "figure.walk"),
            Activities(text: "Capture the red-brick entrance and traditional structures.", icon: "binoculars.fill")
            //            "Catch the sunrise along the beachfront.",
            //            "Walk or cycle along the coastal path.",
            //            "Look for traditional jukung fishing boats and the fishermen returning from the sea."
        ],
        funFactTitle: "Someone actually went to Majapahit to copy a building",
        funFact: "When the King of Badung wanted a Majapahit-style shrine for wayang performance, He sent a builder named I Pasek to Majapahit to measure the original architecture, then used those measurements to build the Candi Raras Majapahit you see here today.",
        images: ["majapahit-temple-1", "majapahit-temple-2", "majapahit-temple-3"],
        illustration: "temple-illustration"
    ),
    LandmarkPOI(
        name: "Sanur Beach",
        latitude: -8.673386444060952, longitude: 115.26348162503426,
        category: "Beach",
        locationName: "Sanur",
        corridorIDs: ["K5"],
        summary: "A laid-back stretch of coastline known for calm waters, sunrise views, traditional fishing boats, and a slower atmosphere than Bali's more famous western beaches.",
        activities: [
            Activities(text: "Admire the sunrise and traditional jukung fishing boats along the beachfront", icon: "binoculars.fill"),
            Activities(text: "Walk or cycle along the coastal path and watch fishermen returning from the sea", icon: "figure.walk"),
            Activities(text: "Capture the sunrise with the jukung boats on the horizon", icon: "camera.fill")
        ],
        funFactTitle: "That giant hotel changed Bali's skyline.",
        funFact: "The towering Bali Beach Hotel in Sanur became a major exception to Bali's low-rise landscape and is closely associated with the development of the island's famous building-height restrictions of around 15 metres.",
        images: ["sanur-beach-1", "sanur-beach-2", "sanur-beach-3"],
        isPopular: true,
        illustration: "beach-illustration"
    ),
//    LandmarkPOI(
//        name: "Sindhu Night Market",
//        latitude: -8.684876763461771, longitude: 115.25981362318157,
//        category: "Market",
//        locationName: "Sanur",
//        corridorIDs: ["K5"],
//        summary: "A lively evening market in Sanur filled with local food, snacks, drinks, and casual crowds. It's one of those places where you can see Sanur shift from a beach destination into a more everyday local neighborhood at night.",
//        activities: [
//            Activities(text: "Have dinner at the food stalls, choosing from Balinese and Indonesian dishes", icon: "placeholdertext.fill")
//            //            "Have dinner at the food stalls, choosing from Balinese and Indonesian dishes."
//        ],
//        funFactTitle: "Sanur gets touristy. This part stays local.",
//        funFact: "Sindhu Market still serves everyday local life alongside its nighttime food scene. Come hungry, walk around first, and graze from several stalls instead of treating it like a regular restaurant.",
//        images: ["sindhu-night-market-1", "sindhu-night-market-2"],
//        illustration: "local-market-illustration"
//    ),
    //    LandmarkPOI(
    //        name: "Titi Banda Statue",
    //        latitude: -8.64232816122597, longitude: 115.25710503721974,
    //        category: "Statue",
    //        corridorIDs: ["K5"],
    //        summary: "Standing at one of Denpasar's busiest crossroads, this giant monument brings a scene from the Ramayana into the middle of everyday city life. Rama stands above his monkey army as they build the legendary bridge to Alengka.",
    //        funFactTitle: "Don't just look at Rama, count his army.",
    //        funFact: "The monument depicts 18 monkey warriors, including famous characters such as Hanoman, Sugriwa, Nala, and Anggada, helping to construct the bridge to Alengka."
    //    ),
    LandmarkPOI(
        name: "Lapangan Niti Mandala Renon - Monumen Perjuangan Rakyat Bali",
        latitude: -8.671099898314099, longitude: 115.23389448270628,
        category: "Park/Statue",
        locationName: "Panjer",
        corridorIDs: ["K3"],
        summary: "A huge green gathering space at the heart of Denpasar, with the striking Bajra Sandhi Monument rising from its center. Come in the morning or evening and you'll see the field turn into one of the city's favorite places to exercise and hang out.",
        activities: [
            Activities(text: "Admire the grand Bajra Sandhi Monument and its distinctive Balinese architecture", icon: "binoculars.fill"),
            Activities(text: "Walk around the open field or join the morning and evening exercise crowd", icon: "figure.walk"),
            Activities(text: "Capture the monument against the wide open park", icon: "camera.fill")
        ],
        funFactTitle: "This massive Bajra Sandhi monument started with a student",
        funFact: "In 1981, architecture student Ida Bagus Gede Yadnya won the design competition for Bajra Sandhi, beating designs submitted by more experienced architects.",
        images: ["lapangan-niti-mandala-1", "lapangan-niti-mandala-2", "lapangan-niti-mandala-3"],
        isPopular: true,
        illustration: "park-illustration"
    ),
    LandmarkPOI(
        name: "Badung Market",
        latitude: -8.656003524510558, longitude: 115.21257684113934,
        category: "Market",
        locationName: "Dauh Puri Kangin",
        corridorIDs: ["K3"],
        summary: "One of Denpasar's busiest traditional markets, where everyday Balinese life unfolds between piles of produce, offerings, spices, snacks, and household goods. Cross the river and you'll find Kumbasari Market, making the area feel like one giant traditional shopping district.",
        activities: [
            Activities(text: "Explore the lively market filled with fresh produce, spices, flowers, offerings, and local goods", icon: "binoculars.fill"),
            Activities(text: "Try local food and traditional snacks from the market stalls", icon: "figure.walk"),
            Activities(text: "Capture the colorful atmosphere and everyday life of the market", icon: "camera.fill")
        ],
        funFactTitle: "That river isn't just scenery.",
        funFact: "During the 1906 Puputan Badung, Dutch forces used Tukad Badung as a logistics route while advancing toward Puri Pemecutan. Today, the same river runs quietly beside one of Denpasar's busiest markets.",
        images: ["badung-market-1", "badung-market-2", "badung-market-3"],
        illustration: "local-market-illustration"
    ),
    LandmarkPOI(
        name: "Puri Agung Pemecutan, Badung Palace (ada Monumen Ida Cokorda Pemecutan IX)",
        latitude: -8.65758230467784, longitude: 115.21010004662973,
        category: "Temple",
        locationName: "Pemecutan",
        corridorIDs: ["K3"],
        summary: "One of Denpasar's historic royal palaces, once the seat of the powerful Pemecutan Kingdom. Today, the palace and the nearby Ida Cokorda Pemecutan IX monument offer a glimpse into the royal history behind modern Denpasar.",
        activities: [
            Activities(text: "Admire the traditional palace architecture and Monumen Ida Cokorda Pemecutan IX", icon: "binoculars.fill"),
            Activities(text: "Walk around the palace area and discover its history", icon: "figure.walk"),
            Activities(text: "Capture the monument alongside the palace’s architectural details", icon: "camera.fill")
        ],
        funFactTitle: "The palace burned, but one part survived.",
        funFact: "During the 1906 Puputan Badung, the old palace was destroyed by fire, yet its Bale Kulkul survived and remains as one of the physical remnants of the old palace.",
        images: ["puri-agung-pemecutan-1", "puri-agung-pemecutan-2", "puri-agung-pemecutan-3"],
        illustration: "temple-illustration"
    ),
    LandmarkPOI(
        name: "Satria Gatotkaca Park",
        latitude: -8.744140533317902, longitude: 115.17883579956927,
        category: "Statue",
        locationName: "Tuban",
        corridorIDs: ["K2", "K6"],
        summary: "A small landmark park in Tuban, near I Gusti Ngurah Rai International Airport. Its centerpiece is a dramatic sculpture depicting Gatotkaca in battle with Karna from the Mahabharata.",
        activities: [
            Activities(text: "Admire the Gatotkaca and Karna sculptures and their intricate details", icon: "binoculars.fill"),
            Activities(text: "Visit in the evening to experience the park’s lights and fountains", icon: "figure.walk"),
            Activities(text: "Capture the sculptures with the illuminated park in the background", icon: "camera.fill")
        ],
        funFactTitle: "Did you know?",
        funFact: "Locals often call it \"Patung Kuda\" (Horse Statue) because the monument includes six horses pulling Karna's war chariot.",
        images: ["satria-gatotkaca-park-1", "satria-gatotkaca-park-2", "satria-gatotkaca-park-3"],
        illustration: "illustration-sgp"
    ),
    LandmarkPOI(
        name: "Lapangan Puputan Badung",
        latitude: -8.656705302595817, longitude: 115.21764810248865,
        category: "Park",
        locationName: "Dauh Puri Kangin",
        corridorIDs: ["K2"],
        // Source data left description/activities/fun-fact blank for this one — placeholder
        // until real copy is written.
        summary: "A historic city park in the heart of Denpasar, surrounded by Balinese landmarks and everyday local life. It’s a nice spot to slow down, people-watch, and see how history blends into the city today.",
        activities: [
            Activities(text: "Admire the iconic Puputan Badung monument and the landmarks surrounding the square", icon: "binoculars.fill"),
            Activities(text: "Take a walk, people-watch, or relax under the trees", icon: "figure.walk"),
            Activities(text: "Capture the monument framed by the city around it", icon: "camera.fill")
        ],
        funFactTitle: "Did you know?",
        funFact: "“Puputan” means fighting to the very end. The square remembers the 1906 Puputan Badung, when Balinese forces chose to resist rather than surrender.",
        images: ["lapangan-puputan-badung-1", "lapangan-puputan-badung-2", "lapangan-puputan-badung-3"],
        isPopular: true,
        illustration: "park-illustration"
    ),
    LandmarkPOI(
        name: "Pura Desa Adat Kuta",
        latitude: -8.722107653279675, longitude: 115.17676159572538,
        category: "Temple",
        locationName: "Kuta",
        corridorIDs: ["K2"],
        summary: "An active Hindu temple serving the traditional community of Kuta.",
        activities: [
            Activities(text: "Admire the temple’s traditional Balinese architecture and intricate details", icon: "binoculars.fill"),
            Activities(text: "xplore the area while respectfully observing local religious traditions", icon: "figure.walk"),
            Activities(text: "Capture the distinctive temple gates and architectural details", icon: "camera.fill")
        ],
        funFactTitle: "Did you know?",
        funFact: "The temple continues to host important ceremonies for the Kuta community.",
        images: ["pura-desa-adat-kuta-1", "pura-desa-adat-kuta-2", "pura-desa-adat-kuta-3", "pura-desa-adat-kuta-4"],
        illustration: "temple-illustration"
    ),
    LandmarkPOI(
        name: "Arjuna Statue",
        latitude: -8.509012760414372, longitude: 115.27113000302433,
        category: "Statue",
        locationName: "Seminyak",
        corridorIDs: ["K4"],
        summary: "A prominent Ubud roadside sculpture commonly identified as Arjuna from the Mahabharata.",
        activities: [
            Activities(text: "Admire the statue’s intricate details and mythological character", icon: "binoculars.fill"),
            Activities(text: "Take a moment to explore the area around the monument", icon: "figure.walk"),
            Activities(text: "Capture the statue from different angles to highlight its details", icon: "camera.fill")
        ],
        funFactTitle: "Did you know?",
        funFact: "The statue's identity is debated: some sources identify it as Arjuna, while others call it Dewa Indra.",
        images: ["arjuna-statue-1", "arjuna-statue-2"],
        illustration: "statue-illustration"
    ),
    LandmarkPOI(
        name: "Titi Banda Statue",
        latitude: -8.64899990715981, longitude: 115.25505582456064,
        category: "Statue",
        locationName: "Kesiman Kertalangu",
        corridorIDs: ["K4", "K5"],
        summary: "A monumental Ramayana sculpture depicting Rama and his monkey army building the bridge to Lanka.",
        activities: [
            Activities(text: "Admire the monument’s depiction of Hanuman and its Ramayana symbolism", icon: "binoculars.fill"),
            Activities(text: "Explore the area around the monument and discover its story", icon: "figure.walk"),
            Activities(text: "Capture the statue’s details and dramatic form", icon: "camera.fill")
        ],
        funFactTitle: "Don't just look at Rama, count his army.",
        funFact: "The monument depicts 18 monkey warriors, including famous characters such as Hanoman, Sugriwa, Nala, and Anggada, helping to construct the bridge to Alengka.",
        images: ["titi-banda-statue-1", "titi-banda-statue-2", "titi-banda-statue-3"],
        isPopular: true,
        illustration: "statue-illustration"
    ),
    LandmarkPOI(
        name: "Lumintang Park",
        latitude: -8.635762683458093, longitude: 115.21291239387253,
        category: "Park",
        locationName: "Puri Kaja",
        corridorIDs: ["K4"],
        summary: "A large public park with recreational, sports, family and children's facilities.",
        activities: [
            Activities(text: "Admire the park’s open green spaces and dancing fountain", icon: "binoculars.fill"),
            Activities(text: "Go for a jog or spend some time at the playground", icon: "figure.walk"),
            Activities(text: "Capture the dancing fountain, especially when it lights up in the evening", icon: "camera.fill")
        ],
        funFactTitle: "Did you know?",
        funFact: "The dancing fountain combines water, lights and music on weekend evenings.",
        images: ["lumintang-park-1", "lumintang-park-2"],
        isPopular: true,
        illustration: "park-illustration"
    ),
    LandmarkPOI(
        name: "Taman Bundaran Ngurah Rai",
        latitude: -8.744916333786607, longitude: 115.18255275339769,
        category: "Park",
        locationName: "Tuban",
        corridorIDs: ["K6"],
        summary: "A landscaped park surrounding the Ngurah Rai monument near Bali's airport.",
        activities: [
            Activities(text: "Admire the monument and its surrounding landscape at this important gateway to Bali", icon: "binoculars.fill"),
            Activities(text: "Take a walk around the area and learn about its connection to Bali’s independence history", icon: "figure.walk"),
            Activities(text: "Capture the monument and its surrounding scenery", icon: "camera.fill")
        ],
        funFactTitle: "Did you know?",
        funFact: "The monument has been a landmark at the Tuban junction since around the 1980s.",
        images: ["taman-bundaran-ngurah-rai-1", "taman-bundaran-ngurah-rai-2", "taman-bundaran-ngurah-rai-3"],
        illustration: "park-illustration"
    ),
    LandmarkPOI(
        name: "Dewa Ruci Statue",
        latitude: -8.721616525230269, longitude: 115.1827303130245,
        category: "Statue",
        locationName: "Kuta",
        corridorIDs: ["K6, K5"],
        summary: "A monumental sculpture depicting Bima's battle with a serpent during his spiritual quest.",
        activities: [
            Activities(text: "Admire the sculpture’s dramatic details and mythological symbolism", icon: "binoculars.fill"),
            Activities(text: "Take a moment to learn about the story of Dewa Ruci and its meaning in Balinese culture", icon: "figure.walk"),
            Activities(text: "Capture the sculpture from an angle that highlights its scale and details", icon: "camera.fill")
        ],
        funFactTitle: "Did you know?",
        funFact: "Created by I Wayan Winten in 1996, it was made from concrete rather than wood.",
        images: ["dewa-ruci-1", "dewa-ruci-2"],
        illustration: "statue-illustration"
    ),
    LandmarkPOI(
        name: "Garuda Wisnu Kencana",
        latitude: -8.81010520901596, longitude: 115.16798733607519,
        category: "Statue",
        locationName: "Ungasan",
        corridorIDs: ["K5"],
        summary: "A massive cultural landmark featuring a towering statue of Lord Vishnu riding Garuda, surrounded by beautiful limestone cliffs and Balinese architecture.",
        activities: [
            Activities(text: "Admire the monumental GWK statue towering over the cultural park", icon: "binoculars.fill"),
            Activities(text: "Explore the cultural park and catch a traditional Balinese performance", icon: "figure.walk"),
            Activities(text: "Capture the iconic statue against the Bali landscape.", icon: "camera.fill")
            //            "Photograph the sculpture and learn about the Dewa Ruci story and its symbolism."
        ],
        funFactTitle: "Did you know?",
        funFact: "The GWK statue is one of the tallest monumental statues in the world, standing at around 121 meters tall",
        images: ["GWK-1", "GWK-2", "GWK-3"],
        illustration: "illustration-gwk"
    ),
]
