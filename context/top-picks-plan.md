# Top Picks Section — Implementation Plan

## Summary

Replace the "Recently Played" section in `explore_screen.dart` with a YouTube Music Speed Dial-style paginated grid. Single new file + one edit to the explore screen.

---

## File Changes

### 1. NEW: `lib/screens/widgets/top_picks_widget.dart`

**Widget: `TopPicksWidget`**

```
StatefulWidget
├── PageController (for horizontal page swiping)
├── _currentPage (int, drives dot indicators)
└── _shuffledTracks (List<Track>, shuffled copy of RecentlyCubit tracks)
```

**Layout structure:**
```
Column
├── Row (section header)
│   ├── "Top Picks" label (accentColor2, secondoryTextStyle, 20px)
│   └── IconButton (MingCute.refresh_2_line) → re-shuffles _shuffledTracks
├── SizedBox (height = grid height, responsive)
│   └── PageView.builder
│       └── GridView.count (crossAxisCount: 3 mobile / 4 tablet/desktop)
│           └── _TopPickCard (per track)
└── Row (page dots, centered, top margin 16px)
```

**Responsive breakpoints** (using `ResponsiveBreakpoints.of(context)`):
- Mobile (`smallerOrEqualTo(TABLET)`): 3 cols × 3 rows = 9/page
- Tablet/Desktop: 4 cols × 2 rows = 8/page

**Card: `_TopPickCard`** (private widget in same file)
- AspectRatio 1:1 via `GridView.count(childAspectRatio: 1.0)`
- `ClipRRect` with `BorderRadius.circular(12)`
- Stack:
  - `LoadImageCached` (deterministic, fills card)
  - Gradient scrim: `Positioned(bottom: 0, left: 0, right: 0, height: 40% of card)` → `Container` with `LinearGradient` from `Colors.transparent` to `Colors.black54` (matches `rgba(0,0,0,0.7)` approx)
  - Title (white, bold, 13px, max 2 lines, ellipsis) — positioned bottom-left with padding
  - Artist (`#AAAAAA`, 11px, max 1 line, ellipsis) — below title
- Press: `AnimatedScale(scale: 0.96)` + `AnimatedOpacity(opacity: 0.85)` — matches `SquareImgCard` pattern
- Hover: `MouseRegion` → white 5% tint overlay — matches `SquareImgCard` pattern
- Long press: `showMoreBottomSheet(context, track)`
- Tap: `player.loadPlaylist(Playlist(tracks: _shuffledTracks, title: 'Top Picks'), idx: index, doPlay: true)`

**Dot indicators:**
- Row, centered, `MainAxisAlignment.center`
- Active: white, 8px diameter
- Inactive: `Color(0xFF717171)`, 6px diameter
- Gap: 8px between dots
- Top margin: 16px from grid

**Data flow:**
1. `BlocBuilder<RecentlyCubit, RecentlyCubitState>` wraps the widget
2. On state change (or on refresh button tap): shuffle tracks, reset to page 0
3. `PageView.builder(pageCount: (tracks.length / itemsPerPage).ceil())`
4. Each page: `GridView.count` with `itemCount: min(itemsPerPage, tracks.length - pageIndex * itemsPerPage)`

### 2. EDIT: `lib/screens/screen/explore_screen.dart`

**What changes:**
- Replace the `BlocBuilder<RecentlyCubit, RecentlyCubitState>` block (lines 186-245) that renders `TabSongListWidget` + `InkWell` → `HistoryView`
- Replace with a single `TopPicksWidget()` widget
- Remove `import '../widgets/tab_list_widget.dart';` if no longer used elsewhere in this file (check: it's also used for Last.fm Picks at line 256 — keep the import)

**New code replaces lines 184-245:**
```dart
const TopPicksWidget(),
```

That's it — one line. The `TopPicksWidget` internally handles its own `BlocBuilder<RecentlyCubit, RecentlyCubitState>`.

### 3. EDIT: `lib/l10n/app_en.arb` (and 6 other locale files)

Add new string:
```json
"exploreTopPicks": "Top Picks"
```

**However** — to avoid touching 7 ARB files + re-running `flutter gen-l10n`, use the existing `exploreRecently` key with a new name. Or simpler: just hardcode "Top Picks" in the widget (it's a branded section name, not user-translatable content). Decision: **hardcode "Top Picks"** — it's a product name, not a translatable label. YAGNI on l10n for a section title.

---

## Interactions

| User action | Response |
|-------------|----------|
| Tap card | Play track immediately via `loadPlaylist` with all shuffled tracks as queue context |
| Long press card | `showMoreBottomSheet(context, track, showSinglePlay: true)` |
| Swipe left/right | `PageView` snaps to next/previous page |
| Tap dot indicator | `PageController.animateToPage(index)` |
| Tap refresh icon | Re-shuffle track list, animate to page 0 |
| Pull to refresh (parent) | Already handled by `RefreshIndicator` in `ExploreScreen` |

---

## What We're NOT Doing (ponytail)

- **No new cubit** — reusing `RecentlyCubit` as-is, shuffling client-side
- **No new data fetching** — 15 tracks from history is enough for 2 pages; 3rd page will have fewer items (YAGNI on padding with fake items)
- **No new animations beyond existing patterns** — scale/opacity from `SquareImgCard`, dot transitions are simple setState
- **No l10n changes** — "Top Picks" is a product name, hardcoded
- **No new dependencies** — `PageView`, `GridView.count` are Flutter built-ins; `responsive_framework` already installed
- **No separate desktop layout** — tablet/desktop share the same 4x2 grid; nav rail is handled by the shell

---

## Verification

1. `dart format lib/screens/widgets/top_picks_widget.dart lib/screens/screen/explore_screen.dart`
2. `flutter analyze --no-fatal-infos` from `Music_Deewane/`
3. Visual: 3×3 grid with dots on mobile viewport
4. Visual: 4×2 grid with dots on tablet/desktop viewport
5. Swipe between pages works
6. Tap card plays track with full queue context
7. Refresh button shuffles and resets to page 0
8. Long press shows bottom sheet
