import 'dart:developer';
import 'package:music_deewane/blocs/internet_connectivity/cubit/connectivity_cubit.dart';
import 'package:music_deewane/blocs/lastdotfm/lastdotfm_cubit.dart';
import 'package:music_deewane/blocs/library/cubit/library_items_cubit.dart';
import 'package:music_deewane/blocs/media_player/music_deewane_player_cubit.dart';
import 'package:music_deewane/blocs/notification/notification_cubit.dart';
import 'package:music_deewane/blocs/settings_cubit/cubit/settings_cubit.dart';
import 'package:music_deewane/core/constants/route_paths.dart';
import 'package:music_deewane/core/di/service_locator.dart';
import 'package:music_deewane/core/models/exported.dart';
import 'package:music_deewane/core/models/media_playlist_model.dart';
import 'package:music_deewane/plugins/blocs/content/content_bloc.dart';
import 'package:music_deewane/plugins/blocs/content/content_event.dart';
import 'package:music_deewane/plugins/blocs/content/content_state.dart';
import 'package:music_deewane/plugins/blocs/plugin/plugin_bloc.dart';
import 'package:music_deewane/plugins/blocs/plugin/plugin_state.dart';
import 'package:music_deewane/screens/widgets/hover_wrapper.dart';
import 'package:music_deewane/screens/widgets/more_bottom_sheet.dart';
import 'package:music_deewane/screens/widgets/sign_board_widget.dart';
import 'package:music_deewane/screens/widgets/song_tile.dart';
import 'package:music_deewane/screens/widgets/top_picks_widget.dart';
import 'package:music_deewane/screens/widgets/for_you_section.dart';
import 'package:flutter/material.dart';
import 'package:music_deewane/screens/screen/home_views/notification_view.dart';
import 'package:music_deewane/screens/screen/home_views/setting_view.dart';
import 'package:music_deewane/screens/screen/home_views/timer_view.dart';
import 'package:music_deewane/core/theme/app_theme.dart';
import 'package:music_deewane/l10n/app_localizations.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsx_plus/iconsx_plus.dart';
import '../widgets/horizontal_card_view.dart';
import '../widgets/tab_list_widget.dart';
import 'package:badges/badges.dart' as badges;

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});
  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  bool isUpdateChecked = false;
  late final ContentBloc _homeContentBloc;
  Future<List<Track>> lFMData = Future.value(const []);

  @override
  void initState() {
    super.initState();
    _homeContentBloc = ContentBloc(pluginService: ServiceLocator.pluginService);
    _tryLoadHomeSections();
  }

  /// Only loads home sections when both settings are ready and plugins are loaded.
  void _tryLoadHomeSections() {
    final settingsState = context.read<SettingsCubit>().state;
    if (!settingsState.settingsReady) return;

    final pluginState = context.read<PluginBloc>().state;
    final contentResolvers = pluginState.loadedContentResolvers;
    if (contentResolvers.isEmpty) return;

    final preferredId = settingsState.homePluginId;
    // If the user's preferred plugin is installed but not yet loaded, wait for it.
    // This prevents flashing the wrong plugin's home page on startup.
    if (preferredId.isNotEmpty) {
      final isAlreadyLoaded =
          contentResolvers.any((p) => p.manifest.id == preferredId);
      if (!isAlreadyLoaded) {
        final isInstalled = pluginState.availablePlugins
            .any((p) => p.manifest.id == preferredId);
        if (isInstalled) return; // Preferred plugin is loading — wait for it
      }
    }

    final pluginId = _effectiveHomePluginId(contentResolvers);

    // Don't reload if we're already showing content from this plugin.
    if (_homeContentBloc.state.activePluginId == pluginId &&
        _homeContentBloc.state.homeSections != null) {
      return;
    }

    _homeContentBloc.add(GetHomeSections(pluginId: pluginId));
  }

  String _effectiveHomePluginId(List<dynamic> loadedResolvers) {
    final preferredId = context.read<SettingsCubit>().state.homePluginId;
    final hasPreferred = preferredId.isNotEmpty &&
        loadedResolvers.any((plugin) => plugin.manifest.id == preferredId);
    return hasPreferred ? preferredId : loadedResolvers.first.manifest.id;
  }

  @override
  void dispose() {
    _homeContentBloc.close();
    super.dispose();
  }

  Future<List<Track>> fetchLFMPicks(bool state, BuildContext ctx) async {
    if (state) {
      try {
        final data = await lFMData;
        if (data.isNotEmpty) return data;
        if (ctx.mounted) {
          final pluginState = ctx.read<PluginBloc>().state;
          final priority = ctx.read<SettingsCubit>().state.resolverPriority;
          final allIds = pluginState.loadedContentResolvers
              .map((p) => p.manifest.id)
              .toList();
          final resolverIds = [
            ...priority.where(allIds.contains),
            ...allIds.where((id) => !priority.contains(id)),
          ];
          lFMData = ctx.read<LastdotfmCubit>().getRecommendedTracks(
                resolverPluginIds: resolverIds,
              );
        }
        return (await lFMData);
      } catch (e) {
        log(e.toString(), name: "ExploreScreen");
      }
    }
    return const [];
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: MultiBlocListener(
        listeners: [
          BlocListener<SettingsCubit, SettingsState>(
            listenWhen: (previous, current) =>
                previous.homePluginId != current.homePluginId ||
                (!previous.settingsReady && current.settingsReady),
            listener: (context, state) {
              _homeContentBloc.add(const ClearHomeSections());
              _tryLoadHomeSections();
            },
          ),
          BlocListener<PluginBloc, PluginState>(
            listenWhen: (previous, current) {
              return previous.loadedContentResolvers !=
                      current.loadedContentResolvers ||
                  previous.loadedPluginIds != current.loadedPluginIds;
            },
            listener: (context, state) {
              if (state.loadedContentResolvers.isEmpty) {
                _homeContentBloc.add(const ClearHomeSections());
                return;
              }

              final activePluginId = _homeContentBloc.state.activePluginId;
              if (activePluginId != null &&
                  !state.loadedPluginIds.contains(activePluginId)) {
                // Active plugin was unloaded — reload from preferred.
                _homeContentBloc.add(const ClearHomeSections());
                _tryLoadHomeSections();
                return;
              }

              // Plugin list changed — check if preferred plugin is different.
              _tryLoadHomeSections();
            },
          ),
        ],
        child: Scaffold(
          body: RefreshIndicator(
            onRefresh: () async {
              final pluginId = _effectiveHomePluginId(
                context.read<PluginBloc>().state.loadedContentResolvers,
              );
              _homeContentBloc.add(
                GetHomeSections(pluginId: pluginId, bypassCache: true),
              );
            },
            child: CustomScrollView(
              shrinkWrap: true,
              physics: const ClampingScrollPhysics(),
              slivers: [
                const CustomDiscoverBar(),
                SliverToBoxAdapter(child: QuickAccessChips()),
                SliverList(
                  delegate: SliverChildListDelegate(
                    [
                      const TopPicksWidget(),
                      const ForYouSection(),
                      BlocBuilder<SettingsCubit, SettingsState>(
                        builder: (context, state) {
                          if (state.lFMPicks) {
                            return FutureBuilder(
                              future: fetchLFMPicks(state.lFMPicks, context),
                              builder: (context, snapshot) {
                                if (snapshot.hasData &&
                                    (snapshot.data?.isNotEmpty ?? false)) {
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 15.0),
                                    child: TabSongListWidget(
                                      list: snapshot.data!.map((e) {
                                        return SongCardWidget(
                                          song: e,
                                          onTap: () {
                                            context
                                                .read<MusicDeewanePlayerCubit>()
                                                .player
                                                .loadPlaylist(
                                                  Playlist(
                                                    tracks: snapshot.data!,
                                                    title: 'Last.Fm Picks',
                                                  ),
                                                  idx:
                                                      snapshot.data!.indexOf(e),
                                                  doPlay: true,
                                                );
                                          },
                                          onOptionsTap: () =>
                                              showMoreBottomSheet(
                                                  context,
                                                  showSinglePlay: true,
                                                  e),
                                        );
                                      }).toList(),
                                      category: AppLocalizations.of(context)!
                                          .exploreLastFmPicks,
                                      columnSize: 3,
                                    ),
                                  );
                                }
                                return const SizedBox.shrink();
                              },
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                      // Home sections from plugin
                      BlocBuilder<ContentBloc, ContentState>(
                        bloc: _homeContentBloc,
                        builder: (context, state) {
                          final loadedResolvers = context
                              .read<PluginBloc>()
                              .state
                              .loadedContentResolvers;
                          if (loadedResolvers.isEmpty) {
                            return const SignBoardWidget(
                              message:
                                  'No content plugin loaded.\nLoad a Content Resolver in Plugin Manager.',
                              icon: MingCute.plugin_2_line,
                            );
                          }

                          final sections = state.homeSections ?? const [];
                          final hasSections = sections.isNotEmpty;
                          final activePluginId = state.activePluginId;
                          if (activePluginId != null &&
                              !context
                                  .read<PluginBloc>()
                                  .state
                                  .loadedPluginIds
                                  .contains(activePluginId) &&
                              !hasSections) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 16),
                              child: SignBoardWidget(
                                message:
                                    'Refreshing Discover source...\nThe previous source is no longer available.',
                                icon: MingCute.warning_line,
                              ),
                            );
                          }

                          if (state.homeSectionsStatus ==
                              DetailStatus.loading) {
                            if (hasSections) {
                              return _HomeSectionsList(
                                sections: sections,
                                contentBloc: _homeContentBloc,
                                state: state,
                              );
                            }

                            return BlocBuilder<ConnectivityCubit,
                                ConnectivityState>(
                              builder: (context, connState) {
                                if (connState ==
                                    ConnectivityState.disconnected) {
                                  return const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 16),
                                    child: SignBoardWidget(
                                      message: 'No Internet Connection!',
                                      icon: MingCute.wifi_off_line,
                                    ),
                                  );
                                }

                                return const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 40),
                                  child: Center(
                                    child: CircularProgressIndicator(
                                      color: Default_Theme.accentColor2,
                                    ),
                                  ),
                                );
                              },
                            );
                          }

                          if (state.homeSectionsStatus == DetailStatus.error) {
                            if (hasSections) {
                              return _HomeSectionsList(
                                sections: sections,
                                contentBloc: _homeContentBloc,
                                state: state,
                              );
                            }

                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              child: SignBoardWidget(
                                message: state.error ??
                                    'Failed to load home sections.',
                                icon: MingCute.sweats_line,
                              ),
                            );
                          }

                          if (!hasSections) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: SizedBox.shrink(),
                            );
                          }

                          return _HomeSectionsList(
                            sections: sections,
                            contentBloc: _homeContentBloc,
                            state: state,
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          backgroundColor: Default_Theme.themeColor,
        ),
      ),
    );
  }
}

