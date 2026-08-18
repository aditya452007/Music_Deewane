import 'dart:async';

import 'package:music_deewane/blocs/add_to_playlist/cubit/add_to_playlist_cubit.dart';
import 'package:music_deewane/blocs/downloader/cubit/downloader_cubit.dart';
import 'package:music_deewane/blocs/library/cubit/library_items_cubit.dart';
import 'package:music_deewane/blocs/lyrics/lyrics_cubit.dart';
import 'package:music_deewane/blocs/player_overlay/player_overlay_cubit.dart';
import 'package:music_deewane/core/adapters/track_adapter.dart';

import 'package:music_deewane/screens/widgets/more_bottom_sheet.dart';
import 'package:music_deewane/screens/widgets/hover_wrapper.dart';
import 'package:music_deewane/screens/widgets/organic_player_control.dart';
import 'package:music_deewane/screens/widgets/player_overlay_wrapper.dart';
import 'package:music_deewane/screens/widgets/up_next_panel.dart';
import 'package:music_deewane/screens/widgets/volume_slider.dart';
import 'package:music_deewane/screens/widgets/wave_progress_bar.dart';
import 'package:music_deewane/screens/widgets/media_metadata_links.dart';
import 'package:music_deewane/screens/screen/player_views/segments_sheet.dart';
import 'package:music_deewane/screens/screen/home_views/timer_view.dart';
import 'package:music_deewane/services/music_deewane_player.dart';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:music_deewane/l10n/app_localizations.dart';
import 'package:iconsx_plus/iconsx_plus.dart';
import 'package:music_deewane/services/player/player_engine.dart';
import 'package:music_deewane/screens/widgets/like_widget.dart';
import 'package:music_deewane/screens/widgets/play_pause_widget.dart';
import 'package:music_deewane/screens/widgets/snackbar.dart';
import 'package:music_deewane/core/theme/app_theme.dart';
import 'package:music_deewane/utils/load_image.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:share_plus/share_plus.dart';
import 'package:go_router/go_router.dart';
import '../../blocs/media_player/music_deewane_player_cubit.dart';
import '../../blocs/mini_player/mini_player_cubit.dart';
import '../../core/constants/route_paths.dart';

class AudioPlayerView extends StatefulWidget {
  const AudioPlayerView({super.key});

  @override
  State<AudioPlayerView> createState() => _AudioPlayerViewState();
}

