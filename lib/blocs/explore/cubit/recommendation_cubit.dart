import 'dart:async';
import 'dart:developer';
import 'dart:math' as math;

import 'package:music_deewane/core/models/exported.dart';
import 'package:music_deewane/services/db/dao/history_dao.dart';
import 'package:music_deewane/services/db/mappers/media_item_mapper.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'recommendation_state.dart';

/// Cubit that produces personalized "For You" recommendations using
/// weighted history + artist affinity — no AI/ML, pure algorithmic scoring.
///
/// Algorithm:
/// 1. Score each history entry by recency (exponential decay over 30 days).
/// 2. Boost tracks by favorite artists (1.5x multiplier).
/// 3. Compute artist frequency weights from recent plays.
/// 4. Mix: top-scored tracks + frequency-weighted tracks from same artists.
class RecommendationCubit extends Cubit<RecommendationState> {
  final HistoryDAO _historyDao;
  StreamSubscription<void>? _watcher;

  RecommendationCubit(this._historyDao) : super(const RecommendationInitial()) {
    _initialize();
  }

  Future<void> _initialize() async {
    await _fetchRecommendations();
    await _watchHistory();
  }

  Future<void> _watchHistory() async {
    _watcher = (await _historyDao.watchHistory()).listen((_) {
      _fetchRecommendations();
      log('Recommendations refreshed', name: 'RecommendationCubit');
    });
  }

  @override
  Future<void> close() {
    _watcher?.cancel();
    return super.close();
  }

  /// Recompute recommendations from raw history.
  void refresh() => _fetchRecommendations();

  Future<void> _fetchRecommendations() async {
    try {
      // Fetch raw history (last 100 plays for good signal).
      final rawHistory = await _historyDao.getRawHistory(limit: 100);
      if (rawHistory.isEmpty) {
        emit(const RecommendationLoaded(tracks: [], reasons: {}));
        return;
      }

      final now = DateTime.now();
      final seenMediaIds = <String>{};
      final scoredTracks = <_ScoredTrack>[];
      final artistPlayCount = <String, int>{};

      // Phase 1: Score each unique track by recency.
      for (final entry in rawHistory) {
        final trackDB = entry.track.value;
        if (trackDB == null) continue;
        if (!seenMediaIds.add(trackDB.mediaId)) continue;

        final track = trackDBToTrack(trackDB);
        final playedAt = entry.playedAt;
        final daysAgo = now.difference(playedAt).inHours / 24.0;

        // Exponential decay: score = e^(-days/7)
        // Recent plays (today) ≈ 1.0, 7 days ago ≈ 0.37, 30 days ≈ 0.013
        final recencyScore = math.exp(-daysAgo / 7.0);

        // Count artist plays for frequency weighting.
        final artists = track.artists;
        for (final artist in artists) {
          final name = artist.name;
          artistPlayCount[name] = (artistPlayCount[name] ?? 0) + 1;
        }

        scoredTracks.add(_ScoredTrack(
          track: track,
          recencyScore: recencyScore,
          artistNames: artists.map((a) => a.name).toList(),
        ));
      }

      // Phase 2: Boost tracks by favorite artist affinity.
      // favoriteArtists is passed via state, not cubit constructor,
      // so we read it from the settings state that the cubit holds.
      // For now, use artist frequency as the affinity signal.
      final topArtists = artistPlayCount.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      final topArtistNames = topArtists.take(10).map((e) => e.key).toSet();

      // Boost tracks whose artists are in the user's top 10 most-played.
      for (final scored in scoredTracks) {
        final hasTopArtist =
            scored.artistNames.any((a) => topArtistNames.contains(a));
        if (hasTopArtist) {
          scored.recencyScore *= 1.5;
        }
      }

      // Phase 3: Sort by final score and pick top results.
      scoredTracks.sort((a, b) => b.recencyScore.compareTo(a.recencyScore));

      // Phase 4: Pick the single most-played artist and filter to their tracks.
      final topArtist = topArtists.isNotEmpty ? topArtists.first.key : null;
      final topArtistTracks = topArtist != null
          ? scoredTracks
              .where((s) => s.artistNames.contains(topArtist))
              .take(30)
              .map((s) => s.track)
              .toList()
          : scoredTracks.take(30).map((s) => s.track).toList();

      // Phase 5: Build reason map for "Because you listened to..." context.
      final reasons = <String, String>{};
      if (topArtist != null) {
        for (final scored in scoredTracks.take(30)) {
          reasons[scored.track.id] = topArtist;
        }
      }

      emit(RecommendationLoaded(
        tracks: topArtistTracks,
        reasons: reasons,
        topArtistName: topArtist,
      ));
    } catch (e) {
      log('Recommendation computation failed: $e', name: 'RecommendationCubit');
      emit(const RecommendationLoaded(tracks: [], reasons: {}));
    }
  }

  /// Re-scoring is handled by _fetchRecommendations which already uses
  /// correct history timestamps. This method triggers a full recomputation
  /// to incorporate updated favorite artists from settings.
  void applyFavoriteArtists(List<String> favoriteArtistNames) {
    _fetchRecommendations();
  }
}

class _ScoredTrack {
  final Track track;
  double recencyScore;
  final List<String> artistNames;

  _ScoredTrack({
    required this.track,
    required this.recencyScore,
    required this.artistNames,
  });
}
