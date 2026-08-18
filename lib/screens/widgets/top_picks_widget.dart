import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:iconsx_plus/iconsx_plus.dart';
import 'package:responsive_framework/responsive_framework.dart';

import 'package:music_deewane/blocs/explore/cubit/recently_cubit.dart';
import 'package:music_deewane/blocs/media_player/music_deewane_player_cubit.dart';
import 'package:music_deewane/core/models/exported.dart';
import 'package:music_deewane/core/models/media_playlist_model.dart';
import 'package:music_deewane/core/theme/app_theme.dart';
import 'package:music_deewane/screens/widgets/more_bottom_sheet.dart';
import 'package:music_deewane/screens/widgets/hover_wrapper.dart';
import 'package:music_deewane/utils/load_image.dart';

class TopPicksWidget extends StatefulWidget {
  const TopPicksWidget({super.key});

  @override
  State<TopPicksWidget> createState() => _TopPicksWidgetState();
}

class _TopPicksWidgetState extends State<TopPicksWidget> {
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

  List<Track> _shuffleTracks(List<Track> tracks) {
    final shuffled = List<Track>.from(tracks);
    shuffled.shuffle(math.Random());
    return shuffled;
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveBreakpoints.of(context).smallerOrEqualTo(TABLET);

    return BlocBuilder<RecentlyCubit, RecentlyCubitState>(
      builder: (context, state) {
        if (state is RecentlyCubitInitial) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: SizedBox(
                height: 40,
                width: 40,
                child: CircularProgressIndicator(
                  color: Default_Theme.accentColor2,
                ),
              ),
            ),
          );
        }

        if (state.tracks.isEmpty) return const SizedBox.shrink();

        final tracks = _shuffleTracks(state.tracks);
        final crossAxisCount = isMobile ? 3 : 5;
        final rows = isMobile ? 3 : 4;
        final itemsPerPage = crossAxisCount * rows;
        final pageCount = (tracks.length / itemsPerPage).ceil();

        return Padding(
          padding: const EdgeInsets.only(top: 15.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Text(
                      'Top Picks',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Default_Theme.accentColor2,
                      ).merge(Default_Theme.secondoryTextStyle),
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
                          setState(() {
                            _currentPage = 0;
                          });
                          if (_pageController.hasClients) {
                            _pageController.jumpToPage(0);
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
              LayoutBuilder(
                builder: (context, constraints) {
                  // Grid needs rows*rows of tiles; derive tile height from
                  // the real available width so the last row is never clipped.
                  const horizontalGridPadding = 12.0;
                  const crossAxisSpacing = 8.0;
                  const mainAxisSpacing = 8.0;
                  const childAspectRatio = 0.9;
                  final tileWidth =
                      (constraints.maxWidth - (horizontalGridPadding * 2)) /
                          crossAxisCount;
                  final tileHeight = tileWidth / childAspectRatio;
                  final gridHeight =
                      rows * tileHeight + (rows - 1) * mainAxisSpacing;

                  return SizedBox(
                    height: gridHeight,
                    child: PageView.builder(
                      controller: _pageController,
                      itemCount: pageCount,
                      itemBuilder: (context, pageIndex) {
                        final startIndex = pageIndex * itemsPerPage;
                        final endIndex =
                            (startIndex + itemsPerPage).clamp(0, tracks.length);
                        final pageTracks = tracks.sublist(startIndex, endIndex);

                        return Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: horizontalGridPadding),
                          child: GridView.builder(
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: crossAxisCount,
                              childAspectRatio: childAspectRatio,
                              crossAxisSpacing: crossAxisSpacing,
                              mainAxisSpacing: mainAxisSpacing,
                            ),
                            itemCount: pageTracks.length,
                            itemBuilder: (context, index) {
                              final track = pageTracks[index];
                              return _TopPickCard(
                                track: track,
                                onTap: () {
                                  context
                                      .read<MusicDeewanePlayerCubit>()
                                      .player
                                      .loadPlaylist(
                                        Playlist(
                                          tracks: tracks,
                                          title: 'Top Picks',
                                        ),
                                        idx: startIndex + index,
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
                  );
                },
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
                              : Default_Theme.primaryColor1
                                  .withValues(alpha: 0.3),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _TopPickCard extends StatefulWidget {
  final Track track;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _TopPickCard({
    required this.track,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  State<_TopPickCard> createState() => _TopPickCardState();
}

class _TopPickCardState extends State<_TopPickCard> {
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