class _AudioPlayerViewState extends State<AudioPlayerView>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final UpNextPanelController _upNextPanelController = UpNextPanelController();
  bool _showLyrics = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<PlayerOverlayCubit>().registerUpNextPanelCollapse(
              () => _upNextPanelController.collapse(),
            );
      }
    });
  }

  @override
  void dispose() {
    context.read<PlayerOverlayCubit>().unregisterUpNextPanelCollapse();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final playerCubit = context.read<MusicDeewanePlayerCubit>();
    final musicPlayer = playerCubit.player;
    final isMobile = ResponsiveBreakpoints.of(context).smallerOrEqualTo(TABLET);

    return Scaffold(
      backgroundColor: Default_Theme.themeColor,
      resizeToAvoidBottomInset: false,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Default_Theme.primaryColor1,
        centerTitle: true,
        leading: Hoverable(
          child: IconButton(
            icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 32),
            onPressed: () {
              if (!_upNextPanelController.collapse()) {
                context.read<PlayerOverlayCubit>().hidePlayer();
              }
            },
          ),
        ),
        actions: [
          Hoverable(
            child: IconButton(
              onPressed: () {
                final mi = musicPlayer.mediaItem.valueOrNull;
                if (mi != null) {
                  showSegmentsSheet(
                    context,
                    trackId: mi.id,
                    trackDuration: mi.duration ?? Duration.zero,
                    onSeek: (pos) => musicPlayer.seek(pos),
                  );
                }
              },
              icon: const Icon(MingCute.list_check_3_line,
                  size: 22, color: Default_Theme.primaryColor1),
            ),
          ),
          Hoverable(
            child: IconButton(
              onPressed: () {
                final expandNotifier = PlayerExpandNotifier.of(context);
                expandNotifier.value = !expandNotifier.value;
              },
              icon: ValueListenableBuilder<bool>(
                valueListenable: PlayerExpandNotifier.of(context),
                builder: (context, isExpanded, _) => Icon(
                  isExpanded
                      ? MingCute.fullscreen_exit_line
                      : MingCute.fullscreen_line,
                  size: 22,
                  color: Default_Theme.primaryColor1,
                ),
              ),
            ),
          ),
          Hoverable(
            child: IconButton(
              onPressed: () => showMoreBottomSheet(
                context,
                musicPlayer.currentMedia,
                showPlayerActions: true,
              ),
              icon: const Icon(MingCute.more_2_fill,
                  size: 25, color: Default_Theme.primaryColor1),
            ),
          )
        ],
        title: Column(
          children: [
            Text(
              l10n.playerEnjoyingFrom,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Default_Theme.primaryColor1,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ).merge(Default_Theme.secondoryTextStyle),
            ),
            StreamBuilder<String>(
              stream: musicPlayer.queueTitle,
              builder: (context, snapshot) {
                return Text(
                  snapshot.data ?? l10n.playerUnknownQueue,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Default_Theme.primaryColor2,
                    fontSize: 12,
                  ).merge(Default_Theme.secondoryTextStyle),
                );
              },
            ),
          ],
        ),
      ),
      body: AnimatedSwitcher(
        duration: const Duration(seconds: 1),
        child: isMobile
            ? LayoutBuilder(
                builder: (context, constraints) {
                  return Stack(
                    alignment: Alignment.bottomCenter,
                    children: [
                      Positioned.fill(
                        child: _PlayerUI(
                          musicPlayer: musicPlayer,
                          tabController: _tabController,
                          showLyrics: _showLyrics,
                          onToggleLyrics: () => setState(() => _showLyrics = !_showLyrics),
                        ),
                      ),
                      UpNextPanel(
                        peekHeight: 60.0,
                        parentHeight: constraints.maxHeight,
                        controller: _upNextPanelController,
                      ),
                    ],
                  );
                },
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      minWidth: 400,
                      maxWidth: MediaQuery.of(context).size.width * 0.60,
                    ),
                      child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: _PlayerUI(
                        musicPlayer: musicPlayer,
                        tabController: _tabController,
                        showLyrics: _showLyrics,
                        onToggleLyrics: () => setState(() => _showLyrics = !_showLyrics),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(15.0),
                      child: SizedBox(
                        height: MediaQuery.of(context).size.height * 0.8,
                        child: UpNextPanel(
                          peekHeight: 60,
                          parentHeight:
                              MediaQuery.of(context).size.height * 0.8,
                          isDesktopMode: true,
                          controller: _upNextPanelController,
                        ),
                      ),
                    ),
                  )
                ],
              ),
      ),
    );
  }
}

class _PlayerUI extends StatelessWidget {
  final MusicDeewanePlayer musicPlayer;
  final TabController tabController;
  final bool showLyrics;
  final VoidCallback onToggleLyrics;

