# UI Context — Design Language

> Current state = the **existing Bloomee UI** (preserved as-is). Full redesign is planned
> later (ADR-008) — when it starts, load `design-basics` + `premium-design` +
> `DESIGN-PSYCHOLOGY.md` and update this file. Until then, this documents the current
> design language so agents don't "improve" it accidentally.

## Theme

- **Dark-only, Material 3** (`useMaterial3: true`, `Brightness.dark`). No light theme, no `ThemeMode`, no dynamic color (no `ColorScheme.fromSeed` anywhere).
- Single theme instance: `Default_Theme().defaultThemeData` (`lib/core/theme/app_theme.dart`) created in `main.dart`.
- Aesthetic: near-black backgrounds with glass/frosted surfaces, pink/cyan accent pair, glowing gradient elements, ambient artwork-palette glow behind the player.
- Responsive (via `responsive_framework`): MOBILE 0–450, TABLET 451–800, DESKTOP 801–1920, 4K 1921+.

## Colors (from `app_theme.dart`)

| Role | Dart value | Notes |
|------|-----------|-------|
| Theme/background | `0xFF0A040C` | near-black page background |
| Primary text | `0xFFDAEAF7` | off-white |
| Secondary text | `0xFFF2E7F0` | |
| Accent 1 | `0xFF0EA5E0` | cyan |
| Accent 1 light | `0xFF18C9ED` | |
| Accent 2 (primary) | `0xFFFE385E` | pink/red — ColorScheme primary |
| Surface container highest | `0xFF1A111B` | surfaces |
| Success | `0xFF5EFF43` | |

Artwork palette extraction (`palette_generator`, `lib/utils/pallete_generator.dart`) drives the player's ambient radial glow — not part of the global theme.

## Typography

| Role | Font (declared in pubspec) | Notes |
|------|---------------------------|-------|
| Default body | Gilroy | default font family |
| Display headings | Fjalla | |
| Tertiary | CodePro | |
| Mini player / track titles | Unageo | |
| Others | NotoSans, ReThink-Sans | |
| Icons | FontAwesome (Regular/Solids/Brands) + `icons_plus` (MingCute set) | |

## Border Radius / Shape

- Cards/surfaces: rounded; frosted-glass dialog kit (`bloomee_ui_kit/bloomee_dialog.dart`) uses translucent surfaces with blur.
- Progress bar: custom `GradientProgressBar` (gradient presets via `GradientGenerator`).
- Exact radius tokens are defined inline in widgets (no token layer yet) — **UNKNOWN if a consistent scale exists; check `app_theme.dart` before styling anything.**

## Component Library / Conventions

- `lib/screens/widgets/` is the shared widget layer: `SongCardWidget` (universal track row), `SquareImgCard`, album/artist/playlist cards, `MiniPlayerWidget`, `PlayerOverlayWrapper`, `UpNextPanel`, `showMoreBottomSheet` (universal track options), `SignBoard` (empty/error states), `SnackbarService`.
- `bloomee_ui_kit/` — canonical dialogs (`showBloomeeDialog`, `BloomeeDialogSurface`, `BloomeeDialogTile`, `BloomeeDialogBadge`).
- Settings UI kit: `home_views/setting_views/setting_shared_widgets.dart` (SettingCard, SettingToggleTile, SettingNavTile, SettingQualityChip, SettingDestructiveTile…), `BloomeeSwitch`.
- No external component library is used (it's a Flutter app — DESIGN.md's web component guidance does not apply; treat `widgets/` as the de-facto design system).

## Layout Patterns

- **Shell**: `GlobalFooter` — mobile: bottom `GNav` bar (google_nav_bar) + mini player above it; desktop/tablet: Spotify-style collapsible sidebar (`_SpotifySidebar`, 72px collapsed / 280px expanded) + mini player at bottom. Sidebar has Home + Search nav items, "Your Library" header, scrollable playlist list from `LibraryItemsCubit`. 5 tabs: Home, Library, Search, Local, Offline.
- Branch transitions: fade+scale 250 ms (`_AnimatedPageView`).
- Full player = persistent overlay (mounted once, `PlayerOverlayCubit<bool>`), not a route. Up Next queue = `DraggableScrollableSheet` panel (bottom sheet on mobile, side panel on desktop).
- Home: sections as horizontal scroll rows, chart carousel, recents grid.

## Motion

- Mini player slide/fade 350 ms; player overlay slide-up/fade 300 ms.
- Entry animations via `AnimatedListItem`.
- Animated play/pause (`PlayPauseButton`), like button (`LikeBtnWidget`), volume drag on artwork (`VolumeDragController`).
- Follow existing widget animations when editing; match the app's duration/curve conventions (no universal motion token layer exists).

## Localization

- 7 locales: `de, en, es, hi, ja, ko, zh`. ARB in `lib/l10n/`; run `flutter gen-l10n` after editing ARBs.
- Locale from `SettingsCubit.state.languageCode` (empty = system default); onboarding picks language + country.

## Update Protocol

- Any visual change must update this file AND get an ADR in `context/decision.md` (template requirement: every meaningful visual decision is logged).
- Redesign work starts by loading `design-basics`, `premium-design`, and reading `DESIGN-PSYCHOLOGY.md` first — never guess design decisions.
