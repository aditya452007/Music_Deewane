# Music_Deewane — UX Enhancement & Error Handling Checklist

> **Purpose**: Every scenario where the user can hit a wall, see a broken state, or get
> stuck — and what the app should do instead. Organized by feature/page. Derived from
> `States.md`, codebase audit, and real-world user behavior.

---

## 1. SEARCH (`/Search`)

### Current gaps
- "No results found" is generic — doesn't tell user **why** or **what to do next**
- No cross-source fallback guidance (JioSaavn vs YouTube Music vs YouTube Video)
- No spelling suggestion or "did you mean?" mechanism
- Search suggestions can fail silently
- No loading skeleton — just a spinner

### Scenarios to handle

| # | Scenario | User sees | Current behavior | Recommended behavior |
|---|----------|-----------|-----------------|---------------------|
| 1.1 | **Search returns 0 results** | "No results found" | `SignBoardWidget` with generic message | **Actionable empty state**: "No results for '[query]'. Check spelling, try different keywords, or search on YouTube Music/YouTube Video." + buttons: "Search YouTube Music" / "Search YouTube Video" (opens in-app browser or external) |
| 1.2 | **Search returns partial results** | Some results | Shows what it has | **Subtle hint**: "Showing results from [source]. Try YouTube Music for more results." (dismissable chip) |
| 1.3 | **Search plugin not loaded** | "No content plugins loaded" | `SignBoardWidget` | **Guided recovery**: "Search isn't available right now. Go to Plugin Manager to install or reload plugins." + button → Plugin Manager |
| 1.4 | **Network offline during search** | "No Internet Connection!" | `SignBoardWidget` | "You're offline. Search requires internet. Check your connection." + "Cached results available" tab if any exist |
| 1.5 | **Slow network / timeout** | Spinner hangs | No timeout feedback | Show loading state after 2s → after 5s: "Search is taking longer than usual..." + skeleton rows → after 15s: "Search timed out. Check your connection and try again." + Retry button |
| 1.6 | **Search suggestions fail** | No suggestions dropdown | Silently fails | Show dropdown with just search history (if available). Don't break the UX. |
| 1.7 | **Invalid search input** (empty, special chars) | Nothing happens | Input ignored | Subtle inline validation: "Enter at least 2 characters" |
| 1.8 | **Search with only filters, no query** | Empty | Nothing shown | "Enter a search term to find music" with example chips: "Try: Arijit Singh, Lo-fi, Bollywood 90s" |
| 1.9 | **Rapid typing / debounce** | Results flash | Current debounce works | Ensure smooth transition, no flicker. Use skeleton loading rows during debounce. |
| 1.10 | **Search result tap → track won't play** | Error snackbar | `PlayerErrorHandler` shows snackbar | "This track couldn't be played from [source]. Try another source?" + suggestion chips |
| 1.11 | **Search result → artist/album page fails** | Blank page or error | `SignBoardWidget` | "Couldn't load details. This might be a temporary issue." + Retry + Back button |

### Missing animations / UI elements
- [ ] Skeleton loading rows for search results (currently just CircularProgressIndicator)
- [ ] Smooth fade-in for results appearing
- [ ] "Did you mean: [corrected]?" chip above results
- [ ] Source indicator badges on results (🎵 JioSaavn, ▶ YouTube Music, 📹 YouTube)
- [ ] Search history section (below search bar when focused, before typing)

---

## 2. PLAYBACK (Player + MiniPlayer)

### Current gaps
- `PlayerErrorHandler` retries silently — user doesn't know what's happening
- No visual feedback when stream URL is expired/geo-blocked
- No guidance when all sources fail
- No "smart replacement" suggestion UI when primary source fails

### Scenarios to handle