class _HomeSectionsList extends StatelessWidget {
  final List<Section> sections;
  final ContentBloc contentBloc;
  final ContentState state;

  const _HomeSectionsList({
    required this.sections,
    required this.contentBloc,
    required this.state,
  });

  static const _excludedSectionIds = {
    'browse_discover', // Browse Categories (empty)
    'radio', // Radio Station
    'trending', // YTVideo Trending (keep JioSaavn's 'new_trending')
  };

  @override
  Widget build(BuildContext context) {
    final filtered = sections
        .where((s) => !_excludedSectionIds.contains(s.id) && s.items.isNotEmpty)
        .toList();
    return ListView.builder(
      shrinkWrap: true,
      itemExtent: 275,
      padding: const EdgeInsets.only(top: 0),
      physics: const NeverScrollableScrollPhysics(),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final section = filtered[index];
        return HorizontalCardView(
          section: section,
          pluginId: contentBloc.state.activePluginId ?? '',
          canLoadMore: section.moreLink != null,
          isLoadingMore: state.isHomeSectionLoading(section.id),
          onLoadMore: section.moreLink == null
              ? null
              : () {
                  contentBloc.add(
                    LoadMoreHomeSectionItems(
                      pluginId: contentBloc.state.activePluginId ?? '',
                      sectionId: section.id,
                      moreLink: section.moreLink!,
                    ),
                  );
                },
        );
      },
    );
  }
}

