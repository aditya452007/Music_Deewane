# Code Standards

## General

- Keep components/widgets small and single-purpose (~300 lines max; the codebase already stretches this in places — don't add more)
- Fix root causes — do not layer workarounds (Agent.md: grep every caller, fix where all callers route through)
- Do not mix unrelated concerns in one widget/bloc/service
- **Ponytail**: laziest solution that actually works, shortest diff, no speculative abstraction, deletion over addition
- Never modify generated code: `lib/src/rust/**` (flutter_rust_bridge) — regenerate instead
- No `npx install --force` / `npm install --force`; resolve dependency conflicts properly (for Dart: deliberate pins/upgrades + lockstep FRB)

## Dart / Flutter

- Follow existing repo patterns: `blocs/` (flutter_bloc cubits/blocs with freezed/equatable states), `services/` for logic, `repository/` for thin DAO wrappers, `core/models/` for domain models
- New domain models that cross the Rust boundary must live in Rust (`rust/src/api/plugin/models.rs`, `#[frb(mirror)]`) and regenerate — do not define parallel Dart models
- DAOs stay in `services/db/dao/` and go through `DBProvider`; no direct Isar queries in widgets
- All plugin commands via `PluginService` (typed exceptions); media IDs parsed with `tryParseMediaId` only
- State: cubit-per-domain; UI reads state via BlocBuilder/BlocListener — never hold playback state in widgets
- L10n: all user-facing strings via `AppLocalizations` (ARB), never hardcoded
- Format with `dart format`; lint with `flutter analyze` (CI: `--no-fatal-infos`)
- `dependency_overrides: ffi: ^1.1.2` is load-bearing for `dart_discord_rpc` — don't touch without retesting Discord presence

## Rust

- Follow the existing module layout under `rust/src/api/`; keep `#[frb]` surface in `bridge.rs` and ignore internals
- New plugin-facing types: add to `commands.rs`/`models.rs` with `#[frb(mirror)]`, keep `CURRENT_MANIFEST_VERSION = 1` in sync with `lib/plugins/utils/plugin_constants.dart`
- All blocking I/O inside `spawn_blocking`; reqwest is blocking by design; never hold the registry `RwLock` across an await
- WASM plugin calls are synchronous and must run inside `spawn_blocking` (per-plugin tokio Mutex)
- `cargo check` and `cargo clippy` must pass (CI: `cargo check`)
- Regenerate bindgen/WIT files only from the canonical `plugin.wit` (SDK repo — UNKNOWN location)

## Styling / Animation (Flutter)

- Colors from `core/theme/app_theme.dart` — no magic hex values inline (existing code is inconsistent; when touching a widget, extract to theme constants)
- Animate only transform/opacity-friendly properties; respect the app's existing motion conventions (see `ui-context.md`)
- No `prefers-reduced-motion` exists in Flutter today — use `MediaQuery.disableAnimations` where animations are added

## File Organization

- Follow the existing structure — do NOT restructure the repo into a different layout (architecture is preserved by decision)
- New code goes in the matching existing folder (`blocs/`, `services/`, `screens/`, `widgets/`, `core/`, `utils/`…)
- New screens add widgets to `screens/widgets/`; new UI kit components to `bloomee_ui_kit/`

## Pre-Commit Checks (Every Task)

1. `flutter analyze --no-fatal-infos` passes
2. `cargo check` passes (when Rust touched)
3. `dart format` applied to touched files
4. `context/progress-tracker.md` updated with completed work
5. `context/flow.md` updated if functions/routes/flows changed
6. `context/decision.md` has an ADR for every meaningful choice
7. No generated files edited by hand; no new dependency without an ADR + design-first approval
8. Design-first workflow followed (spec → clarify → approve → implement) — no code before approval
