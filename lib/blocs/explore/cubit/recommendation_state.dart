part of 'recommendation_cubit.dart';

sealed class RecommendationState {
  const RecommendationState();
}

class RecommendationInitial extends RecommendationState {
  const RecommendationInitial();
}

class RecommendationLoaded extends RecommendationState {
  final List<Track> tracks;
  final Map<String, String> reasons; // trackId -> artist name
  final String? topArtistName;

  const RecommendationLoaded({
    required this.tracks,
    required this.reasons,
    this.topArtistName,
  });
}
