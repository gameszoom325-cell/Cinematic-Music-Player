class CuratedSongEntry {
  final String id;
  final String title;
  final String artist;
  final String album;
  final String language;
  final String genre;
  final String year;
  final String category; // "Trending" or "Classics"
  final String lrcFileName;
  final int defaultDurationMs;
  final String demoLyrics;

  const CuratedSongEntry({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    this.language = "Hindi",
    required this.genre,
    required this.year,
    required this.category,
    required this.lrcFileName,
    required this.defaultDurationMs,
    required this.demoLyrics,
  });
}

class CuratedCatalogue {
  static const List<CuratedSongEntry> trendingHits = [
    CuratedSongEntry(
      id: "hindi_trend_1",
      title: "Gehra Hua",
      artist: "Arijit Singh, Shashwat Sachdev",
      album: "Dhurandhar",
      category: "Trending",
      genre: "Romantic / Soul",
      year: "2024",
      lrcFileName: "gehra_hua.lrc",
      defaultDurationMs: 235000,
      demoLyrics: """
[ti:Gehra Hua]
[ar:Arijit Singh, Shashwat Sachdev]
[al:Dhurandhar]
[00:00.00] (Acoustic Guitar & Piano Prelude)
[00:06.50] Khamoshiyon mein chhupa tha kahin
[00:12.80] Tera mera yeh fasana
[00:19.40] Har lamha ab gehra hua
[00:26.20] Tere sang har mausam suhana
[00:32.80] Yeh ishq hai ya koi dua
[00:39.50] Dil ne tujhe apna maana
[00:46.00] Har lamha ab gehra hua
[00:52.60] Tere bina na koi thikana
""",
    ),
    CuratedSongEntry(
      id: "hindi_trend_2",
      title: "Shararat",
      artist: "Jasmine Sandlas, Madhubanti Bagchi",
      album: "Dhurandhar",
      category: "Trending",
      genre: "Dance / Groove",
      year: "2024",
      lrcFileName: "shararat.lrc",
      defaultDurationMs: 198000,
      demoLyrics: """
[ti:Shararat]
[ar:Jasmine Sandlas, Madhubanti Bagchi]
[al:Dhurandhar]
[00:00.00] (Heavy Bass Groove & Electro Dhol)
[00:05.40] Akhiyan ch nasha tera chhaya
[00:10.20] Dil da chain sara lutt laya
[00:15.50] Yeh shararat teri baat mein
[00:20.80] Koyi jadoo hai barsaat mein
[00:26.00] Nach le tu saari raat mein
[00:31.40] Haath de tu mere haath mein
""",
    ),
    CuratedSongEntry(
      id: "hindi_trend_3",
      title: "Saiyaara",
      artist: "Faheem Abdullah, Tanishk Bagchi",
      album: "Saiyaara",
      category: "Trending",
      genre: "Sufi / Folk Pop",
      year: "2024",
      lrcFileName: "saiyaara.lrc",
      defaultDurationMs: 245000,
      demoLyrics: """
[ti:Saiyaara]
[ar:Faheem Abdullah, Tanishk Bagchi]
[al:Saiyaara]
[00:00.00] (Sufi Rubab & Atmospheric Pad)
[00:08.50] Saiyaara ve saiyaara
[00:14.20] Tu hi mera sahara
[00:20.80] Falak se jo utar aaya
[00:27.50] Chamakta ek sitara
[00:34.20] Tere ishq di lehar chali
[00:41.00] Rooh meri taaza khili
""",
    ),
    CuratedSongEntry(
      id: "hindi_trend_4",
      title: "Aavan Jaavan",
      artist: "Arijit Singh, Nikhita Gandhi",
      album: "WAR 2",
      category: "Trending",
      genre: "Action / Romantic",
      year: "2025",
      lrcFileName: "aavan_jaavan.lrc",
      defaultDurationMs: 212000,
      demoLyrics: """
[ti:Aavan Jaavan]
[ar:Arijit Singh, Nikhita Gandhi]
[al:WAR 2]
[00:00.00] (Pulse Synth & Beat Drop)
[00:06.00] Teri raahon mein mera aavan jaavan
[00:12.40] Tere sang beetein yeh saare saavan
[00:18.80] Dhadkan bole bas ek hi naam
[00:25.20] Subah ho chahe dhale yeh shaam
""",
    ),
    CuratedSongEntry(
      id: "hindi_trend_5",
      title: "Khat",
      artist: "Navjot Ahuja",
      album: "Khat",
      category: "Trending",
      genre: "Indie Pop",
      year: "2024",
      lrcFileName: "khat.lrc",
      defaultDurationMs: 185000,
      demoLyrics: """
[ti:Khat]
[ar:Navjot Ahuja]
[al:Khat]
[00:00.00] (Acoustic Fingerstyle)
[00:07.20] Purane khat tere padhta hoon
[00:14.00] Teri yaadon se roz ladata hoon
[00:20.80] Har lafz mein tu zinda hai
[00:27.50] Dil yeh mera parinda hai
""",
    ),
    CuratedSongEntry(
      id: "hindi_trend_6",
      title: "Jaiye Sajana",
      artist: "Jasmine Sandlas, Shashwat Sachdev",
      album: "Jaiye Sajana",
      category: "Trending",
      genre: "Neo-Classical",
      year: "2024",
      lrcFileName: "jaiye_sajana.lrc",
      defaultDurationMs: 220000,
      demoLyrics: """
[ti:Jaiye Sajana]
[ar:Jasmine Sandlas, Shashwat Sachdev]
[al:Jaiye Sajana]
[00:00.00] (Sarangi & Ambient Drone)
[00:08.50] Jaiye sajana chhod ke na
[00:16.00] Dil di taar tod ke na
[00:23.20] Akhiyan barsan raatan nu
[00:30.80] Bhull na jaiye baatan nu
""",
    ),
    CuratedSongEntry(
      id: "hindi_trend_7",
      title: "Tujhko",
      artist: "Arijit Singh, Sunidhi Chauhan, Pritam",
      album: "Metro In Dino",
      category: "Trending",
      genre: "Romantic Ballad",
      year: "2024",
      lrcFileName: "tujhko.lrc",
      defaultDurationMs: 250000,
      demoLyrics: """
[ti:Tujhko]
[ar:Arijit Singh, Sunidhi Chauhan, Pritam]
[al:Metro In Dino]
[00:00.00] (Electric Piano & Soft Strings)
[00:07.00] Tujhko jo paaya toh laga
[00:14.20] Har dard mera mit gaya
[00:21.00] Khwabon ki is bheed mein
[00:28.00] Tu hi toh roshan hua
""",
    ),
    CuratedSongEntry(
      id: "hindi_trend_8",
      title: "Tere Ishk Mein",
      artist: "Arijit Singh, A.R. Rahman",
      album: "Tere Ishk Mein",
      category: "Trending",
      genre: "Passionate Sufi",
      year: "2025",
      lrcFileName: "tere_ishk_mein.lrc",
      defaultDurationMs: 275000,
      demoLyrics: """
[ti:Tere Ishk Mein]
[ar:Arijit Singh, A.R. Rahman]
[al:Tere Ishk Mein]
[00:00.00] (Orchestral Sweep & Choir)
[00:09.50] Tere ishk mein jal gaya aasmaan
[00:18.00] Tu hi zameen tu hi jahan
[00:26.50] Fanaah hua yeh dil mera
[00:35.00] Tu ban gaya mera khuda
""",
    ),
    CuratedSongEntry(
      id: "hindi_trend_9",
      title: "Dooron Dooron",
      artist: "Paresh Pahuja",
      album: "Dooron Dooron",
      category: "Trending",
      genre: "Acoustic Indie",
      year: "2024",
      lrcFileName: "dooron_dooron.lrc",
      defaultDurationMs: 195000,
      demoLyrics: """
[ti:Dooron Dooron]
[ar:Paresh Pahuja]
[al:Dooron Dooron]
[00:00.00] (Warm Ukulele Strumming)
[00:06.80] Dooron dooron takna tera
[00:13.20] Dil nu bada pyara lagda
[00:19.50] Kol aake muskana tera
[00:25.80] Rab da ishara lagda
""",
    ),
    CuratedSongEntry(
      id: "hindi_trend_10",
      title: "Tabaahi",
      artist: "Vishal Mishra",
      album: "Tabaahi",
      category: "Trending",
      genre: "Heartbreak Ballad",
      year: "2024",
      lrcFileName: "tabaahi.lrc",
      defaultDurationMs: 228000,
      demoLyrics: """
[ti:Tabaahi]
[ar:Vishal Mishra]
[al:Tabaahi]
[00:00.00] (Solo Grand Piano)
[00:08.00] Teri judai ne aisi tabaahi machayi
[00:16.50] Har aahat pe teri yaad chali aayi
[00:24.80] Ab kis se karein shikwa hum
[00:33.20] Har saans mein hai tera gham
""",
    ),
  ];

