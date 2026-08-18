import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:iconsx_plus/iconsx_plus.dart';
import 'package:responsive_framework/responsive_framework.dart';

import 'package:music_deewane/blocs/explore/cubit/recommendation_cubit.dart';
import 'package:music_deewane/blocs/media_player/music_deewane_player_cubit.dart';
import 'package:music_deewane/core/models/exported.dart';
import 'package:music_deewane/core/models/media_playlist_model.dart';
import 'package:music_deewane/core/theme/app_theme.dart';
import 'package:music_deewane/l10n/app_localizations.dart';
import 'package:music_deewane/screens/widgets/more_bottom_sheet.dart';
import 'package:music_deewane/screens/widgets/hover_wrapper.dart';
import 'package:music_deewane/utils/load_image.dart';

/// "For You" section on the Explore screen.
/// Shows personalized recommendations for the user's top artist,
/// with a paginated grid layout matching TopPicksWidget.
class ForYouSection extends StatelessWidget {
  const ForYouSection({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<RecommendationCubit, RecommendationState>(
      builder: (context, state) {
        if (state is RecommendationInitial) {
          return const SizedBox.shrink();
        }

        if (state is! RecommendationLoaded) return const SizedBox.shrink();

        if (state.tracks.isEmpty || state.topArtistName == null) {
          final l10n = AppLocalizations.of(context);
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: Row(
              children: [
                Icon(
                  MingCute.star_line,
                  size: 20,
                  color: Default_Theme.primaryColor1.withValues(alpha: 0.3),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    l10n?.forYouEmpty ??
                        'Play some music to get personalized recommendations.',
                    style: TextStyle(
                      fontSize: 13,
                      color: Default_Theme.primaryColor1.withValues(alpha: 0.4),
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        return _ForYouTopicGroup(
          artistName: state.topArtistName!,
          tracks: state.tracks,
          allTracks: state.tracks,
        );
      },
    );
  }
}

/// A single topic group: "Because you listened to [Artist]" header + paginated grid.
class _ForYouTopicGroup extends StatefulWidget {
  final String artistName;
  final List<Track> tracks;
  final List<Track> allTracks;

  const _ForYouTopicGroup({
    required this.artistName,
    required this.tracks,
    required this.allTracks,
  });

  @override
  State<_ForYouTopicGroup> createState() => _ForYouTopicGroupState();
}

class _ForYouTopicGroupState extends State<_ForYouTopicGroup> {
  int _currentPage = 0;
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _pageController.addListener(() {
      final page = _pageController.page?.round() ?? 0;
      if (page != _currentPage) {
        setState(() => _currentPage = page);
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveBreakpoints.of(context).smallerOrEqualTo(TABLET);
    final crossAxisCount = isMobile ? 3 : 5;
    final rows = isMobile ? 3 : 4;
    final itemsPerPage = crossAxisCount * rows;
    final pageCount = (widget.tracks.length / itemsPerPage).ceil();

    return Padding(
      padding: const EdgeInsets.only(top: 28.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Because you listened to ${widget.artistName}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Default_Theme.primaryColor1,
                    ).merge(Default_Theme.secondoryTextStyle),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Spacer(),
                Hoverable(
                  child: IconButton(
                    icon: const Icon(
                      MingCute.refresh_2_line,
                      color: Default_Theme.primaryColor1,
                      size: 22,
                    ),
                    onPressed: () {
                      context.read<RecommendationCubit>().refresh();
                    },
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: rows * 110.0,
            child: PageView.builder(
              controller: _pageController,
              itemCount: pageCount,
              itemBuilder: (context, pageIndex) {
                final startIndex = pageIndex * itemsPerPage;
                final endIndex =
                    (startIndex + itemsPerPage).clamp(0, widget.tracks.length);
                final pageTracks = widget.tracks.sublist(startIndex, endIndex);

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: GridView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      childAspectRatio: 0.9,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                    ),
                    itemCount: pageTracks.length,
                    itemBuilder: (context, index) {
                      final track = pageTracks[index];
                      return _ForYouCard(
                        track: track,
                        allTracks: widget.allTracks,
                        onTap: () {
                          context
                              .read<MusicDeewanePlayerCubit>()
                              .player
                              .loadPlaylist(
                                Playlist(
                                  tracks: widget.allTracks,
                                  title: 'For You',
                                ),
                                idx: widget.allTracks.indexOf(track),
                                doPlay: true,
                              );
                        },
                        onLongPress: () => showMoreBottomSheet(
                          context,
                          track,
                          showSinglePlay: true,
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
          if (pageCount > 1)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  pageCount,
                  (index) => Container(
                    width: index == _currentPage ? 8 : 6,
                    height: index == _currentPage ? 8 : 6,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: index == _currentPage
                          ? Default_Theme.primaryColor1
                          : Default_Theme.primaryColor1.withValues(alpha: 0.3),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ForYouCard extends StatefulWidget {
  final Track track;
  final List<Track> allTracks;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _ForYouCard({
    required this.track,
    required this.allTracks,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  State<_ForYouCard> createState() => _ForYouCardState();
}

class _ForYouCardState extends State<_ForYouCard> {
  bool _pressed = false;
  bool _hovering = false;

  void _onTapDown(TapDownDetails _) => setState(() => _pressed = true);
  void _onTapUp(TapUpDetails _) => setState(() => _pressed = false);
  void _onTapCancel() => setState(() => _pressed = false);

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        onTapDown: _onTapDown,
        onTapUp: _onTapUp,
        onTapCancel: _onTapCancel,
        child: AnimatedScale(
          scale: _pressed ? 0.96 : 1.0,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          child: AnimatedOpacity(
            opacity: _pressed ? 0.85 : 1.0,
            duration: const Duration(milliseconds: 120),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              decoration: BoxDecoration(
                color: _hovering
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    LoadImageCached.deterministic(
                      imageUrl: widget.track.thumbnail.url,
                      fallbackUrl: widget.track.thumbnail.urlLow ??
                          widget.track.thumbnail.url,
                    ),
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      height: 50,
                      child: Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black54,
                            ],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 6,
                      left: 6,
                      right: 6,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.track.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.track.artists.map((a) => a.name).join(', '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.6),
                              fontSize: 9,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
