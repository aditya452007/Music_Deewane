# Architecture Context

## Stack

| Layer | Technology | Role |
|-------|-----------|------|
| App framework | Flutter (CI pins 3.35.4), Dart SDK `>=3.3.0 <4.0.0` | Cross-platform UI + app logic |
| State management | `flutter_bloc` 9 / `bloc` 9, `rxdart` (streams), `equatable` | Cubits/blocs per domain; stream combinators |
| Routing | `go_router` 16 (`StatefulShellRoute.indexedStack`, 5 branches) | Navigation shell + routes |
| Local DB | `isar_community` 3.3.0-dev.3 (community fork — upstream isar unmaintained) | `dbv3.isar`, 12 collections, DAOs |
| Playback | `media_kit` 1.2.6 + `media_kit_libs_audio` (libmpv) | Dual-player A/B engine with crossfade |
| Media session | `audio_service` 0.18 + `audio_session`, `audio_service_mpris` (Linux), `audio_service_win` (Windows) | Lock screen, notification, MPRIS, SMTC |
| Rust bridge | `flutter_rust_bridge` **=2.12.0 (exact pin, both sides)** | SSE-codec FFI bridge, generated `lib/src/rust/` |
| Rust core | crate `rust_lib_music_deewane` (`rust/` + `rust_builder/` cargokit FFI plugin) | Plugin host, downloads, local music metadata |
| Plugin runtime | `waclay` 0.2.2 + `wasm_runtime_layer` + **wasmi** (interpreter) | WASM component plugin execution |
| Networking | Dart `http`; Rust `reqwest` 0.12 (blocking, rustls-tls) | HTTP in both layers |
| Monetization | `google_mobile_ads` 9.1.0 + `webview_flutter` | Native Advanced ads (Android/iOS only, Void Monochrome theme, 60s interval, badge) |
| Localization | `flutter_localizations` + `intl`, 7 locales (de, en, es, hi, ja, ko, zh) | l10n via ARB |

## Module Map (Dart, `lib/`)

| Folder | Responsibility |
|--------|---------------|
| `main.dart` | Entry point, bootstrap orchestration, root widget tree, 21 root providers, overlay gates |
| `blocs/` | State: player, library, search, history, downloads, settings, timer, connectivity, lyrics, LastFM, notifications, local music, global events, mini player, player overlay |
| `core/` | Models (`models/` re-export Rust-generated types), constants (setting keys, cache keys, routes), `di/service_locator.dart` (static DI), `events/global_event_bus.dart`, `theme/app_theme.dart`, `adapters/track_adapter.dart` (Track↔MediaItem) |
| `plugins/` | Dart plugin-system layer: `PluginBloc`, `ContentBloc`, `ChartBloc`, `ContentImportCubit`, repository models/services, typed exceptions, media-id utils |
| `repository/` | Thin wrappers: downloads, notifications, scrobbling (`LastFM/lastfmapi.dart` HTTP client), search, settings |
| `routes/` | `app_router.dart` — the single GoRouter config |
| `screens/` | All UI: 5 shell branches, player, chart, common detail views, settings, library views, widgets (cards, mini player, overlays, dialogs, `bloomee_ui_kit/`) |
| `services/` | DB + DAOs + mappers + legacy migration, player stack (engine/queue/resolver/error handling), plugin services, **ads** (`ads/ads_config.dart`, `ads/native_ad_card.dart` — Native advanced, always-on), download, cache, import/export, updater, shortcuts, onboarding, Discord, bootstrap |
| `src/rust/` | **Generated** by flutter_rust_bridge — do not edit |
| `utils/` | Helpers: ticker, url checker, country info, download types, palettes, image loading |
| `l10n/` | ARB sources + generated localizations |

## Rust Module Map (`rust/src/`)

| Module | Responsibility |
|--------|---------------|
| `api/bridge.rs` | Entire FRB-exposed API surface (`#[frb]` fns) |
| `api/plugin/` | **The plugin system**: `PluginManager` (registry, dispatch), `Plugin` trait, 5 adapters (content resolver, chart provider, lyrics provider, search suggestion, content importer) with WIT bindgen glue, WASM loader (`waclay`), wasmi engine, `.bex` unpacker (zstd tar), manifest v1 validation, event stream, storage callbacks |
| `api/downloader/` | `DownloadManager`: resumable tasks, retry/backoff, stream selection, tag/cover embedding (lofty), JSON state manifest |
| `api/local_music.rs` | Local audio metadata: lofty tags, cover extraction/resize (image), recursive scan |
| `utils/` | `filename_extractor` |

## System Boundaries

