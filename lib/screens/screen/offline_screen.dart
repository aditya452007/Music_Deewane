import 'dart:developer';

import 'package:music_deewane/blocs/media_player/music_deewane_player_cubit.dart';
import 'package:music_deewane/blocs/downloader/cubit/downloader_cubit.dart';
import 'package:music_deewane/core/models/media_playlist_model.dart';
import 'package:music_deewane/core/models/exported.dart';
import 'package:music_deewane/screens/widgets/downloading_item.dart';
import 'package:music_deewane/screens/widgets/hover_wrapper.dart';
import 'package:music_deewane/screens/widgets/more_bottom_sheet.dart';
import 'package:music_deewane/screens/widgets/snackbar.dart';
import 'package:music_deewane/screens/widgets/song_tile.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:music_deewane/core/theme/app_theme.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:music_deewane/l10n/app_localizations.dart';
import 'package:music_deewane/core/constants/route_paths.dart';
import 'package:iconsx_plus/iconsx_plus.dart';

class OfflineScreen extends StatefulWidget {
  const OfflineScreen({super.key});

  @override
  State<OfflineScreen> createState() => _OfflineScreenState();
}

class _OfflineScreenState extends State<OfflineScreen> {
  bool _isSearch = false;
  final TextEditingController _searchController = TextEditingController();
  List<Track> _filteredSongs = [];

  @override
  void initState() {
    super.initState();
    final downloaderState = context.read<DownloaderCubit>().state;
    _filteredSongs = downloaderState.downloaded;
    _searchController.addListener(_filterSongs);
  }

  @override
  void dispose() {
    _searchController.removeListener(_filterSongs);
    _searchController.dispose();
    super.dispose();
  }

