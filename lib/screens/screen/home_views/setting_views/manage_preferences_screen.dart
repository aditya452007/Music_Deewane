import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:iconsx_plus/iconsx_plus.dart';

import 'package:music_deewane/blocs/settings_cubit/cubit/settings_cubit.dart';
import 'package:music_deewane/core/di/service_locator.dart';
import 'package:music_deewane/core/theme/app_theme.dart';
import 'package:music_deewane/l10n/app_localizations.dart';
import 'package:music_deewane/plugins/blocs/content/content_bloc.dart';
import 'package:music_deewane/plugins/blocs/content/content_event.dart';
import 'package:music_deewane/plugins/blocs/content/content_state.dart';
import 'package:music_deewane/plugins/blocs/plugin/plugin_bloc.dart';
import 'package:music_deewane/src/rust/api/plugin/commands.dart';
import 'package:music_deewane/src/rust/api/plugin/models.dart';
import 'package:music_deewane/screens/widgets/snackbar.dart';

class ManagePreferencesScreen extends StatefulWidget {
  const ManagePreferencesScreen({super.key});

  @override
  State<ManagePreferencesScreen> createState() =>
      _ManagePreferencesScreenState();
}

class _ManagePreferencesScreenState extends State<ManagePreferencesScreen> {
  late final List<Map<String, String>> _selectedArtists;
  late final Set<String> _selectedMusicLangs;
  ContentBloc? _contentBloc;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    final settings = context.read<SettingsCubit>().state;
    _selectedArtists = List<Map<String, String>>.from(
        settings.favoriteArtists.map((e) => Map<String, String>.from(e)));
    _selectedMusicLangs = settings.musicLanguages.toSet();
    _initPluginSearch();
  }

  void _initPluginSearch() {
    try {
      final pluginState = context.read<PluginBloc>().state;
      final resolvers = pluginState.loadedContentResolvers;
      if (resolvers.isNotEmpty) {
        _contentBloc = ContentBloc(pluginService: ServiceLocator.pluginService);
        _contentBloc!.add(
          SetActiveContentPlugin(pluginId: resolvers.first.manifest.id),
        );
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _contentBloc?.close();
    super.dispose();
  }

  void _toggleArtist(Map<String, String> artist) {
    setState(() {
      final exists = _selectedArtists.any((a) => a['id'] == artist['id']);
      if (exists) {
        _selectedArtists.removeWhere((a) => a['id'] == artist['id']);
      } else {
        _selectedArtists.add(artist);
      }
      _hasChanges = true;
    });
  }

  void _toggleMusicLang(String code) {
    setState(() {
      if (_selectedMusicLangs.contains(code)) {
        _selectedMusicLangs.remove(code);
      } else {
        _selectedMusicLangs.add(code);
      }
      _hasChanges = true;
    });
  }

  void _save() {
    context.read<SettingsCubit>().setFavoriteArtists(_selectedArtists);
    context
        .read<SettingsCubit>()
        .setMusicLanguages(_selectedMusicLangs.toList());
    setState(() => _hasChanges = false);
    SnackbarService.showMessage(
        AppLocalizations.of(context)?.managePreferencesSaved ??
            'Preferences saved');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: Default_Theme.themeColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Default_Theme.primaryColor1),
        title: Text(
          l10n?.managePreferencesTitle ?? 'Manage Preferences',
          style: const TextStyle(
            color: Default_Theme.primaryColor1,
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          if (_hasChanges)
            TextButton(
              onPressed: _save,
              child: Text(
                l10n?.managePreferencesSave ?? 'Save',
                style: const TextStyle(
                  color: Default_Theme.accentColor2,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          // Favorite Artists section
          _SectionHeader(
            title: l10n?.managePreferencesArtists ?? 'Favorite Artists',
            subtitle: l10n?.managePreferencesArtistsHint ??
                'Update your favorite artists to improve recommendations.',
          ),
          const SizedBox(height: 8),
          // Search bar
          _ArtistSearchBar(contentBloc: _contentBloc),
          const SizedBox(height: 12),
          // Selected artists chips
          if (_selectedArtists.isNotEmpty)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _selectedArtists.map((artist) {
                return Chip(
                  label: Text(
                    artist['name'] ?? '',
                    style: const TextStyle(
                      color: Default_Theme.primaryColor1,
                      fontSize: 13,
                    ),
                  ),
                  deleteIcon: const Icon(Icons.close,
                      size: 16, color: Default_Theme.primaryColor1),
                  onDeleted: () => _toggleArtist(artist),
                  backgroundColor:
                      Default_Theme.accentColor2.withValues(alpha: 0.2),
                  side: BorderSide(
                    color: Default_Theme.accentColor2.withValues(alpha: 0.5),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(9999),
                  ),
                );
              }).toList(),
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                l10n?.onboardingArtistsSubtitle ??
                    'Select at least 3 artists you love.',
                style: TextStyle(
                  color: Default_Theme.primaryColor1.withValues(alpha: 0.4),
                  fontSize: 13,
                ),
              ),
            ),
          const SizedBox(height: 16),

          // Search results
          if (_contentBloc != null)
            BlocBuilder<ContentBloc, ContentState>(
              bloc: _contentBloc,
              builder: (context, state) {
                if (state.searchStatus == SearchStatus.loading) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Default_Theme.accentColor2,
                        ),
                      ),
                    ),
                  );
                }
                if (state.searchResults == null ||
                    state.searchResults!.items.isEmpty) {
                  return const SizedBox.shrink();
                }
                final artists = <ArtistSummary>[];
                for (final item in state.searchResults!.items) {
                  switch (item) {
                    case MediaItem_Artist(:final field0):
                      artists.add(field0);
                    default:
                      break;
                  }
                }
                return Column(
                  children: artists.take(6).map((artist) {
                    final isSelected =
                        _selectedArtists.any((a) => a['id'] == artist.id);
                    return ListTile(
                      leading: ClipOval(
                        child: SizedBox(
                          width: 40,
                          height: 40,
                          child: (artist.thumbnail?.url.isNotEmpty ?? false)
                              ? Image.network(
                                  artist.thumbnail!.url,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => const Icon(
                                      MingCute.user_3_line,
                                      size: 20),
                                )
                              : const Icon(MingCute.user_3_line, size: 20),
                        ),
                      ),
                      title: Text(
                        artist.name,
                        style: const TextStyle(
                          color: Default_Theme.primaryColor1,
                          fontSize: 14,
                        ),
                      ),
                      trailing: Icon(
                        isSelected
                            ? Icons.check_circle
                            : Icons.add_circle_outline,
                        color: isSelected
                            ? Default_Theme.accentColor2
                            : Default_Theme.primaryColor1
                                .withValues(alpha: 0.5),
                      ),
                      onTap: () => _toggleArtist({
                        'id': artist.id,
                        'name': artist.name,
                      }),
                    );
                  }).toList(),
                );
              },
            ),

          const SizedBox(height: 24),

          // Music Languages section
          _SectionHeader(
            title: l10n?.managePreferencesMusicLangs ?? 'Music Languages',
            subtitle: l10n?.managePreferencesMusicLangsHint ??
                'Choose languages for music recommendations.',
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _buildMusicLanguageOptions().map((lang) {
              final isSelected = _selectedMusicLangs.contains(lang['code']);
              return GestureDetector(
                onTap: () => _toggleMusicLang(lang['code']!),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Default_Theme.accentColor2.withValues(alpha: 0.2)
                        : Default_Theme.surfaceColor,
                    borderRadius: BorderRadius.circular(9999),
                    border: Border.all(
                      color: isSelected
                          ? Default_Theme.accentColor2.withValues(alpha: 0.7)
                          : Default_Theme.primaryColor1.withValues(alpha: 0.12),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isSelected)
                        const Padding(
                          padding: EdgeInsets.only(right: 6),
                          child: Icon(Icons.check,
                              size: 14, color: Default_Theme.accentColor2),
                        ),
                      Text(
                        lang['label']!,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight:
                              isSelected ? FontWeight.w700 : FontWeight.w500,
                          color: isSelected
                              ? Default_Theme.accentColor2
                              : Default_Theme.primaryColor1,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  List<Map<String, String>> _buildMusicLanguageOptions() {
    return [
      {'code': 'hi', 'label': 'Hindi'},
      {'code': 'en', 'label': 'English'},
      {'code': 'ta', 'label': 'Tamil'},
      {'code': 'te', 'label': 'Telugu'},
      {'code': 'bn', 'label': 'Bengali'},
      {'code': 'mr', 'label': 'Marathi'},
      {'code': 'pa', 'label': 'Punjabi'},
      {'code': 'ur', 'label': 'Urdu'},
      {'code': 'kn', 'label': 'Kannada'},
      {'code': 'ml', 'label': 'Malayalam'},
      {'code': 'gu', 'label': 'Gujarati'},
      {'code': 'ko', 'label': 'Korean'},
      {'code': 'ja', 'label': 'Japanese'},
      {'code': 'es', 'label': 'Spanish'},
      {'code': 'de', 'label': 'German'},
      {'code': 'fr', 'label': 'French'},
      {'code': 'pt', 'label': 'Portuguese'},
      {'code': 'zh', 'label': 'Chinese'},
    ];
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SectionHeader({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Default_Theme.primaryColor1,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: TextStyle(
            fontSize: 13,
            color: Default_Theme.primaryColor1.withValues(alpha: 0.5),
          ),
        ),
      ],
    );
  }
}

class _ArtistSearchBar extends StatefulWidget {
  final ContentBloc? contentBloc;

  const _ArtistSearchBar({required this.contentBloc});

  @override
  State<_ArtistSearchBar> createState() => _ArtistSearchBarState();
}

class _ArtistSearchBarState extends State<_ArtistSearchBar> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onSearch(String query) {
    if (query.trim().length < 2 || widget.contentBloc == null) return;
    widget.contentBloc!.add(SearchContent(
      query: query.trim(),
      filter: ContentSearchFilter.artist,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1C1624),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Default_Theme.primaryColor1.withValues(alpha: 0.12),
        ),
      ),
      child: TextField(
        controller: _controller,
        onChanged: _onSearch,
        style: const TextStyle(
          color: Default_Theme.primaryColor1,
          fontSize: 15,
        ),
        decoration: InputDecoration(
          hintText: AppLocalizations.of(context)?.onboardingSearchArtists ??
              'Search artists...',
          hintStyle: TextStyle(
            color: Default_Theme.primaryColor1.withValues(alpha: 0.4),
          ),
          prefixIcon: const Icon(
            MingCute.search_line,
            color: Default_Theme.primaryColor1,
            size: 20,
          ),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }
}
