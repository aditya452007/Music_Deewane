import 'dart:async';
import 'dart:developer' as dev;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:music_deewane/blocs/internet_connectivity/cubit/connectivity_cubit.dart';
import 'package:music_deewane/core/theme/app_theme.dart';
import 'ads_config.dart';

/// Policy-compliant Native ad card — Void Monochrome themed.
///
/// - Hidden on unsupported platforms (Web/Desktop)
/// - Hidden when offline (ConnectivityCubit)
/// - Shows "Ad" badge, never mimics SongCard
/// - 60s min refresh enforced by not re-loading before dispose
/// - On failure → SizedBox.shrink (no retry storm — ponytail)
class NativeAdCard extends StatefulWidget {
  const NativeAdCard({super.key, this.height = 280, this.margin});

  final double height;
  final EdgeInsetsGeometry? margin;

  @override
  State<NativeAdCard> createState() => _NativeAdCardState();
}

class _NativeAdCardState extends State<NativeAdCard> {
  NativeAd? _nativeAd;
  bool _isLoaded = false;
  bool _didFail = false;
  int _retryCount = 0;
  Timer? _retryTimer;
  static const _maxRetries = 2; // 3 total attempts

  @override
  void initState() {
    super.initState();
    _loadAd();
  }

  bool get _isSupported => AdsConfig.isSupported;

  void _loadAd() {
    if (!_isSupported) return;
    _nativeAd?.dispose();
    // Native template — no custom factoryId needed (uses GMA default templates).
    _nativeAd = NativeAd(
      adUnitId: AdsConfig.nativeAdUnitId,
      listener: NativeAdListener(
        onAdLoaded: (ad) {
          _retryTimer?.cancel();
          dev.log(
              'NativeAd loaded: ${AdsConfig.nativeAdUnitId} retry=$_retryCount',
              name: 'Ads');
          if (mounted) setState(() => _isLoaded = true);
        },
        onAdFailedToLoad: (ad, error) {
          // dispose failed ad
          ad.dispose();
          dev.log(
              'NativeAd failed: code=${error.code} domain=${error.domain} message=${error.message} retry=$_retryCount/$adSpecs',
              name: 'Ads');
          debugPrint(
              'NativeAd failed: code=${error.code} domain=${error.domain} message=${error.message} retry=$_retryCount');
          // retry with backoff 10s, 20s — ponytail: limited retries, not infinite storm
          if (_retryCount < _maxRetries && mounted) {
            _retryCount++;
            final delay = Duration(seconds: _retryCount == 1 ? 10 : 20);
            _retryTimer?.cancel();
            _retryTimer = Timer(delay, () {
              if (mounted && !_isLoaded) {
                dev.log('NativeAd retry $_retryCount/$_maxRetries after $delay',
                    name: 'Ads');
                _loadAd();
              }
            });
          } else {
            if (mounted) setState(() => _didFail = true);
          }
        },
        onAdClicked: (ad) {},
        onAdImpression: (ad) {},
      ),
      request: const AdRequest(),
      // Void Monochrome: dark surface #27272A, white CTAs
      nativeTemplateStyle: NativeTemplateStyle(
        templateType: TemplateType.medium,
        mainBackgroundColor: const Color(0xFF27272A),
        callToActionTextStyle: NativeTemplateTextStyle(
          textColor: Colors.white,
          backgroundColor: const Color(0xFFFAFAFA),
          style: NativeTemplateFontStyle.bold,
          size: 14,
        ),
        primaryTextStyle: NativeTemplateTextStyle(
          textColor: Colors.white,
          style: NativeTemplateFontStyle.bold,
          size: 14,
        ),
        secondaryTextStyle: NativeTemplateTextStyle(
          textColor: Color(0xFFA1A1AA),
          style: NativeTemplateFontStyle.normal,
          size: 12,
        ),
        tertiaryTextStyle: NativeTemplateTextStyle(
          textColor: Color(0xFF71717A),
          style: NativeTemplateFontStyle.normal,
          size: 11,
        ),
        cornerRadius: 16,
      ),
    )..load();
  }

  // helper for log string — keeps ad unit visible in error without leaking PII
  String get adSpecs => AdsConfig.nativeAdUnitId;

  @override
  void dispose() {
    _retryTimer?.cancel();
    _nativeAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isSupported) return const SizedBox.shrink();
    if (_didFail) return const SizedBox.shrink();

