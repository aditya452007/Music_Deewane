import 'package:music_deewane/core/models/exported.dart';

/// A null/empty [Track] sentinel used as a default value
/// where a non-nullable Track is required but no track is loaded.
const Track trackNull = Track(
  id: 'Null',
  title: 'Null',
  artists: [],
  thumbnail: Artwork(url: '', layout: ImageLayout.square),
  isExplicit: false,
);

/// Check whether a [Track] is the null sentinel.
bool isTrackNull(Track track) => track.id == 'Null' && track.title == 'Null';