  const _PlayerUI({
    required this.musicPlayer,
    required this.tabController,
    required this.showLyrics,
    required this.onToggleLyrics,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveBreakpoints.of(context).smallerOrEqualTo(TABLET);
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    return Stack(
      alignment: Alignment.center,
      children: [
        const Positioned.fill(
          child: RepaintBoundary(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  colors: [
                    Color(0xFF141417),
                    Default_Theme.themeColor,
                  ],
                  center: Alignment.center,
                  radius: 0.85,
                ),
              ),
            ),
          ),
        ),
        SafeArea(
          bottom: false,
          child: Column(
            mainAxisSize: MainAxisSize.max,
            children: [
              SizedBox(height: isMobile ? 56 : 64),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                      horizontal: isMobile ? 20 : 32, vertical: 4),
                  child: CoverImageVolSlider(
                    showLyrics: showLyrics,
                    onToggleLyrics: onToggleLyrics,
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(
                    horizontal: isMobile ? 20 : 32),
                child: PlayerCtrlWidgets(
                  musicPlayer: musicPlayer,
                  showVolumeSlider: !isMobile,
                  showLyrics: showLyrics,
                  onToggleLyrics: onToggleLyrics,
                ),
              ),
              // ponytail: queue finished message — simple StreamBuilder, no new state
              StreamBuilder<MediaItem?>(
                stream: musicPlayer.mediaItem,
                builder: (context, mediaSnap) {
                  if (mediaSnap.data == null) return const SizedBox.shrink();
                  return BlocBuilder<MiniPlayerCubit, MiniPlayerState>(
                    builder: (context, state) {
                      if (!state.isCompleted) return const SizedBox.shrink();
                      return GestureDetector(
                        onTap: () => context.goNamed(RoutePaths.searchScreen),
                        child: Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            AppLocalizations.of(context)!.playerQueueFinished,
                            style: TextStyle(
                              color: Default_Theme.primaryColor1
                                  .withValues(alpha: 0.6),
                              fontSize: 13,
                              decoration: TextDecoration.underline,
                              decorationColor: Default_Theme.primaryColor1
                                  .withValues(alpha: 0.3),
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
              SizedBox(height: (bottomPadding > 0 ? bottomPadding : 24) + 56),
            ],
          ),
        ),
      ],
    );
  }
}

class CoverImageVolSlider extends StatelessWidget {
  final bool showLyrics;
  final VoidCallback onToggleLyrics;

  const CoverImageVolSlider({
    super.key,
    this.showLyrics = false,
    required this.onToggleLyrics,
  });

  void _handleArtworkTap(TapUpDetails details, BuildContext context) {
    final playerCubit = context.read<MusicDeewanePlayerCubit>();
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return;
    final localX = box.globalToLocal(details.globalPosition).dx;
    final isLeftHalf = localX < box.size.width / 2;
    if (isLeftHalf) {
      playerCubit.player
          .seekNSecBackward(const Duration(seconds: 10));
    } else {
      playerCubit.player
          .seekNSecForward(const Duration(seconds: 10));
    }
  }

  @override
  Widget build(BuildContext context) {
    final playerCubit = context.read<MusicDeewanePlayerCubit>();

    return VolumeDragController(
      child: showLyrics
          ? MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: onToggleLyrics,
                child: const _InlineLyricsView(),
              ),
            )
          : StreamBuilder<MediaItem?>(
              stream: playerCubit.player.mediaItem,
              builder: (context, snapshot) {
                final currentTrack = playerCubit.player.currentTrackInfo;
                final highResUrl =
                    currentTrack.thumbnail.urlHigh ?? currentTrack.thumbnail.url;
                final lowResUrl =
                    currentTrack.thumbnail.urlLow ?? currentTrack.thumbnail.url;

                return MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTapUp: (d) => _handleArtworkTap(d, context),
                    child: SizedBox.expand(
                      child: Center(
                        child: AspectRatio(
                          aspectRatio: 1.0,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: LoadImageCached(
                              imageUrl: highResUrl,
                              fallbackUrl: lowResUrl,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class PlayerCtrlWidgets extends StatelessWidget {
  final MusicDeewanePlayer musicPlayer;
  final bool showVolumeSlider;
  final bool showLyrics;
  final VoidCallback onToggleLyrics;
  const PlayerCtrlWidgets({
    super.key,
    required this.musicPlayer,
    this.showVolumeSlider = false,
    required this.showLyrics,
    required this.onToggleLyrics,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const _SongInfoRow(),
        SizedBox(height: showVolumeSlider ? 8 : 10),
        _ActionPillsRow(
          showLyrics: showLyrics,
          onToggleLyrics: onToggleLyrics,
          isDesktop: showVolumeSlider,
        ),
        const SizedBox(height: 10),
        const _PlayerProgressBar(),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Tooltip(
              message: AppLocalizations.of(context)!.playerShuffle,
              child: const _ShuffleControl(),
            ),
            if (showVolumeSlider) ...[
              const SizedBox(width: 12),
              Tooltip(
                message: AppLocalizations.of(context)!.playerSeekBack10,
                child: OrganicIconButton(
                  icon: Icons.replay_10_outlined,
                  iconSize: 20,
                  size: 44,
                  onPressed: () =>
                      musicPlayer.seekNSecBackward(const Duration(seconds: 10)),
                ),
              ),
            ],
            const SizedBox(width: 16),
            Tooltip(
              message: AppLocalizations.of(context)!.playerSkipPrevious,
              child: OrganicIconButton(
                icon: MingCute.skip_previous_fill,
                iconSize: 24,
                size: 52,
                onPressed: musicPlayer.skipToPrevious,
              ),
            ),
            const SizedBox(width: 20),
            const _PlayPauseButton(),
            const SizedBox(width: 20),
            Tooltip(
              message: AppLocalizations.of(context)!.playerSkipNext,
              child: OrganicIconButton(
                icon: MingCute.skip_forward_fill,
                iconSize: 24,
                size: 52,
                onPressed: musicPlayer.skipToNext,
              ),
            ),
            if (showVolumeSlider) ...[
              const SizedBox(width: 16),
              Tooltip(
                message: AppLocalizations.of(context)!.playerSeekForward10,
                child: OrganicIconButton(
                  icon: Icons.forward_10_outlined,
                  iconSize: 20,
                  size: 44,
                  onPressed: () =>
                      musicPlayer.seekNSecForward(const Duration(seconds: 10)),
                ),
              ),
            ],
            const SizedBox(width: 12),
            Tooltip(
              message: AppLocalizations.of(context)!.playerLoop,
              child: const _LoopControl(),
            ),
            if (showVolumeSlider) ...[
              const SizedBox(width: 24),
              SizedBox(
                width: 140,
                child: _PlayerVolumeControl(musicPlayer: musicPlayer),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class _SongInfoRow extends StatelessWidget {
  const _SongInfoRow();

  @override
  Widget build(BuildContext context) {
    final player = context.read<MusicDeewanePlayerCubit>().player;
    return StreamBuilder<MediaItem?>(
      stream: player.mediaItem,
      builder: (context, snapshot) {
        final currentTrack = player.currentTrackInfo;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              currentTrack.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style:
                  Default_Theme.secondoryTextStyle.merge(const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: Default_Theme.primaryColor1,
              )),
            ),
            const SizedBox(height: 4),
            TrackMetadataLinks(
              track: currentTrack,
              showAlbum: currentTrack.album != null,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Default_Theme.secondoryTextStyle.merge(TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: Default_Theme.primaryColor1.withValues(alpha: 0.7),
              )),
            ),
          ],
        );
      },
    );
  }
}

/// Horizontally scrollable action pills row — mobile and desktop.
/// YouTube Music pattern: sits between song info and progress bar.
class _ActionPillsRow extends StatelessWidget {
  final bool showLyrics;
  final VoidCallback onToggleLyrics;
  final bool isDesktop;
  const _ActionPillsRow({
    required this.showLyrics,
    required this.onToggleLyrics,
    this.isDesktop = false,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SizedBox(
      height: isDesktop ? 44 : 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        children: [
          _ActionPill(
            icon: MingCute.heart_line,
            label: l10n.playerAddToFavorites,
            isDesktop: isDesktop,
            onTap: () {
              final player = context.read<MusicDeewanePlayerCubit>().player;
              final currentMedia = player.mediaItem.valueOrNull;
              if (currentMedia == null) return;
              final libCubit = context.read<LibraryItemsCubit>();
              libCubit.setTrackLiked(mediaItemToTrack(currentMedia), true);
              SnackbarService.showMessage(
                  l10n.playerLiked(currentMedia.title));
            },
          ),
          _ActionPill(
            icon: MingCute.download_2_line,
            label: l10n.menuDownload,
            isDesktop: isDesktop,
            onTap: () {
              final player = context.read<MusicDeewanePlayerCubit>().player;
              final currentMedia = player.mediaItem.valueOrNull;
              if (currentMedia == null) return;
              context
                  .read<DownloaderCubit>()
                  .downloadSong(mediaItemToTrack(currentMedia));
            },
          ),
          _ActionPill(
            icon: MingCute.align_center_line,
            label: l10n.playerLyrics,
            isActive: showLyrics,
            isDesktop: isDesktop,
            onTap: onToggleLyrics,
          ),
          _ActionPill(
            icon: MingCute.share_forward_line,
            label: l10n.menuShare,
            isDesktop: isDesktop,
            onTap: () {
              final player = context.read<MusicDeewanePlayerCubit>().player;
              final currentMedia = player.mediaItem.valueOrNull;
              if (currentMedia == null) return;
              SnackbarService.showMessage(
                  l10n.menuSharePreparing(currentMedia.title));
              final trackUrl = player.currentTrackInfo.url;
              if (trackUrl?.isNotEmpty ?? false) {
                SharePlus.instance.share(ShareParams(
                    text: trackUrl!, subject: currentMedia.title));
              }
            },
          ),
          _ActionPill(
            icon: MingCute.playlist_2_line,
            label: l10n.playerAddToQueue,
            isDesktop: isDesktop,
            onTap: () {
              final player = context.read<MusicDeewanePlayerCubit>().player;
              final currentMedia = player.mediaItem.valueOrNull;
              if (currentMedia == null) return;
              player.addQueueTracks([mediaItemToTrack(currentMedia)]);
              SnackbarService.showMessage(l10n.snackbarAddedToQueue);
            },
          ),
          _ActionPill(
            icon: MingCute.alarm_1_line,
            label: l10n.playerTimer,
            isDesktop: isDesktop,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const TimerView()),
              );
            },
          ),
          _ActionPill(
            icon: MingCute.add_circle_line,
            label: l10n.menuAddToPlaylist,
            isDesktop: isDesktop,
            onTap: () {
              final player = context.read<MusicDeewanePlayerCubit>().player;
              final currentMedia = player.mediaItem.valueOrNull;
              if (currentMedia == null) return;
              context
                  .read<AddToPlaylistCubit>()
                  .setTrack(mediaItemToTrack(currentMedia));
              context.pushNamed(RoutePaths.addToPlaylistScreen);
            },
          ),
        ],
      ),
    );
  }
}

class _ActionPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool isActive;
  final bool isDesktop;
  const _ActionPill({
    required this.icon,
    required this.label,
    this.onTap,
    this.isActive = false,
    this.isDesktop = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(right: isDesktop ? 12 : 8),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: EdgeInsets.symmetric(
              horizontal: isDesktop ? 16 : 14, vertical: isDesktop ? 10 : 8),
          decoration: BoxDecoration(
            color: isActive
                ? Default_Theme.accentColor2.withValues(alpha: 0.2)
                : Default_Theme.primaryColor1.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isActive
                  ? Default_Theme.accentColor2.withValues(alpha: 0.4)
                  : Default_Theme.primaryColor1.withValues(alpha: 0.06),
              width: 0.5,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: isDesktop ? 20 : 18,
                color: isActive
                    ? Default_Theme.accentColor2
                    : Default_Theme.primaryColor1.withValues(alpha: 0.7),
              ),
              SizedBox(width: isDesktop ? 8 : 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: isDesktop ? 14 : 13,
                  fontWeight: FontWeight.w600,
                  color: isActive
                      ? Default_Theme.accentColor2
                      : Default_Theme.primaryColor1.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}



/// Inline lyrics view that replaces the album artwork when lyrics are toggled on.
/// Auto-scrolls to keep the current lyric line centered — no manual scrolling needed.
class _InlineLyricsView extends StatefulWidget {
  const _InlineLyricsView();

  @override
  State<_InlineLyricsView> createState() => _InlineLyricsViewState();
}

class _InlineLyricsViewState extends State<_InlineLyricsView> {
  final ItemScrollController _itemScrollController = ItemScrollController();
  int _currentIndex = -1;
  bool _userScrolling = false;
  Timer? _userScrollTimer;

  void _scrollToCurrentLyric() {
    if (_userScrolling) return;
    if (_itemScrollController.isAttached && _currentIndex >= 0) {
      _itemScrollController.scrollTo(
        index: _currentIndex,
        alignment: 0.4,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutQuart,
      );
    }
  }

  void _onUserScroll() {
    _userScrolling = true;
    _userScrollTimer?.cancel();
    _userScrollTimer = Timer(const Duration(seconds: 3), () {
      _userScrolling = false;
      _scrollToCurrentLyric();
    });
  }

  @override
  void dispose() {
    _userScrollTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final playerCubit = context.read<MusicDeewanePlayerCubit>();

    return BlocBuilder<LyricsCubit, LyricsState>(
      builder: (context, state) {
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          child: switch (state) {
            LyricsInitial() || LyricsLoading() => const Center(
                child: CircularProgressIndicator(
                    color: Default_Theme.accentColor2)),
            LyricsLoaded() => state.lyrics.parsedLyrics != null
                ? _buildSyncedLyrics(context, state, playerCubit)
                : state.lyrics.lyricsPlain.isNotEmpty
                    ? _buildPlainLyrics(state.lyrics.lyricsPlain)
                    : _buildNoLyrics(l10n),
            LyricsError() => _buildNoLyrics(l10n),
            LyricsState() => const SizedBox.shrink(),
          },
        );
      },
    );
  }

  Widget _buildNoLyrics(AppLocalizations l10n) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(MingCute.music_2_line,
              color: Default_Theme.primaryColor1.withValues(alpha: 0.4),
              size: 48),
          const SizedBox(height: 12),
          Text(
            l10n.playerNoLyricsFound,
            style: TextStyle(
              color: Default_Theme.primaryColor1.withValues(alpha: 0.5),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap to search for lyrics',
            style: TextStyle(
              color: Default_Theme.primaryColor1.withValues(alpha: 0.3),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlainLyrics(String lyrics) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: ShaderMask(
        shaderCallback: (Rect bounds) {
          return const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.transparent,
              Colors.white,
              Colors.white,
              Colors.transparent,
            ],
            stops: [0.0, 0.15, 0.85, 1.0],
          ).createShader(bounds);
        },
        blendMode: BlendMode.dstIn,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Center(
            child: Text(
              lyrics,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontFamily: 'NotoSans',
                fontWeight: FontWeight.w600,
                color: Default_Theme.primaryColor1.withValues(alpha: 0.9),
                height: 1.6,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSyncedLyrics(BuildContext context, LyricsState state, MusicDeewanePlayerCubit playerCubit) {
    final lyrics = state.lyrics.parsedLyrics?.lyrics ?? [];
    if (lyrics.isEmpty) return _buildNoLyrics(AppLocalizations.of(context)!);

    return StreamBuilder<Duration>(
        stream: playerCubit.player.engine.positionStream,
        builder: (context, snapshot) {
          final currentPosition = snapshot.data ?? Duration.zero;

          int newIndex = 0;
          for (int i = 0; i < lyrics.length; i++) {
            if (currentPosition >= lyrics[i].start) {
              newIndex = i;
            }
          }

          if (newIndex != _currentIndex) {
            _currentIndex = newIndex;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _scrollToCurrentLyric();
            });
          }

          return NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              if (notification is ScrollStartNotification &&
                  notification.dragDetails != null) {
                _onUserScroll();
              }
              return false;
            },
            child: ShaderMask(
              shaderCallback: (Rect bounds) {
                return const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.white,
                    Colors.white,
                    Colors.transparent,
                  ],
                  stops: [0.0, 0.15, 0.85, 1.0],
                ).createShader(bounds);
              },
              blendMode: BlendMode.dstIn,
              child: ScrollablePositionedList.builder(
                itemScrollController: _itemScrollController,
                itemCount: lyrics.length,
                padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 24),
                physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics()),
                itemBuilder: (context, index) {
                  final lyric = lyrics[index];
                  final isCurrentLine = index == _currentIndex;
                  final isPastLine = index < _currentIndex;

                  return GestureDetector(
                    onTap: () {
                      _userScrolling = false;
                      playerCubit.player.seek(lyric.start);
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 300),
                        style: TextStyle(
                          fontSize: isCurrentLine ? 20 : 16,
                          fontFamily: 'NotoSans',
                          fontWeight: isCurrentLine ? FontWeight.w800 : FontWeight.w500,
                          color: Default_Theme.primaryColor1
                              .withValues(alpha: isCurrentLine ? 1.0 : (isPastLine ? 0.3 : 0.5)),
                        ),
                        textAlign: TextAlign.center,
                        child: Text(lyric.text),
                      ),
                    ),
                  );
                },
              ),
            ),
          );
        },
      );
  }
}

/// FIX M-05: Replaced FutureBuilder (re-queries DB on every stream event) with
/// a StatefulWidget that caches the download state and only re-queries when the
/// media item ID actually changes.
class _DownloadButton extends StatefulWidget {
  const _DownloadButton();

  @override
  State<_DownloadButton> createState() => _DownloadButtonState();
}

class _DownloadButtonState extends State<_DownloadButton> {
  String? _lastTrackId;
  bool _isDownloaded = false;
  StreamSubscription? _mediaSub;

  @override
  void initState() {
    super.initState();
    final player = context.read<MusicDeewanePlayerCubit>().player;
    _mediaSub = player.mediaItem.listen((mi) {
      if (mi?.id != _lastTrackId) {
        _lastTrackId = mi?.id;
        _queryDownloadState(mi);
      }
    });
    // Query immediately for the current track.
    _queryDownloadState(player.mediaItem.valueOrNull);
  }

  Future<void> _queryDownloadState(MediaItem? mi) async {
    if (mi == null) {
      if (mounted) setState(() => _isDownloaded = false);
      return;
    }
    try {
      final info = await context
          .read<DownloaderCubit>()
          .getDownloadInfo(mediaItemToTrack(mi));
      if (mounted) setState(() => _isDownloaded = info != null);
    } catch (_) {
      if (mounted) setState(() => _isDownloaded = false);
    }
  }

  @override
  void dispose() {
    _mediaSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isDownloaded) return const SizedBox.shrink();
    return Tooltip(
      message: AppLocalizations.of(context)!.tooltipAvailableOffline,
      child: Hoverable(
        child: IconButton(
          iconSize: 25,
          icon: Icon(
            Icons.offline_pin_rounded,
            color: Default_Theme.primaryColor1.withValues(alpha: 0.5),
          ),
          onPressed: () {},
        ),
      ),
    );
  }
}

/// FIX M-05: Replaced nested FutureBuilder+StreamBuilder+BlocBuilder with a
/// StatefulWidget that caches liked state and only re-queries when track ID changes.
class _LikeButton extends StatefulWidget {
  const _LikeButton();