    return BlocBuilder<ConnectivityCubit, ConnectivityState>(
      builder: (context, connState) {
        if (connState == ConnectivityState.disconnected) {
          return const SizedBox.shrink();
        }
        if (!_isLoaded || _nativeAd == null) {
          // reserve space but show subtle placeholder to avoid layout shift
          return Container(
            height: widget.height,
            margin: widget.margin ??
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Default_Theme.surfaceColor.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
            ),
            child: const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white24,
                ),
              ),
            ),
          );
        }

        return Container(
          height: widget.height,
          margin: widget.margin ??
              const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF18181B),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              // Ad content
              Padding(
                padding: const EdgeInsets.only(top: 22),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: AdWidget(ad: _nativeAd!),
                ),
              ),
              // "Ad" badge — required for policy (distinguishable)
              Positioned(
                top: 8,
                left: 8,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(6),
                    border:
                        Border.all(color: Colors.white.withValues(alpha: 0.12)),
                  ),
                  child: const Text(
                    'Ad',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 8,
                right: 10,
                child: Text(
                  'Sponsored',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.35),
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Small variant for tight spaces (e.g., search inline) — 150dp.
class NativeAdSmallCard extends StatefulWidget {
  const NativeAdSmallCard({super.key});

  @override
  State<NativeAdSmallCard> createState() => _NativeAdSmallCardState();
}

class _NativeAdSmallCardState extends State<NativeAdSmallCard> {
  NativeAd? _nativeAd;
  bool _isLoaded = false;
  bool _didFail = false;
  int _retryCount = 0;
  Timer? _retryTimer;
  static const _maxRetries = 2;

  bool get _isSupported => AdsConfig.isSupported;

  void _loadSmallAd() {
    if (!_isSupported) return;
    _nativeAd?.dispose();
    _nativeAd = NativeAd(
      adUnitId: AdsConfig.nativeAdUnitId,
      listener: NativeAdListener(
        onAdLoaded: (ad) {
          _retryTimer?.cancel();
          dev.log('NativeAdSmall loaded retry=$_retryCount', name: 'Ads');
          if (mounted) setState(() => _isLoaded = true);
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          dev.log(
              'NativeAdSmall failed: code=${error.code} domain=${error.domain} message=${error.message} retry=$_retryCount',
              name: 'Ads');
          debugPrint(
              'NativeAdSmall failed: code=${error.code} msg=${error.message} retry=$_retryCount');
          if (_retryCount < _maxRetries && mounted) {
            _retryCount++;
            final delay = Duration(seconds: _retryCount == 1 ? 10 : 20);
            _retryTimer?.cancel();
            _retryTimer = Timer(delay, () {
              if (mounted && !_isLoaded) _loadSmallAd();
            });
          } else {
            if (mounted) setState(() => _didFail = true);
          }
        },
      ),
      request: const AdRequest(),
      nativeTemplateStyle: NativeTemplateStyle(
        templateType: TemplateType.small,
        mainBackgroundColor: const Color(0xFF27272A),
        callToActionTextStyle: NativeTemplateTextStyle(
          textColor: Colors.white,
          backgroundColor: const Color(0xFFFAFAFA),
          style: NativeTemplateFontStyle.bold,
          size: 13,
        ),
        primaryTextStyle: NativeTemplateTextStyle(
          textColor: Colors.white,
          style: NativeTemplateFontStyle.bold,
          size: 13,
        ),
        secondaryTextStyle: NativeTemplateTextStyle(
          textColor: Color(0xFFA1A1AA),
          style: NativeTemplateFontStyle.normal,
          size: 11,
        ),
        cornerRadius: 12,
      ),
    )..load();
  }

  @override
  void initState() {
    super.initState();
    _loadSmallAd();
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    _nativeAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isSupported || _didFail) return const SizedBox.shrink();
    return BlocBuilder<ConnectivityCubit, ConnectivityState>(
      builder: (context, conn) {
        if (conn == ConnectivityState.disconnected) {
          return const SizedBox.shrink();
        }
        if (!_isLoaded || _nativeAd == null) {
          return Container(
            height: 92,
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Default_Theme.surfaceColor.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
            ),
            child: const Center(
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white24),
              ),
            ),
          );
        }
        return Container(
          height: 92,
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF18181B),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 18),
                child: AdWidget(ad: _nativeAd!),
              ),
              Positioned(
                top: 4,
                left: 6,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text('Ad',
                      style: TextStyle(
                          color: Colors.white70,
                          fontSize: 9,
                          fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