  static const List<CuratedSongEntry> classics = [
    CuratedSongEntry(
      id: "hindi_classic_1",
      title: "Tum Hi Ho",
      artist: "Arijit Singh",
      album: "Aashiqui 2",
      category: "Classics",
      genre: "Bollywood Romance",
      year: "2013",
      lrcFileName: "tum_hi_ho.lrc",
      defaultDurationMs: 262000,
      demoLyrics: """
[ti:Tum Hi Ho]
[ar:Arijit Singh]
[al:Aashiqui 2]
[00:00.00] (Piano Intro)
[00:12.50] Hum tere bin ab reh nahi sakte
[00:19.00] Tere bina kya wajood mera
[00:25.80] Tujhse juda gar ho jaayenge
[00:32.40] Toh khud se hi ho jaayenge judaa
[00:39.20] Kyunki tum hi ho, ab tum hi ho
[00:46.00] Zindagi ab tum hi ho
[00:52.50] Chain bhi, mera dard bhi
[00:59.00] Meri aashiqui ab tum hi ho
""",
    ),
    CuratedSongEntry(
      id: "hindi_classic_2",
      title: "Kesariya",
      artist: "Arijit Singh",
      album: "Brahmāstra",
      category: "Classics",
      genre: "Romantic Anthem",
      year: "2022",
      lrcFileName: "kesariya.lrc",
      defaultDurationMs: 268000,
      demoLyrics: """
[ti:Kesariya]
[ar:Arijit Singh]
[al:Brahmāstra]
[00:00.00] (Acoustic Guitar Riff)
[00:10.50] Mujhko itna bataye koyi
[00:16.80] Kaise tujhse dil na lagaye koyi
[00:23.20] Rabba ne tujhko banane mein
[00:29.50] Kardi hai husn ki khaali tijoriyan
[00:36.00] Kesariya tera ishq hai piya
[00:42.50] Rang jaaun jo main haath lagaun
[00:49.00] Din beete saara teri fikr mein
[00:55.50] Rain saari teri khair manaun
""",
    ),
    CuratedSongEntry(
      id: "hindi_classic_3",
      title: "Chaiyya Chaiyya",
      artist: "Sukhwinder Singh, Sapna Awasthi",
      album: "Dil Se",
      category: "Classics",
      genre: "Folk / World Fusion",
      year: "1998",
      lrcFileName: "chaiyya_chaiyya.lrc",
      defaultDurationMs: 390000,
      demoLyrics: """
[ti:Chaiyya Chaiyya]
[ar:Sukhwinder Singh, Sapna Awasthi]
[al:Dil Se]
[00:00.00] (Train Rhythm & Heavy Percussion)
[00:14.00] Jinke sar ho ishq ki chhaaon
[00:20.50] Paanv ke neeche jannat hogi
[00:27.20] Chal chaiyya chaiyya chaiyya chaiyya
[00:33.80] Sar ishq ki chhaaon chal chaiyya chaiyya
[00:40.50] Woh yaar hai jo khushboo ki tarah
[00:47.00] Jiski zubaan pe urdu ki tarah
""",
    ),
    CuratedSongEntry(
      id: "hindi_classic_4",
      title: "Kal Ho Naa Ho",
      artist: "Sonu Nigam",
      album: "Kal Ho Naa Ho",
      category: "Classics",
      genre: "Timeless Ballad",
      year: "2003",
      lrcFileName: "kal_ho_naa_ho.lrc",
      defaultDurationMs: 321000,
      demoLyrics: """
[ti:Kal Ho Naa Ho]
[ar:Sonu Nigam]
[al:Kal Ho Naa Ho]
[00:00.00] (Violin & Piano Melody)
[00:12.80] Har ghadi badal rahi hai roop zindagi
[00:21.00] Chhaon hai kabhi kabhi hai dhoop zindagi
[00:29.50] Har pal yahan jee bhar jiyo
[00:37.80] Jo hai sama, kal ho naa ho
[00:46.00] Palkon ke leke saaye
[00:54.00] Paas koi jo aaye
""",
    ),
    CuratedSongEntry(
      id: "hindi_classic_5",
      title: "Tujhe Dekha To",
      artist: "Kumar Sanu, Lata Mangeshkar",
      album: "Dilwale Dulhania Le Jayenge",
      category: "Classics",
      genre: "Evergreen Romance",
      year: "1995",
      lrcFileName: "tujhe_dekha_to.lrc",
      defaultDurationMs: 304000,
      demoLyrics: """
[ti:Tujhe Dekha To]
[ar:Kumar Sanu, Lata Mangeshkar]
[al:Dilwale Dulhania Le Jayenge]
[00:00.00] (Mandolin & Flute Harmony)
[00:11.20] Tujhe dekha toh yeh jaana sanam
[00:18.80] Pyaar hota hai deewana sanam
[00:26.50] Ab yahan se kahan jaayein hum
[00:34.00] Teri baahon mein mar jaayein hum
""",
    ),
    CuratedSongEntry(
      id: "hindi_classic_6",
      title: "Kun Faya Kun",
      artist: "A.R. Rahman, Javed Ali, Mohit Chauhan",
      album: "Rockstar",
      category: "Classics",
      genre: "Divine Sufi",
      year: "2011",
      lrcFileName: "kun_faya_kun.lrc",
      defaultDurationMs: 473000,
      demoLyrics: """
[ti:Kun Faya Kun]
[ar:A.R. Rahman, Javed Ali, Mohit Chauhan]
[al:Rockstar]
[00:00.00] (Nizamuddin Dargah Ambience & Harmonium)
[00:18.00] Ya Nizamuddin Auliya, Ya Nizamuddin Sarkar
[00:34.00] Kadam badha le, hadon ko mita le
[00:42.50] Aaja khalipan mein pukaar le
[00:51.00] Kun faya kun, kun faya kun
[00:59.50] Faya kun, faya kun, faya kun
""",
    ),
    CuratedSongEntry(
      id: "hindi_classic_7",
      title: "Kabira",
      artist: "Tochi Raina, Rekha Bhardwaj",
      album: "Yeh Jawaani Hai Deewani",
      category: "Classics",
      genre: "Soulful Folk",
      year: "2013",
      lrcFileName: "kabira.lrc",
      defaultDurationMs: 251000,
      demoLyrics: """
[ti:Kabira]
[ar:Tochi Raina, Rekha Bhardwaj]
[al:Yeh Jawaani Hai Deewani]
[00:00.00] (Acoustic Guitar & Tabla)
[00:10.00] Kaisi teri khudgarzi
[00:15.50] Na dhoop chune na chhaaon
[00:21.00] Kaisi teri khudgarzi
[00:26.50] Kisi thor tike na paanv
[00:32.00] Re Kabira maan jaa
[00:37.50] Re Faqeera maan jaa
""",
    ),
    CuratedSongEntry(
      id: "hindi_classic_8",
      title: "Lag Ja Gale",
      artist: "Lata Mangeshkar",
      album: "Woh Kaun Thi?",
      category: "Classics",
      genre: "Golden Era Masterpiece",
      year: "1964",
      lrcFileName: "lag_ja_gale.lrc",
      defaultDurationMs: 258000,
      demoLyrics: """
[ti:Lag Ja Gale]
[ar:Lata Mangeshkar]
[al:Woh Kaun Thi?]
[00:00.00] (Sitar & Acoustic Resonance)
[00:12.00] Lag ja gale ki phir yeh
[00:19.50] Haseen raat ho na ho
[00:27.00] Shaayad phir is janam mein
[00:34.50] Mulaqaat ho na ho
[00:42.00] Lag ja gale se...
""",
    ),
    CuratedSongEntry(
      id: "hindi_classic_9",
      title: "Channa Mereya",
      artist: "Arijit Singh",
      album: "Ae Dil Hai Mushkil",
      category: "Classics",
      genre: "Soul Anthem",
      year: "2016",
      lrcFileName: "channa_mereya.lrc",
      defaultDurationMs: 289000,
      demoLyrics: """
[ti:Channa Mereya]
[ar:Arijit Singh]
[al:Ae Dil Hai Mushkil]
[00:00.00] (Acoustic Riff & Footsteps)
[00:14.00] Achha chalta hoon, duaon mein yaad rakhna
[00:22.50] Mere zikr ka zubaan pe swaad rakhna
[00:31.00] Dil ke sandookon mein mere achhe kaam rakhna
[00:39.50] Chithi taaron mein bhi mera tu salaam rakhna
[00:48.00] Andhera tera maine le liya
[00:56.50] Mera ujla sitaara tere naam kiya
[01:05.00] Channa mereya mereya, channa mereya mereya
[01:13.50] O piya...
""",
    ),
  ];

  static List<CuratedSongEntry> get allSongs => [...trendingHits, ...classics];
}