class CustomDiscoverBar extends StatelessWidget {
  const CustomDiscoverBar({super.key});

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      floating: true,
      surfaceTintColor: Default_Theme.themeColor,
      backgroundColor: Default_Theme.themeColor,
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            AppLocalizations.of(context)!.exploreDiscover,
            style: Default_Theme.primaryTextStyle.merge(
              const TextStyle(
                fontSize: 34,
                color: Default_Theme.primaryColor1,
              ),
            ),
          ),
          const Spacer(),
          const SearchIcon(),
          const NotificationIcon(),
          const TimerIcon(),
          const SettingsIcon(),
        ],
      ),
    );
  }
}

class NotificationIcon extends StatelessWidget {
  const NotificationIcon({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<NotificationCubit, NotificationState>(
      builder: (context, state) {
        if (state is NotificationInitial || state.notifications.isEmpty) {
          return Hoverable(
            child: IconButton(
              padding: const EdgeInsets.all(5),
              constraints: const BoxConstraints(),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const NotificationView(),
                  ),
                );
              },
              icon: const Icon(
                MingCute.notification_line,
                color: Default_Theme.primaryColor1,
                size: 30.0,
              ),
            ),
          );
        }
        return badges.Badge(
          badgeContent: Padding(
            padding: const EdgeInsets.all(1.5),
            child: Text(
              state.notifications.length.toString(),
              style: Default_Theme.primaryTextStyle.merge(
                const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Default_Theme.primaryColor2,
                ),
              ),
            ),
          ),
          badgeStyle: const badges.BadgeStyle(
            badgeColor: Default_Theme.accentColor2,
            shape: badges.BadgeShape.circle,
          ),
          position: badges.BadgePosition.topEnd(top: -10, end: -5),
          child: Hoverable(
            child: IconButton(
              padding: const EdgeInsets.all(5),
              constraints: const BoxConstraints(),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const NotificationView(),
                  ),
                );
              },
              icon: const Icon(
                MingCute.notification_line,
                color: Default_Theme.primaryColor1,
                size: 30.0,
              ),
            ),
          ),
        );
      },
    );
  }
}

