import 'package:music_deewane/blocs/library/cubit/library_items_cubit.dart';
import 'package:music_deewane/blocs/player_overlay/player_overlay_cubit.dart';
import 'package:music_deewane/core/constants/route_paths.dart';
import 'package:music_deewane/screens/widgets/offline_banner.dart';
import 'package:music_deewane/screens/widgets/player_overlay_wrapper.dart';
import 'package:music_deewane/screens/widgets/mini_player_widget.dart';
import 'package:music_deewane/core/theme/app_theme.dart';
import 'package:music_deewane/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_nav_bar/google_nav_bar.dart';
import 'package:iconsx_plus/iconsx_plus.dart';
import 'package:responsive_framework/responsive_framework.dart';

class GlobalFooter extends StatefulWidget {
  const GlobalFooter({super.key, required this.navigationShell});
  final StatefulNavigationShell navigationShell;

  @override
  State<GlobalFooter> createState() => _GlobalFooterState();
}

class _GlobalFooterState extends State<GlobalFooter> {
  bool _sidebarExpanded = false;

  int get _sidebarWidth => _sidebarExpanded ? 280 : 72;

  @override
  Widget build(BuildContext context) {
    context.watch<PlayerOverlayCubit>();
    final isMobile = ResponsiveBreakpoints.of(context).isMobile;

    return SidebarWidthNotifier(
      width: isMobile ? 0 : _sidebarWidth,
      child: PlayerOverlayWrapper(
        child: BackButtonListener(
          onBackButtonPressed: () async {
            final overlayC = context.read<PlayerOverlayCubit>();
            final router = GoRouter.of(context);

            if (router.canPop()) {
              router.pop();
              return true;
            }

            if (overlayC.state && overlayC.collapseUpNextPanel()) {
              return true;
            }

            if (overlayC.state) {
              overlayC.hidePlayer();
              return true;
            }

            return false;
          },
          child: PopScope(
            canPop: false,
            onPopInvokedWithResult: (didPop, _) async {
              if (didPop) return;
              await _handleHardwareBackPress(context);
            },
            child: Scaffold(
              backgroundColor: Default_Theme.themeColor,
              drawerScrimColor: Default_Theme.themeColor,
              body: Stack(
                children: [
                  isMobile
                      ? Column(
                          children: [
                            Expanded(
                              child: _AnimatedPageView(
                                  navigationShell: widget.navigationShell),
                            ),
                            const MiniPlayerWidget(),
                          ],
                        )
                      : Row(
                          children: [
                            _SpotifySidebar(
                              navigationShell: widget.navigationShell,
                              onExpansionChanged: (expanded) {
                                setState(() => _sidebarExpanded = expanded);
                              },
                            ),
                            Expanded(
                              child: Column(
                                children: [
                                  Expanded(
                                    child: _AnimatedPageView(
                                        navigationShell:
                                            widget.navigationShell),
                                  ),
                                  const MiniPlayerWidget(),
                                ],
                              ),
                            ),
                          ],
                        ),
                  const Positioned(
                      top: 0, left: 0, right: 0, child: OfflineBanner()),
                ],
              ),
              bottomNavigationBar: isMobile
                  ? SafeArea(
                      child: Container(
                        color: Colors.transparent,
                        margin: const EdgeInsets.symmetric(
                            vertical: 5, horizontal: 10),
                        child: HorizontalNavBar(
                            navigationShell: widget.navigationShell),
                      ),
                    )
                  : null,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleHardwareBackPress(BuildContext context) async {
    final overlayC = context.read<PlayerOverlayCubit>();
    final router = GoRouter.of(context);

    if (router.canPop()) {
      router.pop();
      return;
    }

    if (overlayC.state && overlayC.collapseUpNextPanel()) return;

    if (overlayC.state) {
      overlayC.hidePlayer();
      return;
    }

    if (widget.navigationShell.currentIndex != 0) {
      widget.navigationShell.goBranch(0);
      return;
    }

    if (context.mounted) {
      await SystemNavigator.pop();
    }
  }
}

class _AnimatedPageView extends StatefulWidget {
  const _AnimatedPageView({required this.navigationShell});
  final StatefulNavigationShell navigationShell;

  @override
  State<_AnimatedPageView> createState() => _AnimatedPageViewState();
}

class _AnimatedPageViewState extends State<_AnimatedPageView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animationController;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _scaleAnimation;
  int _previousIndex = 0;

  @override
  void initState() {
    super.initState();
    _previousIndex = widget.navigationShell.currentIndex;

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 250),
      vsync: this,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    );

    _scaleAnimation = Tween<double>(begin: 0.96, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOutCubic,
      ),
    );

    _animationController.forward();
  }

  @override
  void didUpdateWidget(_AnimatedPageView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.navigationShell.currentIndex != _previousIndex) {
      _previousIndex = widget.navigationShell.currentIndex;
      _animationController.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: widget.navigationShell,
      ),
    );
  }
}

