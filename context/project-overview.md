# Project Overview

## Overview

**Music_Deewane** is a Flutter music player forked from **BloomeeTunes** (upstream v3.0.4+0). It is an open-source, free music player: no ads, no login, plays music from third-party sources through a **WASM plugin system**, with a local library, downloads, lyrics, charts, radio, import from external services (Spotify/YouTube playlists, M3U), Last.fm scrobbling, and builds for Android, iOS, Windows, Linux, macOS, and Web.

Key architecture facts (verified from code):

- **Flutter/Dart UI + state layer** (`lib/`): `flutter_bloc` cubits/blocs, `go_router` navigation, Material 3 dark theme.
- **Rust core** (`rust/`, crate `rust_lib_music_deewane`): plugin host (WASM component runtime via wasmi/waclay), download manager, local-music metadata; bridged with `flutter_rust_bridge 2.12.0` (SSE codec, generated code in `lib/src/rust/`).
- **Playback**: `media_kit` (libmpv, dual-player crossfade) + `audio_service` for OS media session / lock screen / MPRIS / SMTC.
- **Storage**: `isar_community` (Isar fork), database `dbv3.isar`, 12 collections, DAO layer.
- **Music sources**: 5 plugin types (content resolver, chart provider, lyrics provider, search suggestion provider, content importer) installed as `.bex` archives (zstd tar with WASM component) from HTTP plugin repositories. **No provider code is in this repo** — providers are opaque WASM plugins.

The project runs on the **Template AI-development framework** (Agent.md execution protocol + `.agents/` skills + `context/` living docs) — it is the development operating system for this project.

## Goals (current phase)

1. Keep the BloomeeTunes application functional and unmodified (no app-code changes during initialization/discovery).
2. Run the Template AI framework as the standard operating procedure (design-first workflow, skill loading, context sync).
3. Maintain the `context/` system so a brand-new agent can understand the project without rediscovering it.
4. **App rename complete (Bloomee → Music Deewane)** — identity established across codebase (ADR-012).
5. Next: UI redesign via design-first workflow (ADR-008).

## Core User Flow (actual, traced from code)

1. App launch → `bootstrapApp()` → gates: legacy DB migration overlay → onboarding (language/country) → plugin bootstrap (first-run plugin install) → home tab (`/Explore`).
2. Home: plugin-driven sections, chart carousel, recently played; tap → play or detail.
3. Search: debounced suggestions + results across the active content plugin.
4. Artist / Album / Playlist detail: plugin-fetched, infinite scroll, save to library, play.
5. Playback: tap → `MusicDeewanePlayer.loadPlaylist` → `MediaResolverService` (offline-first, else `GetStreams` from plugin) → media_kit engine → mini player / full player overlay with queue ("Up Next"), lyrics, segments, EQ, sleep timer, like/download.
6. Library: playlists CRUD, favorites, history, saved remote collections, local music scan, add-to-playlist.
7. Downloads → offline tab; import (URL/plugin/M3U/backup file); settings; update checks.

## Core User Flow (actual, traced from code)

1. App launch → `bootstrapApp()` → gates: legacy DB migration overlay → onboarding (language/country) → plugin bootstrap (first-run plugin install) → home tab (`/Explore`).
2. Home: plugin-driven sections, chart carousel, recently played; tap → play or detail.
3. Search: debounced suggestions + results across the active content plugin.
4. Artist / Album / Playlist detail: plugin-fetched, infinite scroll, save to library, play.
5. Playback: tap → `BloomeeMusicPlayer.loadPlaylist` → `MediaResolverService` (offline-first, else `GetStreams` from plugin) → media_kit engine → mini player / full player overlay with queue ("Up Next"), lyrics, segments, EQ, sleep timer, like/download.
6. Library: playlists CRUD, favorites, history, saved remote collections, local music scan, add-to-playlist.
7. Downloads → offline tab; import (URL/plugin/M3U/backup file); settings; update checks.

## Target Audience

Inferred from the upstream app (not confirmed): free/independent music listeners (no ads), privacy-conscious users, cross-platform desktop users (keyboard shortcuts, Discord presence), Last.fm scrobblers. **UNKNOWN — needs developer confirmation.**

## Success Metrics (phase-appropriate)

- `context/` answers "where does the project stand" for a fresh agent (this phase's deliverable).
- `flutter analyze` and `cargo check` pass (CI `checkout.yml` standard).
- No upstream divergence beyond the AI framework during initialization.

---

## Upstream & Git Relationship

| Item | Value |
|------|-------|
| Originated from | https://github.com/HemantKArya/BloomeeTunes (upstream commit history preserved) |
| Origin repo | https://github.com/aditya452007/Music_Deewane.git (remote `origin`) |
| Upstream remote | https://github.com/HemantKArya/BloomeeTunes.git (remote `upstream`) |
| Branch | `main` (pushed, tracking origin/main) |
| Sync status | Not performed — and by decision (ADR-005) not scheduled |

### What has already been changed (vs upstream)

- **Template AI-development framework** added (140 files, commit `949c041`): `.agents/` skills, `context/` docs, `Agent.md`, `AGENTS.md`, `SKILLS.md`, `Skills.py`, `skills-lock.json`, `DESIGN*.md`, `States.md`.
- **App rename complete** (Bloomee → Music Deewane): `pubspec.yaml name: music_deewane`, 170+ Dart imports `package:music_deewane/`, symbols `MusicDeewanePlayer`/`MusicDeewanePlayerCubit`/`MusicDeewaneSwitch`/`MusicDeewaneDialog*`, Rust crate `rust_lib_music_deewane`, FRB regen, Windows/Linux/macOS/web binary/app names, CI artifacts `music_deewane_tunes_*`, exe `Music Deewane.exe`, About page credits (handle `@aditya452007`, 5 contact pills), README rewrite, 7 l10n ARBs regenerated.

### What has intentionally NOT been changed

- No application code: no Flutter/Dart/Rust/Android/iOS/desktop/web changes, no UI, colors, icons, images, layouts, functionality, architecture, dependencies, APIs, or providers.
- Functional identifiers preserved for backwards compatibility: package/bundle IDs `ls.bloomee.musicplayer` (Android/iOS/macOS), notification channel `com.BloomeePlayer.notification.status`, updater/plugin URLs (`sourceforge.net/projects/bloomee`, `hemantkarya.github.io/BloomeeTunes/*`, `bloomee.sourceforge.io`), DB/backup paths (`bloomee_backup_dbv3.isar`, `bloomeeBackup/`, `bloomee_restore_*`, `bloomee_downloads`, `bloomee_runtime_embedded_art`), M3U format tags (`#BLOOMEE-GENERATED_BY`, `#BLOOMEE-VERSION`, etc.), asset filenames (`bloomee_new_logo_c.png`, `BloomeeTunes4ZoomedOut2.png`), Discord asset key `bloomeetunes_logo`, test DB name `bloomee_legacy_migration_test_`, legacy DB comment in `legacy_db_opener.dart` (historical accuracy).

### Future upstream synchronization

- Decision: **diverge; upstream is base only** (ADR-005). No scheduled sync. If a future manual sync is ever needed: `git fetch upstream` and merge/cherry-pick deliberately, never blindly; app code is now ours to diverge.