| # | Scenario | User sees | Current behavior | Recommended behavior |
|---|----------|-----------|-----------------|---------------------|
| 2.1 | **Track fails to play (first attempt)** | Brief error | Auto-retry (3 attempts) | **Subtle toast**: "Having trouble playing this track..." (don't interrupt if auto-retry succeeds) |
| 2.2 | **All retry attempts exhausted** | Error snackbar | `PlayerErrorHandler` shows snackbar with retry count | **Actionable error panel**: "Couldn't play '[track]' from [source]." + "Try: YouTube Music" / "Try: JioSaavn" / "Try: YouTube Video" buttons (opens search for that track on the alternative source) |
| 2.3 | **Stream URL expired mid-playback** | Playback stops | Error → retry | Auto-retry with fresh URL. If fails: "Stream expired. Retrying..." → after 3 fails: show source alternatives |
| 2.4 | **Geo-blocked content** | Playback fails | Generic error | "This track is not available in your region. Try another source?" + source chips |
| 2.5 | **Network drops mid-playback** | Buffering stuck | `isOffline` stream triggers | Show buffering state → after 10s: "Connection lost. Playing from cache..." → after 30s: "Connection lost. Your track will resume when you're back online." + pause button |
| 2.6 | **Downloaded file deleted externally** | Play from offline fails | `MediaResolverService` finds no local file → tries online | "Downloaded file not found. Playing from online..." (transparent fallback) |
| 2.7 | **Queue ends (last track)** | Player stays on last track | Nothing happens | Auto-stop, show "Queue finished. Add more music?" with suggested tracks or library link |
| 2.8 | **Play next track in queue fails** | Skip to next silently | Auto-advance with error | "Skipping '[failed track]' — couldn't play from any source." + show the failed track dimmed in queue |
| 2.9 | **Crossfade fails** | Abrupt transition | Logs error | Silent — don't break UX for a cosmetic feature |
| 2.10 | **EQ/Audio session error** | Unknown | Logs error | "Audio settings couldn't be applied. Reset to defaults?" |
| 2.11 | **Playback from unknown plugin** | Track won't play | `PluginException` thrown | "This track's source plugin is not installed. Install [plugin name]?" + link to Plugin Manager |
| 2.12 | **Smart replacement fails** | Track skipped | `SmartTrackReplacementService` tries cross-plugin | "No alternative source found for '[track]'. Skipping..." |

### Missing animations / UI elements
- [ ] Buffering animation (pulsing dots or wave) instead of generic spinner
- [ ] Smooth transition between "playing" → "buffering" → "playing" states
- [ ] Track failure indicator in Up Next queue (dimmed + ❌ icon on failed tracks)
- [ ] Source chip on now-playing card showing current source
- [ ] Wave progress bar should pause animation when buffering (currently freezes)

---

## 3. LIBRARY (Library Screen + Playlists)

### Current gaps
- Empty library says "Your music library is a bit quiet..." — doesn't guide user to populate it
- No warning when a saved remote playlist's plugin is uninstalled
- No handling for corrupted playlist data
- Playlist with 0 songs shows generic "No songs yet"

### Scenarios to handle

| # | Scenario | User sees | Current behavior | Recommended behavior |
|---|----------|-----------|-----------------|---------------------|
| 3.1 | **Empty library (first-time user)** | "Your music library is a bit quiet..." | `SignBoardWidget` | **Onboarding empty state**: "Start your collection!" + cards: "Search for music" / "Import from Spotify" / "Import from YouTube" / "Scan local files" (each links to the respective feature) |
| 3.2 | **Empty playlist (created but no songs)** | "No songs yet" | `SignBoardWidget` | "This playlist is empty. Add songs from Search or your Library." + "Add Songs" button → Search |
| 3.3 | **Playlist not found** | Error or blank | `CurrentPlaylistCubit` throws | "Playlist '[name]' couldn't be found. It may have been deleted." + "Go to Library" button |
| 3.4 | **Saved remote collection's plugin uninstalled** | Playlist shows but tracks fail | Tracks load as errors | **Proactive warning**: Badge on playlist card: "⚠ Plugin not installed" + tap → "Install [plugin] to access this playlist" |
| 3.5 | **Library search returns nothing** | "No matches found" | `SignBoardWidget` | "No matches in your library for '[query]'. Try browsing your playlists." + link |
| 3.6 | **Add to playlist fails** | Error snackbar | `SnackbarService` shows error | "Couldn't add to playlist. The playlist may have been deleted." + retry |
| 3.7 | **Playlist has 1000+ songs** | Slow scrolling | 40/page infinite scroll exists | Ensure smooth performance. Show "Loading more..." at scroll end. No jank. |
| 3.8 | **Import from Spotify/YouTube fails** | Error in import screen | `_ErrorView` shown | **Specific error + guidance**: "Spotify link is invalid. Make sure the playlist is public." / "YouTube playlist not found. Check the URL." |
| 3.9 | **Concurrent playlist edits** | Data inconsistency | No conflict handling | "This playlist was modified elsewhere. Refresh to see changes." |
| 3.10 | **Delete playlist accidentally** | Gone | No undo | Show undo snackbar: "Playlist deleted. Undo?" (5-second window) |
| 3.11 | **Library load error** | Blank screen or error | `LibraryItemsError` → `SignBoardWidget` | "Couldn't load your library. Check your connection and try again." + Retry button |
| 3.12 | **Duplicate song in playlist** | Duplicates shown | No dedup | Allow — user may want duplicates. But offer "Remove duplicates" in edit mode. |

### Missing animations / UI elements
- [ ] Playlist card with badge for remote/local/empty status
- [ ] Drag-to-reorder animation for playlist items
- [ ] Swipe-to-delete with haptic feedback + undo snackbar
- [ ] Empty library with illustrated guidance (not just text)
- [ ] Skeleton loading for library items during initial load

---

## 4. DOWNLOADS (Offline Screen)

### Current gaps
- No guidance when download fails (just "Failed" status)
- No handling for disk full scenario
- No re-download button for failed downloads

### Scenarios to handle

| # | Scenario | User sees | Current behavior | Recommended behavior |
|---|----------|-----------|-----------------|---------------------|
| 4.1 | **Download fails (network)** | "Failed" status | `DownloadState.failed` | "Download failed. Check your connection." + "Retry" button + "Remove" button |
| 4.2 | **Download fails (disk full)** | "Failed" | Generic failure | "Not enough storage. Free up [X] MB and try again." + link to storage settings |
| 4.3 | **Download cancelled by user** | "Cancelled" | `DownloadState.cancelled` | "Download cancelled." + "Resume" button (if partial) or "Re-download" button |
| 4.4 | **Downloaded file corrupted** | Play fails | `MediaResolverService` fallback to online | "Downloaded file is corrupted. Re-downloading..." or "Re-download this track?" |
| 4.5 | **Download in progress, network drops** | "Retrying" state | `DownloadState.retrying` with backoff | Show progress + "Connection lost. Retrying..." + manual "Pause" button |
| 4.6 | **All downloads list is empty** | "No Downloads" | `SignBoardWidget` | "No downloaded music yet. Download tracks from Search or Playlists to listen offline." + "Browse Music" button |
| 4.7 | **Download queue stuck** | Items stuck in "Queued" | No timeout | After 5 min: "Download stuck? Check connection." + "Retry all" button |
| 4.8 | **Storage permission denied** | Download fails silently | Error caught | "Storage permission required. Grant permission in Settings." + "Open Settings" button |
| 4.9 | **Partial download resume** | Progress continues | Resumable download works | Show "Resuming from [X]%" with smooth progress update |

### Missing animations / UI elements
- [ ] Download progress with animated circular indicator per item
- [ ] Swipe-to-cancel or swipe-to-retry on download items
- [ ] "Clear all failed" button in download list header
- [ ] Storage usage indicator: "Using [X] GB of downloads"

---

## 5. EXPLORE / HOME (`/Explore`)

### Current gaps
- Plugin sections can fail silently (just show error state)
- No handling for when chart data is stale
- Recently played can be empty for new users
- QuickAccessChips has no empty state

### Scenarios to handle

| # | Scenario | User sees | Current behavior | Recommended behavior |
|---|----------|-----------|-----------------|---------------------|
| 5.1 | **Plugin section fails to load** | Error state in section | `DetailStatus.error` → `SignBoardWidget` | "Couldn't load this section. Tap to retry." (inline, not blocking the whole page) |
| 5.2 | **Charts unavailable** | Empty carousel or error | `ChartStatus.error` | "Charts are temporarily unavailable. Try again later." + hide carousel gracefully |
| 5.3 | **No recently played (new user)** | Empty section | Empty list | Hide section entirely OR show: "Start listening! Your recently played tracks will appear here." |
| 5.4 | **No playlists (QuickAccessChips empty)** | Empty chips row | `LibraryItemsCubit` empty | Hide chips row OR show: "Create your first playlist to see quick access here." |
| 5.5 | **Home sections load slow** | Spinner | `CircularProgressIndicator` | Skeleton rows matching the section layout (horizontal card skeletons) |
| 5.6 | **TopPicks empty** | Empty grid | No data | Hide section — don't show an empty grid |
| 5.7 | **Last.fm not configured** | `TabSongListWidget` empty | Shows empty state | "Connect Last.fm in Settings to see personalized recommendations." |
| 5.8 | **Plugin update available during browse** | Nothing | `NotificationCubit` handles | Subtle banner: "Plugins updated. Tap to refresh." |

### Missing animations / UI elements
- [ ] Skeleton loading rows for home sections (horizontal card placeholders)
- [ ] Pull-to-refresh with custom animation (matching monochrome theme)
- [ ] Smooth section fade-in as data loads
- [ ] "Refresh" action on pull-down with branded spinner

---

## 6. ARTIST / ALBUM / PLAYLIST DETAIL VIEWS

### Current gaps
- Error states are generic `SignBoardWidget`
- No handling for when a detail page's plugin is uninstalled mid-view
- No handling for when tracks in a detail page fail to load

### Scenarios to handle

| # | Scenario | User sees | Current behavior | Recommended behavior |
|---|----------|-----------|-----------------|---------------------|
| 6.1 | **Detail page fails to load** | Error state | `DetailStatus.error` → `SignBoardWidget` | "Couldn't load [artist/album/playlist]. Check your connection." + Retry + Back |
| 6.2 | **Some tracks in album fail to load** | Partial track list | Error tracks shown or skipped | Show all tracks, but failed ones are dimmed with "⚠ Unavailable" badge. Don't hide them. |
| 6.3 | **Artist page: albums fail to load** | Empty section | Error state | "Albums couldn't be loaded." section-level retry, not page-level |
| 6.4 | **Plugin uninstalled while viewing detail** | Tracks fail | `PluginNotLoadedError` | "Some tracks require [plugin] which is not installed." + "Install Plugin" button |
| 6.5 | **Infinite scroll reaches end** | No more items | Stops loading | Smooth stop, no spinner. "You've reached the end." (subtle, not a full state) |
| 6.6 | **Save to library fails** | Error snackbar | Snackbar shows error | "Couldn't save. Check your connection." + retry |
| 6.7 | **Track count mismatch** (playlist says 50, loads 48) | Fewer tracks | Some fail silently | "Showing 48 of 50 tracks. 2 unavailable." |

### Missing animations / UI elements
- [ ] Skeleton loading for detail pages (header + track list placeholders)
- [ ] Hero transition from card to detail page
- [ ] Smooth expand animation for album track list

---

## 7. LYRICS

### Current gaps
- No "lyrics not found" with alternative sources
- Lyrics search fails silently
- No handling for timed vs untimed lyrics mismatch

### Scenarios to handle

| # | Scenario | User sees | Current behavior | Recommended behavior |
|---|----------|-----------|-----------------|---------------------|
| 7.1 | **No lyrics found** | Empty or error | `SignBoardWidget` | "No lyrics found for '[track]'." + "Search manually" button + "Try LrcNet" button (if plugin available) |
| 7.2 | **Lyrics plugin not loaded** | Error | `LyricsError` | "Lyrics aren't available right now. Install a lyrics plugin in Plugin Manager." |
| 7.3 | **Lyrics timed out** | Spinner | Loading state | After 8s: "Lyrics search is taking long..." → after 20s: "Couldn't find lyrics. Try searching manually." |
| 7.4 | **Lyrics out of sync** | Scroll misaligned | Auto-offset | "Lyrics seem out of sync? Tap to adjust offset." + offset controls |
| 7.5 | **Lyrics search returns no results** | "No lyrics found" | `lyricsSearchNoResults` | "No lyrics found for '[query]'. Try different spelling or check the artist name." |
| 7.6 | **Lyrics load but are wrong song** | Wrong lyrics displayed | No verification | Show track name prominently. "Wrong lyrics? Search for correct lyrics." |
| 7.7 | **Fullscreen lyrics load fail** | Error state | `SignBoardWidget` | Graceful fallback to inline lyrics or "No lyrics available" |

### Missing animations / UI elements
- [ ] Smooth scroll animation for synced lyrics (karaoke effect)
- [ ] Lyric line highlight glow (monochrome white accent)
- [ ] Fade transition between lyrics sources
- [ ] "Searching for lyrics..." animation (pulsing text)

---

## 8. PLUGINS (Plugin Manager)

### Current gaps
- Plugin install failure shows generic error
- No guidance on which plugins to install
- No health check for installed plugins

### Scenarios to handle

| # | Scenario | User sees | Current behavior | Recommended behavior |
|---|----------|-----------|-----------------|---------------------|
| 8.1 | **Plugin install fails** | Error snackbar | `SnackbarService` shows error | "Failed to install [plugin]. Check your internet connection." + "Retry" button |
| 8.2 | **Plugin install timeout** | Stuck loading | Timeout after 45s | "Installation is taking longer than usual. Check your connection." + Retry |
| 8.3 | **No plugins installed** | "No plugins installed" | `SignBoardWidget` | "No plugins yet. Install plugins to search and play music from various sources." + "Install Recommended" button (installs default set) |
| 8.4 | **All plugins fail to load** | No search/play works | Multiple errors | **Critical state banner**: "No music sources available. Install plugins from the Plugin Manager." + persistent banner on all screens |
| 8.5 | **Plugin repository unreachable** | Can't browse/install | Error state | "Can't reach plugin repository. Check your internet connection." + cached plugin list |
| 8.6 | **Plugin update available** | Nothing | `NotificationCubit` | Badge on Plugin Manager icon + notification: "X plugins have updates." |
| 8.7 | **Corrupted plugin file** | Install fails | Validation error | "Plugin file is corrupted. Re-download from repository." + auto-remove + retry |
| 8.8 | **Plugin storage quota exceeded** | Unknown | Isar storage grows | "Plugin storage is full. Clear cache in Settings." |

### Missing animations / UI elements
- [ ] Plugin install progress animation (progress ring)
- [ ] Plugin health status indicator (green/yellow/red dot)
- [ ] "Recommended" badge on essential plugins (content resolver, search suggestion)
- [ ] Plugin card with description, version, and source info

---

## 9. IMPORT (URL / Spotify / YouTube / M3U / Backup)

### Current gaps
- Import errors are shown in `_ErrorView` but don't guide next steps
- No handling for rate limits from external services
- No handling for private playlists

### Scenarios to handle

| # | Scenario | User sees | Current behavior | Recommended behavior |
|---|----------|-----------|-----------------|---------------------|
| 9.1 | **Invalid URL** | Error | `_ErrorView` | "This URL doesn't seem right. Make sure it's a valid playlist or track URL." + example URLs shown |
| 9.2 | **Private playlist** | Error or empty | Import fails | "This playlist is private. Make it public or try a different playlist." |
| 9.3 | **Rate limited by external API** | Timeout or error | Error state | "Too many requests. Please wait a moment and try again." + auto-retry after 30s |
| 9.4 | **Partial import (some tracks fail)** | Review screen shows failures | `ImportPhase.review` | "X of Y tracks imported. Z tracks couldn't be found." + "Skip failed" / "Retry failed" options |
| 9.5 | **M3U file malformed** | Parse error | Error thrown | "This M3U file couldn't be read. Make sure it's a valid M3U format." |
| 9.6 | **Backup file corrupted** | Restore fails | Error shown | "Backup file is corrupted or incompatible. Try a different backup file." |
| 9.7 | **Import takes too long** | Spinner | No timeout feedback | After 30s: "Import is taking longer than usual..." → after 60s: "Import timed out. Try again." |
| 9.8 | **No import plugins available** | Error | No importer plugin | "No import plugins installed. Install Spotify/YouTube importer from Plugin Manager." |
| 9.9 | **Import plugin not loaded** | Error | `ContentImportCubit` error | "Import plugin is not loaded. Restart the app or reinstall the plugin." |

### Missing animations / UI elements
- [ ] Import progress with track-by-track indicator
- [ ] Success checkmark animation on completed imports
- [ ] Failed track row with ❌ + reason + "Retry" button

---

## 10. SETTINGS

### Current gaps
- No validation feedback for invalid settings values
- Backup/restore errors are generic
- No handling for storage full during backup

### Scenarios to handle

| # | Scenario | User sees | Current behavior | Recommended behavior |
|---|----------|-----------|-----------------|---------------------|
| 10.1 | **Backup fails (storage full)** | Error snackbar | `SnackbarService` | "Not enough storage for backup. Free up space and try again." |
| 10.2 | **Restore fails (wrong format)** | Error | Error dialog | "This file doesn't seem to be a valid backup. Supported formats: .isar, .json" |
| 10.3 | **Last.fm auth expired** | Scrobbling stops | Silent failure | "Last.fm connection lost. Re-authenticate in Settings." + notification |
| 10.4 | **EQ settings don't apply** | Unknown | Error logged | "Equalizer settings couldn't be applied on this device." |
| 10.5 | **Language change doesn't apply** | Partial change | Locale updated | "Restart the app to apply language changes." + "Restart Now" button |
| 10.6 | **Update check fails** | Nothing | Silent | Don't show error — updates are optional. Log internally. |

### Missing animations / UI elements
- [ ] Backup progress with percentage
- [ ] Settings save confirmation (subtle checkmark animation)

---

## 11. NETWORK STATES (App-wide)

### Current gaps
- No persistent offline indicator
- No reconnection feedback
- No bandwidth-aware behavior

### Scenarios to handle

| # | Scenario | User sees | Current behavior | Recommended behavior |
|---|----------|-----------|-----------------|---------------------|
| 11.1 | **Goes offline** | Individual errors | `ConnectivityCubit` detects | **Persistent banner**: "You're offline. Some features require internet." (bottom, above footer) |
| 11.2 | **Comes back online** | Nothing | `ConnectivityCubit` detects | Banner slides away. "You're back online." (auto-dismiss after 3s) |
| 11.3 | **Slow network** | Slow loading | No detection | After 5s of a pending request: "Slow connection detected. Loading may take longer." |
| 11.4 | **Network fluctuates** | Intermittent errors | Multiple error toasts | Debounce network errors. Single banner that updates, not multiple toasts. |
| 11.5 | **Metered network** | Same as WiFi | No detection | Optional setting: "Warn before using mobile data for streaming" |

### Missing animations / UI elements
- [ ] Offline banner with connection icon (animated reconnection)
- [ ] Smooth banner slide-up/slide-down for network state changes
- [ ] Subtle background pulse when reconnecting

---

## 12. ONBOARDING & FIRST-TIME USER

### Current gaps
- Onboarding only covers language/country + plugin bootstrap
- No feature discovery for new users
- No "what's new" after update

### Scenarios to handle

| # | Scenario | User sees | Current behavior | Recommended behavior |
|---|----------|-----------|-----------------|---------------------|
| 12.1 | **First launch** | Onboarding overlay | Language/country + plugin install | Add a brief 3-slide feature tour: "Search & Play" / "Build Your Library" / "Listen Offline" |
| 12.2 | **Post-update first launch** | Normal home | Nothing special | "What's New in Music Deewane [version]" dialog with changelog |
| 12.3 | **First search** | Normal search | Nothing | Subtle hint: "Try searching for your favorite artist or song!" |
| 12.4 | **First download** | Normal flow | Nothing | After first download: "You can find your downloads in the Offline tab." + highlight Offline tab |

### Missing animations / UI elements
- [ ] Feature discovery tooltips (spotlight on key UI elements)
- [ ] Celebration animation on first successful play
- [ ] "Welcome" card on home screen for first-time users

---

## 13. GLOBAL / CROSS-CUTTING

### Missing pages / screens

| # | Screen | Purpose | Priority |
|---|--------|---------|----------|
| 13.1 | **Network Error Page** | Full-page offline state with troubleshooting tips | HIGH |
| 13.2 | **Source Alternatives Page** | When a track fails, show all available sources | HIGH |
| 13.3 | **What's New / Changelog Screen** | Post-update feature discovery | MEDIUM |
| 13.4 | **Feature Tour / Onboarding Slides** | First-time user guidance | MEDIUM |
| 13.5 | **Storage Management Page** | Show download storage usage, clear cache | LOW |
| 13.6 | **Diagnostics / Health Check Page** | Plugin status, network test, DB integrity | LOW |

### Missing animations (app-wide)

| # | Animation | Where | Priority |
|---|-----------|-------|----------|
| 13.7 | **Skeleton loading** | All list/page loads | HIGH |
| 13.8 | **Pull-to-refresh** | Explore, Library, Search results | HIGH |
| 13.9 | **Smooth page transitions** | All navigation | MEDIUM |
| 13.10 | **Haptic feedback** | Play/pause, like, download complete | MEDIUM |
| 13.11 | **Error shake** | Invalid input, failed action | LOW |
| 13.12 | **Success checkmark** | Download complete, save to library | LOW |
| 13.13 | **Connection restored pulse** | Network reconnection | LOW |

### Missing feedback mechanisms

| # | Mechanism | Purpose | Priority |
|---|-----------|---------|----------|
| 13.14 | **Undo snackbar** | Delete playlist, remove from library | HIGH |
| 13.15 | **Confirmation dialog** | Destructive actions (delete, clear queue) | HIGH |
| 13.16 | **Progress indicator** | Long operations (import, bulk download) | MEDIUM |
| 13.17 | **Tooltip hints** | First-time use of features | LOW |
| 13.18 | **In-app notification center** | Plugin updates, new features | LOW |

---

## 14. QUALITY GATES (from States.md)

Before any feature is considered complete, verify:

- [ ] Every loading state has a completion state (no infinite spinners)
- [ ] Every success path has an error path
- [ ] Every asynchronous operation provides user feedback
- [ ] Every failure provides recovery or retry
- [ ] Every destructive action requires confirmation
- [ ] Every empty screen explains what to do next
- [ ] Every form validates before submission
- [ ] Every API call handles network failures gracefully
- [ ] Every page remains usable on slow networks
- [ ] Every interactive element provides visible feedback
- [ ] No user action leads to a dead end
- [ ] All applicable states are intentionally designed, implemented, and tested

---

## 15. PRIORITY MATRIX

### P0 — Must have (blocks user from using the app)
1. Offline banner + reconnection feedback (11.1, 11.2)
2. Search no-results → cross-source guidance (1.1)
3. Playback failure → source alternatives (2.2)
4. Empty library → guided onboarding (3.1)
5. Plugin failure → guided recovery (8.4)

### P1 — Should have (significantly improves UX)
6. Skeleton loading for all major lists (13.7)
7. Pull-to-refresh on main screens (13.8)
8. Download failure → retry + guidance (4.1, 4.2)
9. Undo snackbar for destructive actions (13.14)
10. Lyrics not found → manual search + alternatives (7.1)
11. Import error → specific guidance (9.1, 9.4)
12. Network timeout feedback (1.5, 11.3)
13. Play next fails → skip notification (2.8)
14. Empty playlist guidance (3.2)

### P2 — Nice to have (polish)
15. Feature tour for first-time users (12.1)
16. What's New dialog after update (12.2)
17. Haptic feedback (13.10)
18. Source badges on search results (1.4)
19. Storage management page (13.5)
20. Plugin health indicators (8.7)

### P3 — Future consideration
21. Diagnostics / health check page (13.6)
22. Metered network warnings (11.5)
23. Celebration animations (12.4)
24. Tooltip hints (13.17)
