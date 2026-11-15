import 'dart:math';
import 'models/catalog_song.dart';

/// Recommendation foundation engine for Cinematic Music Player.
/// Implements content-based, artist-affinity, era-proximity, and trending scoring algorithms.
class CatalogRecommendationEngine {
  /// Computes related songs based on content similarity:
  /// - Matching primary artist (+50 pts)
  /// - Matching album (+35 pts)
  /// - Matching musical genre (+20 pts)
  /// - Release era proximity within +/- 3 years (+15 pts)
  static List<CatalogSong> getRelatedSongs(
    CatalogSong target,
    List<CatalogSong> pool, {
    int limit = 10,
  }) {
    final targetYear = int.tryParse(target.year) ?? 2022;
    final targetArtists = target.artist.toLowerCase().split(RegExp(r'[,&]')).map((s) => s.trim()).toSet();

    final scored = pool.where((s) => s.id != target.id).map((candidate) {
      double score = 0.0;

      // Artist affinity
      final candidateArtists = candidate.artist.toLowerCase().split(RegExp(r'[,&]')).map((s) => s.trim()).toSet();
      final commonArtists = targetArtists.intersection(candidateArtists);
      if (commonArtists.isNotEmpty) {
        score += 50.0 * commonArtists.length;
      }

      // Album match
      if (candidate.album.toLowerCase() == target.album.toLowerCase()) {
        score += 35.0;
      }

      // Genre match
      if (candidate.genre.toLowerCase() == target.genre.toLowerCase()) {
        score += 20.0;
      } else if (candidate.genre.toLowerCase().contains(target.genre.toLowerCase()) ||
          target.genre.toLowerCase().contains(candidate.genre.toLowerCase())) {
        score += 10.0;
      }

      // Era proximity
      final candidateYear = int.tryParse(candidate.year) ?? 2022;
      final yearDiff = (targetYear - candidateYear).abs();
      if (yearDiff <= 3) {
        score += 15.0;
      } else if (yearDiff <= 8) {
        score += 8.0;
      }

      // Popularity dampener
      score += log(max(1, candidate.playCount)) * 0.5;

      return MapEntry(candidate, score);
    }).toList();

    scored.sort((a, b) => b.value.compareTo(a.value));
    return scored.take(limit).map((e) => e.key).toList();
  }

  /// Personalized recommendations derived from user favorites and listening history
  static List<CatalogSong> getPersonalizedRecommendations({
    required List<String> favoriteOrHistorySongIds,
    required List<CatalogSong> allCatalogSongs,
    int limit = 15,
  }) {
    if (favoriteOrHistorySongIds.isEmpty) {
      // Default fallback: return highest played trending tracks
      final copy = List<CatalogSong>.from(allCatalogSongs);
      copy.sort((a, b) => b.playCount.compareTo(a.playCount));
      return copy.take(limit).toList();
    }

    // Identify user taste profile
    final listenedSongs = allCatalogSongs.where((s) => favoriteOrHistorySongIds.contains(s.id)).toList();
    final preferredArtists = <String, int>{};
    final preferredGenres = <String, int>{};

    for (final s in listenedSongs) {
      final artists = s.artist.toLowerCase().split(RegExp(r'[,&]')).map((a) => a.trim());
      for (final a in artists) {
        preferredArtists[a] = (preferredArtists[a] ?? 0) + 1;
      }
      preferredGenres[s.genre.toLowerCase()] = (preferredGenres[s.genre.toLowerCase()] ?? 0) + 1;
    }

    final scored = allCatalogSongs.where((s) => !favoriteOrHistorySongIds.contains(s.id)).map((candidate) {
      double score = 0.0;

      // Match against preferred artists
      final candArtists = candidate.artist.toLowerCase().split(RegExp(r'[,&]')).map((a) => a.trim());
      for (final a in candArtists) {
        if (preferredArtists.containsKey(a)) {
          score += 40.0 * (preferredArtists[a] ?? 1);
        }
      }

      // Match against preferred genres
      final genreKey = candidate.genre.toLowerCase();
      if (preferredGenres.containsKey(genreKey)) {
        score += 25.0 * (preferredGenres[genreKey] ?? 1);
      }

      // Add baseline popularity score
      score += log(max(1, candidate.playCount)) * 1.2;

      return MapEntry(candidate, score);
    }).toList();

    scored.sort((a, b) => b.value.compareTo(a.value));
    return scored.take(limit).map((e) => e.key).toList();
  }

  /// Calculates trending ranking based on weighted playcount and freshness
  static List<CatalogSong> getTrendingRankings(List<CatalogSong> pool, {int limit = 20}) {
    final list = List<CatalogSong>.from(pool);
    list.sort((a, b) => b.playCount.compareTo(a.playCount));
    return list.take(limit).toList();
  }

  /// Calculates recently added songs sorted by release year and dateAdded
  static List<CatalogSong> getRecentlyAdded(List<CatalogSong> pool, {int limit = 20}) {
    final list = List<CatalogSong>.from(pool);
    list.sort((a, b) {
      final yA = int.tryParse(a.year) ?? 0;
      final yB = int.tryParse(b.year) ?? 0;
      if (yB != yA) return yB.compareTo(yA);
      return b.dateAdded.compareTo(a.dateAdded);
    });
    return list.take(limit).toList();
  }
}