  @override
  State<_LikeButton> createState() => _LikeButtonState();
}

class _LikeButtonState extends State<_LikeButton> {
  String? _lastTrackId;
  bool _isLiked = false;
  StreamSubscription? _mediaSub;

  @override
  void initState() {
    super.initState();
    final player = context.read<MusicDeewanePlayerCubit>().player;
    _mediaSub = player.mediaItem.listen((mi) {
      if (mi?.id != _lastTrackId) {
        _lastTrackId = mi?.id;
        _queryLikedState(mi);
      }
    });
    _queryLikedState(player.mediaItem.valueOrNull);
  }

  Future<void> _queryLikedState(MediaItem? mi) async {
    if (mi == null) {
      if (mounted) setState(() => _isLiked = false);
      return;
    }
    try {
      final liked = await context
          .read<LibraryItemsCubit>()
          .isTrackLiked(mediaItemToTrack(mi));
      if (mounted) setState(() => _isLiked = liked);
    } catch (_) {
      if (mounted) setState(() => _isLiked = false);
    }
  }

  @override
  void dispose() {
    _mediaSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final player = context.read<MusicDeewanePlayerCubit>().player;
    final l10n = AppLocalizations.of(context)!;

    return StreamBuilder<bool>(
      stream: player.engine.playingStream,
      builder: (context, playingSnapshot) {
        final isPlaying = playingSnapshot.data ?? false;
        final currentMedia = player.mediaItem.valueOrNull;
        if (currentMedia == null) return const SizedBox.shrink();

        return LikeBtnWidget(
          isPlaying: isPlaying,
          isLiked: _isLiked,
          iconSize: 25,
          onLiked: () {
            context
                .read<LibraryItemsCubit>()
                .setTrackLiked(mediaItemToTrack(currentMedia), true);
            setState(() => _isLiked = true);
            SnackbarService.showMessage(l10n.playerLiked(currentMedia.title));
          },
          onDisliked: () {
            context
                .read<LibraryItemsCubit>()
                .setTrackLiked(mediaItemToTrack(currentMedia), false);
            setState(() => _isLiked = false);
            SnackbarService.showMessage(l10n.playerUnliked(currentMedia.title));
          },
        );
      },
    );
  }
}

class _PlayerProgressBar extends StatelessWidget {
  const _PlayerProgressBar();

