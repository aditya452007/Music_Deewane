import 'package:flutter/foundation.dart';

/// Central config for Google Mobile Ads.
///
/// App ID: ca-app-pub-4220631457594135~1863471881  (manifest / Info.plist)
/// Ad Unit: ca-app-pub-4220631457594135/9953714892 (Native Advanced)
class AdsConfig {
  AdsConfig._();

  /// Production ad unit — use only in release builds.
  static const String prodNativeAdUnitId =
      'ca-app-pub-4220631457594135/9953714892';

  /// Google test ad unit for Native Advanced (safe for debug/profile).
  static const String testNativeAdUnitId =
      'ca-app-pub-3940256099942544/2247696110';

  /// Returns true only on Android/iOS, never on Web/Desktop.
  static bool get isSupported {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  /// Correct ad unit for current build mode.
  static String get nativeAdUnitId =>
      kReleaseMode ? prodNativeAdUnitId : testNativeAdUnitId;

  /// App ID (for reference, actual value lives in manifest/plist).
  static const String appId = 'ca-app-pub-4220631457594135~1863471881';
}