class TimerIcon extends StatelessWidget {
  const TimerIcon({super.key});

  @override
  Widget build(BuildContext context) {
    return Hoverable(
      child: IconButton(
        padding: const EdgeInsets.all(5),
        constraints: const BoxConstraints(),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const TimerView()),
          );
        },
        icon: const Icon(
          MingCute.stopwatch_line,
          color: Default_Theme.primaryColor1,
          size: 30.0,
        ),
      ),
    );
  }
}

class SettingsIcon extends StatelessWidget {
  const SettingsIcon({super.key});

  @override
  Widget build(BuildContext context) {
    return Hoverable(
      child: IconButton(
        padding: const EdgeInsets.all(5),
        constraints: const BoxConstraints(),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const SettingsView()),
          );
        },
        icon: const Icon(
          MingCute.settings_3_line,
          color: Default_Theme.primaryColor1,
          size: 30.0,
        ),
      ),
    );
  }
}

class SearchIcon extends StatelessWidget {
  const SearchIcon({super.key});

  @override
  Widget build(BuildContext context) {
    return Hoverable(
      child: IconButton(
        padding: const EdgeInsets.all(5),
        constraints: const BoxConstraints(),
        onPressed: () {
          context.pushNamed(RoutePaths.searchScreen);
        },
        icon: const Icon(
          MingCute.search_2_fill,
          color: Default_Theme.primaryColor1,
          size: 28.0,
        ),
      ),
    );
  }
}

/// Quick-access chip row: "Liked Songs" + user playlists.
/// Follows Spotify/YouTube Music pattern of tappable pills at top of home.
class QuickAccessChips extends StatelessWidget {
  const QuickAccessChips({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LibraryItemsCubit, LibraryItemsState>(
      builder: (context, state) {
        if (state is! LibraryItemsLoaded) return const SizedBox.shrink();

        final playlists = state.playlists;
        if (playlists.isEmpty) return const SizedBox.shrink();

        // Liked Songs first, then pinned playlists, then remaining.
        final pinned = playlists.where((p) => p.isPinned).toList();
        final unpinned = playlists.where((p) => !p.isPinned).toList();
        final sorted = [...pinned, ...unpinned];

        return SizedBox(
          height: 50,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: sorted.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final item = sorted[index];
              return _QuickAccessChip(
                label: item.playlistName,
                coverUrl: item.coverImgUrl,
                onTap: () {
                  context.pushNamed(
                    RoutePaths.playlistView,
                    extra: item.storageKey,
                  );
                },
              );
            },
          ),
        );
      },
    );
  }
}

class _QuickAccessChip extends StatefulWidget {
  final String label;
  final String? coverUrl;
  final VoidCallback onTap;

  const _QuickAccessChip({
    required this.label,
    this.coverUrl,
    required this.onTap,
  });

  @override
  State<_QuickAccessChip> createState() => _QuickAccessChipState();
}

class _QuickAccessChipState extends State<_QuickAccessChip> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: _hovering
                ? Colors.white.withValues(alpha: 0.1)
                : Default_Theme.surfaceColor,
            borderRadius: BorderRadius.circular(9999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.coverUrl != null && widget.coverUrl!.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: Image.network(
                      widget.coverUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.music_note,
                        size: 16,
                        color: Default_Theme.primaryColor2,
                      ),
                    ),
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Icon(
                    MingCute.heart_line,
                    size: 18,
                    color: Default_Theme.primaryColor2,
                  ),
                ),
              const SizedBox(width: 6),
              Text(
                widget.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Default_Theme.secondoryTextStyle.merge(
                  const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Default_Theme.primaryColor1,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
