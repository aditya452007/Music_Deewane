# Feature Spec: Google Mobile Ads — Native Advanced (Music Deewane)

**Status:** Approved (user: "do as you wish keep ads always on")
**App ID:** `ca-app-pub-4220631457594135~1863471881`
**Ad Unit ID (Native Advanced):** `ca-app-pub-4220631457594135/9953714892`
**Scope:** `Music_Deewane` repo only — not `Music_Deewane_factory`
**Platforms:** Android + iOS (MobileAds). Desktop/Web = no-op (Void Monochrome theme preserved)
**Ads always-on:** No setting toggle, no premium gate (per user request)

---

## 1. Goals
- Integrate Google Mobile Ads SDK per https://developers.google.com/admob/flutter/quick-start + native advanced guide
- Show Native ads that match Void Monochrome palette (#09090B bg, #27272A surface, #FAFAFA text)
- 100% AdMob policy compliant (badge, no overlap, no empty screens, 60s refresh, correct test vs prod IDs)
- Zero impact on playback (no ad in player/mini-player/UpNext)

## 2. Non-Goals
- No interstitial / banner / app-open / rewarded
- No ads in `Music_Deewane_factory`
- No per-user targeting configuration beyond AdMob defaults
- No UMP consent dialog in v1 (will add if EEA traffic appears — flagged in decision.md)

## 3. Placements (all Native Medium, 280dp card, "Ad · Sponsored" badge)

### 3.1 Explore `/Explore` — PRIMARY
- After `TopPicksWidget` (SliverToBoxAdapter) — 1 card
- Interleaved every 3 plugin sections in `_HomeSectionsList` (index % 3 == 2)
- Hidden when: `sections.length <2` or `homeSectionsStatus != loaded` or `ConnectivityState.disconnected` or `filtered.isEmpty`
- File: `lib/screens/screen/explore_screen.dart:352`

### 3.2 Search `/Search` — SECONDARY
- In results `SliverList` at global positions 5, 15, 25… (every 10 after first)
- Only when `searchStatus==loaded && items.length >=6`
- File: `lib/screens/screen/search_screen.dart` (`_ContentSliver` → `_SliverSearchResults`)

### 3.3 Library `/Library` — TERTIARY
- Single card after last playlist (`SliverToBoxAdapter` bottom)
- Hidden when `playlists.isEmpty` (guided empty state) or `isSearching && !hasResults`
- File: `lib/screens/screen/library_screen.dart:305`

### 3.4 Playlist `/Library/PlaylistView` — OPTIONAL
- Single card below `_buildInfo` / above track list (not between tracks — avoids scroll jank)
- Only when `tracks.length >=5`
- File: `lib/screens/screen/library_views/playlist_screen.dart:440, 512`

### 3.5 Explicitly NEVER
PlayerScreen, MiniPlayer, UpNextPanel, Sidebar, HorizontalNavBar, Onboarding, Settings, OfflineBanner area.

## 4. Technical Design

### 4.1 Dependency
`pubspec.yaml: + google_mobile_ads: ^5.3.0` (compatible with flutter 3.44.9, compileSdk 36). Keep `ffi ^2.2.0` override.

### 4.2 Platform Config
- `android/app/src/main/AndroidManifest.xml` inside `<application>`:
  ```xml
  <meta-data android:name="com.google.android.gms.ads.APPLICATION_ID"
             android:value="ca-app-pub-4220631457594135~1863471881"/>
  ```
  `INTERNET` permission already present — no change.
- `ios/Runner/Info.plist`:
  ```xml
  <key>GADApplicationIdentifier</key><string>ca-app-pub-4220631457594135~1863471881</string>
  <key>SKAdNetworkItems</key><array><dict><key>SKAdNetworkIdentifier</key><string>cstr6suwn9.skadnetwork</string></dict></array>
  ```

### 4.3 Initialization
`lib/main.dart:153 main()`:
```dart
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:flutter/foundation.dart';
...
WidgetsFlutterBinding.ensureInitialized();
if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
  MobileAds.instance.initialize();
}
```
Guarded by `!kIsWeb` + `io.Platform`. No await needed (fire-and-forget), does not block bootstrap.

### 4.4 Service + Widget (fewest files)
```
lib/services/ads/
  ads_config.dart      // const appId, prodAdUnit, testAdUnit, isSupported()
  native_ad_card.dart  // StatefulWidget: loads NativeAd, AdWidget, handles fail, 60s refresh, dark style
```
- `AdsConfig.isSupported` → `!kIsWeb && (Platform.isAndroid||Platform.isIOS)`
- `AdsConfig.adUnitId` → `kReleaseMode ? prod : test` (test = `ca-app-pub-3940256099942544/2247696110`)
- `NativeAdCard` state:
  - `initState`: if !supported → no-op
  - `load()`: `NativeAd(adUnitId: AdsConfig.adUnitId, request: AdRequest(), nativeTemplateStyle: NativeTemplateStyle(templateType: TemplateType.medium, mainBackgroundColor: #27272A, callToActionTextStyle: ...), listener: NativeAdListener(...))`
  - On `onAdLoaded`: setState → show `SizedBox(height:280, child: AdWidget)`
  - On `onAdFailedToLoad`: log, dispose, show `SizedBox.shrink()` (no retry loop >3 — ponytail: simple)
  - On `onAdClicked`: no custom handler (policy: don't incentivize)
  - `dispose`: ad.dispose()
  - Wrap with `BlocBuilder<ConnectivityCubit>` → hidden when disconnected
  - Outer container: `BoxDecoration(color:#18181B, borderRadius:16, border:1px #27272A)`, top-left "Ad" badge (white 10% bg, 10px text)

### 4.5 Request Flow
```
App launch → MobileAds.initialize() → (no ad yet)
Explore/Search/Library render → NativeAdCard.initState → NativeAd.load() → Google ad server → AdWidget
Connectivity loss → BlocBuilder hides ad (no request)
Ad closed/dismissed → dispose
```

### 4.6 Error Strategy
- Load failure → shrinks to 0 height, no placeholder, no retry storm.
- Null adUnitId / unsupported platform → render nothing.
- `PlatformException` during init → catch + debugPrint, app continues.

### 4.7 Privacy
- Minimal: `app-ads.txt` at repo root + `ghpage` branch (`google.com, pub-4220631457594135, DIRECT, f08c47fec0942fa0`)
- `frontend/privacy.html` disclosure added (AdMob collects Advertising ID, IP, device info). In-app privacy screen links same.

## 5. Success Criteria
- `flutter analyze` 0 issues
- `flutter build apk --debug` succeeds with ads showing test ad on Android
- No ad overlaps player controls (manual QA: open player, verify no ad behind)
- No ad when offline or empty list
- Release APK uses prod ID only (verified via `strings` or log)

## 6. Risks & Mitigations
- `google_mobile_ads` version skew with `media_kit` → pin to ^5.3, verify `compileSdk 36` (already 36)
- MSIX rebuild overwriting exe version (ADR-046) — not affected; mobile ads not in Windows build
- iOS unbuildable — config added but not blocking Android release

## 7. Future (not in v1)
- UMP consent for EEA (add `google_mobile_ads` UMP after first AdMob warning)
- Frequency capping per session
- Remove-ads purchase