  @override
  Widget build(BuildContext context) {
    final playerCubit = context.read<MusicDeewanePlayerCubit>();
    return RepaintBoundary(
      child: StreamBuilder<ProgressBarStreams>(
        stream: playerCubit.progressStreams,
        builder: (context, snapshot) {
          final data = snapshot.data;
          return WaveProgressBar(
            progress: data?.position ?? Duration.zero,
            total: data?.duration ?? Duration.zero,
            buffered: data?.buffered ?? Duration.zero,
            onSeek: playerCubit.player.seek,
            isPlaying: data?.isPlaying ?? false,
            trackHeight: 6.0,
            thumbRadius: 8.0,
            timeLabelStyle: Default_Theme.secondoryTextStyle.merge(TextStyle(
              fontSize: 15,
              color: Default_Theme.primaryColor1.withValues(alpha: 0.7),
            )),
          );
        },
      ),
    );
  }
}

class _LoopControl extends StatelessWidget {
  const _LoopControl();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<LoopMode>(
      stream: context.read<MusicDeewanePlayerCubit>().player.loopMode,
      builder: (context, snapshot) {
        final loopMode = snapshot.data ?? LoopMode.off;
        final l10n = AppLocalizations.of(context)!;
        return PopupMenuButton<int>(
          itemBuilder: (_) => [
            PopupMenuItem(value: 0, child: Text(l10n.playerLoopOff)),
            PopupMenuItem(value: 1, child: Text(l10n.playerLoopOne)),
            PopupMenuItem(value: 2, child: Text(l10n.playerLoopAll)),
          ],
          onSelected: (value) {
            final player = context.read<MusicDeewanePlayerCubit>().player;
            if (value == 0) player.setLoopMode(LoopMode.off);
            if (value == 1) player.setLoopMode(LoopMode.one);
            if (value == 2) player.setLoopMode(LoopMode.all);
          },
          child: OrganicIconButton(
            icon: loopMode == LoopMode.off
                ? MingCute.repeat_line
                : loopMode == LoopMode.one
                    ? MingCute.repeat_one_line
                    : MingCute.repeat_fill,
            iconSize: 20,
            size: 44,
            isActive: loopMode != LoopMode.off,
          ),
        );
      },
    );
  }
}