- **Dart UI → Dart state (`blocs/`) → services → DAOs → Isar.** Widgets mostly route through cubits; some blocs construct DAOs directly.
- **Dart → Rust**: exclusively through `PluginService` / `RustDownloadService` / `LocalMusicService` calling generated bridge fns in `lib/src/rust/`. `RustLib.init()` in `services/bootstrap.dart`.
- **Rust → WASM plugins**: `PluginManager.handle_plugin_request` (spawn_blocking + per-plugin tokio Mutex) → adapter → WIT bindgen export → WASM component; host functions: `http_request` (blocking reqwest, 30s timeout), `random_number`, `current_unix_timestamp`, storage get/set. Entity IDs stamped `"pluginId::"`.
- **Rust → Dart events**: `StreamSink<PluginManagerEvent>` / `StreamSink<DownloadManagerEvent>` → broadcast buses in Dart.
- **Playback boundary**: Rust produces URLs + metadata only — **no audio decoding in Rust**; media_kit decodes/plays in Dart.
- **OS integration**: no custom native code anywhere — all via plugins (audio_service, media_kit, permission_handler, share_handler, google_mobile_ads, etc.) and stock runners.

## Data Flow (top level)

```
UI (screens) → cubits/blocs → services/repositories → DAOs → Isar
                                    ↘ PluginService → FRB bridge → Rust PluginManager → WASM plugin → HTTP (reqwest)
playback: MediaResolverService (offline check → GetStreams) → StreamQualitySelector → PlayerEngine (media_kit) → audio_service (OS session)
downloads: DownloaderCubit → RustDownloadService → Rust DownloadManager → file + DownloadDAO + _DOWNLOADS playlist
storage: appSupportDir/dbv3.isar · appSupportDir/plugins/ (installed .bex) · download dir per platform · appDocDir (imports/backups)
```

## Dependency Direction

- `screens → blocs → repositories → DAOs → DBProvider → Isar`
- `screens/blocs → PluginService (via ServiceLocator) → src/rust bridge`
- `services/player/*` is the hub of playback logic; `PlayerEngine` is the only media_kit owner.
- Never import `src/rust/` internals directly from widgets; never bypass `PluginService` for plugin commands (it maps Rust errors to typed `PluginException`s).

## Storage Model

- Isar `dbv3.isar`: `TrackDB`, `PlaylistDB`, `PlaylistEntryDB`, `NotificationsDB`, `LyricsDB`, `SearchHistoryDB`, `DownloadDB`, `AppSettingsStrDB`, `AppSettingsBoolDB`, `PlaybackHistoryDB`, `CacheEntryDB`, `PluginStorageEntity` (mirror of Rust storage).
- Playlists are link-based (entries with position, gap-tolerant ordering); system playlists: `Liked`, `_DOWNLOADS`, `_LOCAL_MUSIC`, `recently_played`.
- Backups: Isar snapshot (`copyToFile`) + legacy JSON formats; import/export via `ImportExportService`.
- Plugin storage is two-layer: Rust in-memory → `storageSet` events → `PluginStorageEntity` in Isar (preloaded back at startup).

## Invariants

1. Never edit `lib/src/rust/` (generated) or `frb_generated*` — regenerate with flutter_rust_bridge 2.12.
2. flutter_rust_bridge must stay **exact-pinned `=2.12.0`** on BOTH Dart and Rust sides — move in lockstep or regenerate.
3. Media IDs are `"{pluginId}::{localId}"` — always parse via `tryParseMediaId`; never split manually.
4. All plugin commands go through `PluginService`; errors surface as typed `PluginException` via `GlobalEventBus`.
5. `dependency_overrides: ffi: ^1.1.2` — required by `dart_discord_rpc`; do not remove.
6. No `npx install --force` / `npm install --force`; resolve conflicts properly (Flutter: pin/upgrade deliberately).
7. Design-first workflow + skill loading + context sync are mandatory (Agent.md) — not optional for any task.
8. Playback state lives in `MusicDeewanePlayer` (audio_service handler) + `MusicDeewanePlayerCubit` (global); UI must not hold its own playback state.

## Known Unknowns (from discovery — need developer confirmation)

1. Default plugin catalogue content (`https://hemantkarya.github.io/BloomeeTunes/repositories.json` — not in repo; `ghpage/repositories.json` is deploy-time).
2. Plugin SDK / canonical `plugin.wit` sources — not in this repo (bindgen is generated).
3. iOS build status: no Podfile committed, no `UIBackgroundModes` audio, no permission strings — effectively unbuildable as committed; CI builds only Windows/Android/Linux.
4. Android `versionCode = 0` (from `3.0.4+0`) — likely breaks store uploads.
5. Android release signing silently falls back to debug signing (no `key.properties`/`bloomee.jks`).
6. macOS Release entitlements lack `network.client` (sandboxed release may block streaming).
7. Web (wasm32) Rust build not wired into rust_builder — web build status unknown.
8. `quinn` (QUIC) in Cargo.lock but not Cargo.toml.
9. Android `network_cfg.xml` orphaned (not referenced in manifest); `share_targets.xml` points at `MainActivity` which is not the launcher (`AudioServiceActivity` is).
10. OS-level notification permission flow not visible in Dart.
11. `offline_views/downloads_status.dart` appears unused (dead code?).
12. Unregistered route constants `MainPage`/`TestPage`/`MusicPlayer` — vestigial.
13. Last.fm integration (scrobbling) — functional in code; legacy status unknown.