/// Spotify-style collapsible sidebar for desktop/tablet.
/// Collapsed: 72px, icons only. Expanded: 280px, icons + labels + playlists.
class _SpotifySidebar extends StatefulWidget {
  final StatefulNavigationShell navigationShell;
  final ValueChanged<bool>? onExpansionChanged;
  const _SpotifySidebar(
      {required this.navigationShell, this.onExpansionChanged});
  @override
  State<_SpotifySidebar> createState() => _SpotifySidebarState();
}

class _SpotifySidebarState extends State<_SpotifySidebar> {
  bool _expanded = false;
  final ScrollController _scrollController = ScrollController();

  static const _navItems = [
    _NavItemData(icon: MingCute.home_4_fill, labelKey: 'navHome', index: 0),
    _NavItemData(icon: MingCute.search_2_fill, labelKey: 'navSearch', index: 2),
    _NavItemData(icon: MingCute.music_2_fill, labelKey: 'navLocal', index: 3),
    _NavItemData(
        icon: MingCute.folder_download_fill, labelKey: 'navOffline', index: 4),
  ];

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  String _getLabel(BuildContext context, String key) {
    final l10n = AppLocalizations.of(context);
    if (l10n == null) return key;
    switch (key) {
      case 'navHome':
        return l10n.navHome;
      case 'navSearch':
        return l10n.navSearch;
      case 'navLocal':
        return l10n.navLocal;
      case 'navOffline':
        return l10n.navOffline;
      default:
        return key;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      width: _expanded ? 280 : 72,
      decoration: BoxDecoration(
        color: Default_Theme.themeColor,
        border: Border(
          right: BorderSide(
            color: Default_Theme.primaryColor1.withValues(alpha: 0.08),
          ),
        ),
      ),
      child: Column(
        children: [
          // ── Toggle + Logo ──
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
            child: Row(
              children: [
                IconButton(
                  padding: const EdgeInsets.all(8),
                  constraints: const BoxConstraints(),
                  onPressed: () {
                    setState(() => _expanded = !_expanded);
                    widget.onExpansionChanged?.call(_expanded);
                  },
                  icon: Icon(
                    _expanded ? MingCute.menu_line : MingCute.menu_line,
                    color: Default_Theme.primaryColor1,
                    size: 22,
                  ),
                ),
                if (_expanded) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Music Deewane',
                      style: Default_Theme.secondoryTextStyleMedium.merge(
                        const TextStyle(
                          color: Default_Theme.primaryColor1,
                          fontSize: 16,
                        ),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 8),
          // ── Nav items ──
          ..._navItems.map((item) => _buildNavItem(item)),
          // ── Divider ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Container(
              height: 1,
              color: Default_Theme.primaryColor1.withValues(alpha: 0.08),
            ),
          ),
          // ── Library header (expanded only) ──
          if (_expanded)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => widget.navigationShell.goBranch(1),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Icon(
                        MingCute.book_5_fill,
                        color:
                            Default_Theme.primaryColor1.withValues(alpha: 0.6),
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Your Library',
                          style: TextStyle(
                            color: Default_Theme.primaryColor1
                                .withValues(alpha: 0.6),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          if (_expanded) const SizedBox(height: 8),
          // ── Playlist list ──
          Expanded(
            child: _expanded ? _buildPlaylistList() : _buildCollapsedIcons(),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(_NavItemData item) {
    final isSelected = widget.navigationShell.currentIndex == item.index;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => widget.navigationShell.goBranch(item.index),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: EdgeInsets.symmetric(
              horizontal: _expanded ? 14 : 0,
              vertical: 10,
            ),
            decoration: BoxDecoration(
              color:
                  isSelected ? Default_Theme.surfaceColor : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: _expanded
                  ? MainAxisAlignment.start
                  : MainAxisAlignment.center,
              children: [
                Icon(
                  item.icon,
                  color: isSelected
                      ? Default_Theme.primaryColor1
                      : Default_Theme.primaryColor2,
                  size: 22,
                ),
                if (_expanded) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _getLabel(context, item.labelKey),
                      style: TextStyle(
                        color: isSelected
                            ? Default_Theme.primaryColor1
                            : Default_Theme.primaryColor2,
                        fontSize: 14,
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Collapsed: show library icon that navigates to Library tab.
  Widget _buildCollapsedIcons() {
    final isLibrarySelected = widget.navigationShell.currentIndex == 1;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => widget.navigationShell.goBranch(1),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: isLibrarySelected
                  ? Default_Theme.surfaceColor
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Icon(
                MingCute.book_5_fill,
                color: isLibrarySelected
                    ? Default_Theme.primaryColor1
                    : Default_Theme.primaryColor2,
                size: 22,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Expanded: show playlist list from LibraryItemsCubit.
  Widget _buildPlaylistList() {
    return BlocBuilder<LibraryItemsCubit, LibraryItemsState>(
      builder: (context, state) {
        if (state is! LibraryItemsLoaded) {
          return const SizedBox.shrink();
        }

        final playlists = state.playlists;
        if (playlists.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              'No playlists yet',
              style: TextStyle(
                color: Default_Theme.primaryColor1.withValues(alpha: 0.3),
                fontSize: 12,
              ),
            ),
          );
        }

        final pinned = playlists.where((p) => p.isPinned).toList();
        final unpinned = playlists.where((p) => !p.isPinned).toList();
        final sorted = [...pinned, ...unpinned];

        return ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          itemCount: sorted.length,
          itemBuilder: (context, index) {
            final item = sorted[index];
            return _PlaylistTile(
              name: item.playlistName,
              coverUrl: item.coverImgUrl,
              onTap: () {
                context.pushNamed(
                  RoutePaths.playlistView,
                  extra: item.storageKey,
                );
              },
            );
          },
        );
      },
    );
  }
}

class _PlaylistTile extends StatefulWidget {
  final String name;
  final String? coverUrl;
  final VoidCallback onTap;

  const _PlaylistTile({
    required this.name,
    this.coverUrl,
    required this.onTap,
  });

  @override
  State<_PlaylistTile> createState() => _PlaylistTileState();
}

class _PlaylistTileState extends State<_PlaylistTile> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovering = true),
        onExit: (_) => setState(() => _hovering = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: _hovering
                  ? Default_Theme.surfaceColor.withValues(alpha: 0.5)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: SizedBox(
                    width: 32,
                    height: 32,
                    child:
                        widget.coverUrl != null && widget.coverUrl!.isNotEmpty
                            ? Image.network(
                                widget.coverUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  color: Default_Theme.surfaceColor,
                                  child: const Icon(
                                    Icons.music_note,
                                    size: 16,
                                    color: Default_Theme.primaryColor2,
                                  ),
                                ),
                              )
                            : Container(
                                color: Default_Theme.surfaceColor,
                                child: const Icon(
                                  Icons.music_note,
                                  size: 16,
                                  color: Default_Theme.primaryColor2,
                                ),
                              ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    widget.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Default_Theme.primaryColor1.withValues(alpha: 0.8),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItemData {
  final IconData icon;
  final String labelKey;
  final int index;

  const _NavItemData({
    required this.icon,
    required this.labelKey,
    required this.index,
  });
}

class HorizontalNavBar extends StatelessWidget {
  const HorizontalNavBar({super.key, required this.navigationShell});
  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GNav(
        gap: 7.0,
        hoverColor: Default_Theme.accentColor2.withValues(alpha: 0.05),
        tabBackgroundColor: Default_Theme.accentColor2.withValues(alpha: 0.22),
        color: Default_Theme.primaryColor2,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        activeColor: Default_Theme.accentColor2,
        textStyle: Default_Theme.secondoryTextStyleMedium.merge(
            const TextStyle(color: Default_Theme.accentColor2, fontSize: 18)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        backgroundColor: Default_Theme.themeColor.withValues(alpha: 0.3),
        tabs: [
          GButton(icon: MingCute.home_4_fill, text: l10n.navHome),
          GButton(icon: MingCute.book_5_fill, text: l10n.navLibrary),
          GButton(icon: MingCute.search_2_fill, text: l10n.navSearch),
          GButton(icon: MingCute.music_2_fill, text: l10n.navLocal),
          GButton(icon: MingCute.folder_download_fill, text: l10n.navOffline),
        ],
        selectedIndex: navigationShell.currentIndex,
        onTabChange: navigationShell.goBranch,
      ),
    );
  }
}
