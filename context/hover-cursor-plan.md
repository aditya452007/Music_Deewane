# Hover Effects & Hand Cursor — App-Wide Audit Fix

## Problem

Hand cursor + visible hover overlay (white 5% tint) is only applied on ~5 widgets
(`SongCardWidget`, `SquareImgCard`, `TopPickCard`, `CarouselCardView`). **50+ other
interactive widgets** across 15+ files are missing both.

## Solution: `Hoverable` wrapper + bulk-apply

### New widget: `Hoverable` (add to `hover_wrapper.dart`)

```dart
class Hoverable extends StatefulWidget {
  final Widget child;
  final BorderRadius borderRadius;
  // MouseRegion + AnimatedContainer with hover overlay
  // NO GestureDetector — child handles its own taps
}
```

~15 lines. Wraps any child with cursor + hover overlay. Does NOT interfere with
child's own tap handling. Used as:

```dart
Hoverable(child: IconButton(onPressed: ..., icon: ...))
Hoverable(child: GestureDetector(onTap: ..., child: ...))
```

### Files to edit

#### HIGH — Core navigation (always visible)

| File | Line(s) | Widget | Change |
|------|---------|--------|--------|
| `explore_screen.dart` | 433, 470 | `NotificationIcon` (no badge, with badge) | Wrap `IconButton` with `Hoverable` |
| `explore_screen.dart` | 498 | `TimerIcon` | Wrap `IconButton` with `Hoverable` |
| `explore_screen.dart` | 521 | `SettingsIcon` | Wrap `IconButton` with `Hoverable` |
| `explore_screen.dart` | 544 | `SiteIcon` | Wrap `IconButton` with `Hoverable` |
| `mini_player_widget.dart` | 160 | Main card `GestureDetector` (swipe+tap) | Wrap with `MouseRegion(cursor: click)` |
| `mini_player_widget.dart` | 489 | `_PlayPauseButton` `GestureDetector` | Wrap with `MouseRegion(cursor: click)` |
| `mini_player_widget.dart` | 541 | `_ControlButton` `InkWell` | Wrap with `MouseRegion(cursor: click)` |
| `player_screen.dart` | 83 | AppBar leading (down arrow) | Wrap `IconButton` with `Hoverable` |
| `player_screen.dart` | 92, 107 | AppBar actions (segments, more) | Wrap `IconButton` with `Hoverable` |
| `player_screen.dart` | 421 | `_DownloadButton` `IconButton` | Wrap with `Hoverable` |
| `player_screen.dart` | 578, 587, 592, 610, 615 | Player controls row (alarm, prev, lyrics, next, settings) | Wrap each `IconButton` with `Hoverable` |
| `player_screen.dart` | 680 | `_ShuffleControl` `IconButton` | Wrap with `Hoverable` |
| `player_screen.dart` | 701 | `_ExternalLinkControl` `IconButton` | Wrap with `Hoverable` |
| `player_screen.dart` | 752 | `_PlayPauseButton` fallback `GestureDetector` | Wrap with `MouseRegion(cursor: click)` |

#### MEDIUM — Secondary screens

| File | Line(s) | Widget | Change |
|------|---------|--------|--------|
| `library_screen.dart` | 410, 427, 433 | Search, create, import `IconButton`s | Wrap with `Hoverable` |
| `local_music_screen.dart` | 556, 563, 570 | Rescan, add folder, search `IconButton`s | Wrap with `Hoverable` |
| `local_music_screen.dart` | 597 | `_ActionChipButton` `InkWell` | Wrap with `Hoverable` |
| `offline_screen.dart` | 189, 200 | Refresh, search `IconButton`s | Wrap with `Hoverable` |
| `carousal_widget.dart` | 114 | Carousel item `GestureDetector` | Wrap with `MouseRegion(cursor: click)` |

#### LOW — Less frequent

| File | Line(s) | Widget | Change |
|------|---------|--------|--------|
| `horizontal_card_view.dart` | 123, 154 | Scroll left/right `IconButton`s | Wrap with `Hoverable` |
| `top_picks_widget.dart` | 116 | Refresh `IconButton` | Wrap with `Hoverable` |
| `top_picks_widget.dart` | 189 | Page dots `GestureDetector` | Wrap with `MouseRegion(cursor: click)` |
| `more_bottom_sheet.dart` | ~379, 436, 486 | `IconButton`, `InkWell` items | Wrap with `Hoverable` |
| `tab_list_widget.dart` | 132, 142 | Scroll left/right `IconButton`s | Wrap with `Hoverable` |
| `plugin_manager_screen.dart` | 142, 227, 236 | Back, refresh, install `IconButton`s | Wrap with `Hoverable` |
| `chart_view.dart` | 302, 331 | Back, refresh `IconButton`s | Wrap with `Hoverable` |
| `up_next_panel.dart` | 369, 651 | Clear queue, queue item more | Wrap with `MouseRegion(cursor: click)` |
| `fullscreen_lyrics_view.dart` | 318, 364, 455, 509, 527 | Top bar + bottom controls | Wrap with `Hoverable` |

### What we're NOT touching

- `SongCardWidget` (song_tile.dart) — already has full treatment
- `SquareImgCard` (square_card.dart) — already has full treatment
- `TopPickCard` (top_picks_widget.dart) — already has full treatment
- `CarouselCardView` (carousel_card_widget.dart) — already has full treatment
- `GlobalFooter` nav items — nav bar has its own selection highlight, cursor already present
- `PopupMenuButton` (loop control) — Flutter handles this internally
- `Tooltip` wrappers — already have `child` with cursor from inner widget

## Implementation order

1. Add `Hoverable` to `hover_wrapper.dart`
2. HIGH priority files (explore, mini player, player screen)
3. MEDIUM priority files (library, local, offline, carousel)
4. LOW priority files (remaining)
5. `dart format` + `flutter analyze`

## Verification

- `dart format` passes
- `flutter analyze --no-fatal-infos` passes (no new errors)
- Manual: hover over every IconButton → cursor changes to pointer
- Manual: hover → subtle white tint appears
- Manual: tap still works on all buttons