  void _filterSongs() {
    final downloaderState = context.read<DownloaderCubit>().state;
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredSongs = downloaderState.downloaded
          .where((song) =>
              "${song.title.toLowerCase()} ${song.artists.map((a) => a.name).join(', ').toLowerCase()}"
                  .contains(query))
          .toList();
    });
  }

  void _toggleSearch() {
    setState(() {
      _isSearch = !_isSearch;
      // When closing the search, clear the controller and reset the filter
      if (!_isSearch) {
        _searchController.clear();
        final downloaderState = context.read<DownloaderCubit>().state;
        _filteredSongs = downloaderState.downloaded;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SafeArea(
      child: Scaffold(
        backgroundColor: Default_Theme.themeColor,
        body: BlocBuilder<DownloaderCubit, DownloaderState>(
          builder: (context, state) {
            if (_searchController.text.isEmpty) {
              _filteredSongs = state.downloaded;
            }
            return CustomScrollView(
              slivers: [
                customDiscoverSliverBar(context, l10n),
                if (state.downloads.isEmpty && state.downloaded.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(height: 60),
                          Icon(FontAwesome.download_solid,
                              size: 56,
                              color: Default_Theme.primaryColor2
                                  .withValues(alpha: 0.5)),
                          const SizedBox(height: 20),
                          Text(l10n.offlineEmptyTitle,
                              style: Default_Theme.primaryTextStyle.merge(
                                  const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w700))),
                          const SizedBox(height: 8),
                          Text(l10n.offlineEmptyHint,
                              textAlign: TextAlign.center,
                              style: Default_Theme.secondoryTextStyle.merge(
                                  TextStyle(
                                      color: Default_Theme.primaryColor2
                                          .withValues(alpha: 0.6),
                                      fontSize: 13))),
                          const SizedBox(height: 24),
                          FilledButton.icon(
                            onPressed: () =>
                                context.goNamed(RoutePaths.searchScreen),
                            icon: const Icon(MingCute.search_line, size: 18),
                            label: Text(l10n.offlineEmptyBrowse),
                            style: FilledButton.styleFrom(
                              backgroundColor: Default_Theme.accentColor2,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 24, vertical: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  SliverList(
                    delegate: SliverChildListDelegate(
                      [
                        ...state.downloads.map((download) =>
                            DownloadingCardWidget(downloadProgress: download)),
                        ..._filteredSongs.map((song) => SongCardWidget(
                              song: song,
                              showOptions: true,
                              delDownBtn: true,
                              onTap: () {
                                final selectedIndex =
                                    state.downloaded.indexWhere(
                                  (item) => item.id == song.id,
                                );

                                if (selectedIndex < 0 ||
                                    state.downloaded.isEmpty) {
                                  SnackbarService.showMessage(
                                      l10n.offlineOpenFailed);
                                  log(
                                    'Offline play failed: missing track in downloaded list (${song.id})',
                                    name: 'OfflineScreen',
                                  );
                                  return;
                                }

                                try {
                                  context
                                      .read<MusicDeewanePlayerCubit>()
                                      .player
                                      .loadPlaylist(
                                        Playlist(
                                          tracks: state.downloaded,
                                          title: "Offline",
                                        ),
                                        idx: selectedIndex,
                                        doPlay: true,
                                      );
                                } catch (e, stack) {
                                  log(
                                    'Offline play crashed for ${song.id}',
                                    name: 'OfflineScreen',
                                    error: e,
                                    stackTrace: stack,
                                  );
                                  SnackbarService.showMessage(
                                      l10n.offlinePlayFailed);
                                }
                              },
                              onOptionsTap: () {
                                showMoreBottomSheet(context, song,
                                    showDelete: false);
                              },
                            )),
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  SliverAppBar customDiscoverSliverBar(
      BuildContext context, AppLocalizations l10n) {
    return SliverAppBar(
      floating: true,
      pinned: true,
      surfaceTintColor: Default_Theme.themeColor,
      backgroundColor: Default_Theme.themeColor,
      title: AnimatedSwitcher(
        duration: const Duration(milliseconds: 350),
        transitionBuilder: (Widget child, Animation<double> animation) {
          final slideAnimation = Tween<Offset>(
            begin: const Offset(1.0, 0.0),
            end: Offset.zero,
          ).animate(CurvedAnimation(
            parent: animation,
            curve: Curves.easeInOut,
          ));
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: slideAnimation,
              child: child,
            ),
          );
        },
        child: _isSearch ? _buildSearchField(l10n) : _buildTitle(l10n),
      ),
      actions: [
        !_isSearch
            ? Tooltip(
                message: l10n.offlineRefreshTooltip,
                child: Hoverable(
                  child: IconButton(
                    icon: const Icon(MingCute.refresh_2_line),
                    onPressed: () {
                      context.read<DownloaderCubit>().refreshDownloadedSongs();
                    },
                  ),
                ),
              )
            : const SizedBox.shrink(),
        Tooltip(
          message:
              _isSearch ? l10n.offlineCloseSearch : l10n.offlineSearchTooltip,
          child: Hoverable(
            child: IconButton(
              icon: Icon(
                _isSearch ? Icons.close : Icons.search,
                color: Default_Theme.primaryColor1,
              ),
              onPressed: _toggleSearch,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTitle(AppLocalizations l10n) {
    return Container(
      key: const ValueKey('title'),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(l10n.offlineTitle,
              style: Default_Theme.primaryTextStyle.merge(const TextStyle(
                  fontSize: 34, color: Default_Theme.primaryColor1))),
          const Spacer(),
        ],
      ),
    );
  }

  Widget _buildSearchField(AppLocalizations l10n) {
    return Container(
      key: const ValueKey('search'),
      child: TextField(
        controller: _searchController,
        autofocus: true,
        cursorColor: Default_Theme.primaryColor1,
        decoration: InputDecoration(
          hintText: l10n.offlineSearchHint,
          border: InputBorder.none,
          hintStyle: TextStyle(
              color: Default_Theme.primaryColor1.withValues(alpha: 0.7)),
        ),
        style: Default_Theme.secondoryTextStyle.merge(
          const TextStyle(
            color: Default_Theme.primaryColor1,
            fontSize: 15.0,
          ),
        ),
      ),
    );
  }
}