class _ShuffleControl extends StatelessWidget {
  const _ShuffleControl();

  @override
  Widget build(BuildContext context) {
    final player = context.read<MusicDeewanePlayerCubit>().player;
    return StreamBuilder<bool>(
      stream: player.shuffleMode,
      builder: (context, snapshot) {
        final isShuffle = snapshot.data ?? false;
        return OrganicIconButton(
          icon: MingCute.shuffle_2_fill,
          iconSize: 24,
          size: 52,
          isActive: isShuffle,
          onPressed: () => player.shuffle(!isShuffle),
        );
      },
    );
  }
}

class _PlayPauseButton extends StatelessWidget {
  const _PlayPauseButton();

  @override
  Widget build(BuildContext context) {
    final musicPlayer = context.read<MusicDeewanePlayerCubit>().player;
    return BlocBuilder<MiniPlayerCubit, MiniPlayerState>(
      builder: (context, state) {
        if (state.isVisible) {
          return PlayPauseButton(
            size: 70,
            onPause: musicPlayer.pause,
            onPlay: musicPlayer.play,
            isPlaying: state.isPlaying,
          );
        }

        Widget child;
        if (state.isLoading || state.isResolving) {
          child = const SizedBox(
            width: 26,
            height: 26,
            child: CircularProgressIndicator(
                strokeWidth: 3, color: Default_Theme.accentColor2dark),
          );
        } else if (state.isCompleted) {
          child = const Icon(FontAwesome.rotate_right_solid,
              color: Default_Theme.accentColor2dark, size: 30);
        } else if (state.hasError) {
          child = const Icon(MingCute.warning_line,
              color: Default_Theme.accentColor2dark, size: 30);
        } else {
          child = const SizedBox();
        }

        return MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: () {
              if (state.isCompleted) {
                musicPlayer.seek(Duration.zero);
                musicPlayer.play();
              } else if (state.hasError) {
                musicPlayer.play();
              }
            },
            child: Container(
              width: 70,
              height: 70,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Default_Theme.accentColor2,
              ),
              child: Center(
                child: SizedBox(width: 32, height: 32, child: child),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Volume control — visible on tablet + desktop only.
/// Horizontal slider with mute icon, subscribes to engine volume stream.
class _PlayerVolumeControl extends StatefulWidget {
  final MusicDeewanePlayer musicPlayer;
  const _PlayerVolumeControl({required this.musicPlayer});

  @override
  State<_PlayerVolumeControl> createState() => _PlayerVolumeControlState();
}

class _PlayerVolumeControlState extends State<_PlayerVolumeControl> {
  late double _volume;
  StreamSubscription<double>? _volumeSub;
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    _volume = widget.musicPlayer.engine.volume;
    _volumeSub = widget.musicPlayer.engine.volumeStream.listen((v) {
      if (!_isDragging && mounted) setState(() => _volume = v);
    });
  }

  @override
  void dispose() {
    _volumeSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isMuted = _volume == 0;
    return Tooltip(
      message: l10n.playerVolumeHint,
      child: Row(
        children: [
          GestureDetector(
            onTap: () {
              final newVol = isMuted ? 0.5 : 0.0;
              widget.musicPlayer.engine.setVolume(newVol);
              setState(() => _volume = newVol);
            },
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: Icon(
                isMuted ? MingCute.volume_off_fill : MingCute.volume_fill,
                size: 18,
                color: Default_Theme.primaryColor1
                    .withValues(alpha: _volume == 0 ? 0.45 : 0.72),
              ),
            ),
          ),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: Default_Theme.primaryColor1,
                inactiveTrackColor:
                    Default_Theme.primaryColor1.withValues(alpha: 0.12),
                thumbColor: Default_Theme.primaryColor1,
                overlayColor: Colors.white.withValues(alpha: 0.08),
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                trackHeight: 4,
                trackShape: const RoundedRectSliderTrackShape(),
              ),
              child: Slider(
                value: _volume,
                min: 0,
                max: 1,
                onChanged: (v) {
                  // Set dragging flag FIRST to prevent stream listener from
                  // overriding the value during drag.
                  if (!_isDragging) setState(() => _isDragging = true);
                  final clamped = v.clamp(0.0, 1.0);
                  widget.musicPlayer.engine.setVolume(clamped);
                  setState(() => _volume = clamped);
                },
                onChangeEnd: (_) {
                  setState(() => _isDragging = false);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// FIX M-06: (removed) Ambient artwork glow retired with the Void Monochrome
/// palette — playback is now clean and glow-free.
