import 'dart:math';

import 'package:flutter/material.dart';

import 'package:music_deewane/core/theme/app_theme.dart';
import 'package:music_deewane/screens/widgets/organic_player_control.dart';
import 'package:iconsx_plus/iconsx_plus.dart';

/// An organic play/pause button: a soft white scalloped flower with a black
/// icon. Tapping play triggers a brief white particle "relief burst" that
/// radiates outward and fades over ~900 ms.
class PlayPauseButton extends StatefulWidget {
  final double size;
  final VoidCallback? onPlay;
  final VoidCallback? onPause;
  final bool isPlaying;
  const PlayPauseButton({
    super.key,
    this.size = 70,
    this.onPlay,
    this.onPause,
    this.isPlaying = false,
  });
  @override
  State<PlayPauseButton> createState() => _PlayPauseButtonState();
}

class _PlayPauseButtonState extends State<PlayPauseButton>
    with SingleTickerProviderStateMixin {
  static const _burstDuration = Duration(milliseconds: 900);
  late final AnimationController _burstController;
  late List<_BurstParticle> _particles;

  @override
  void initState() {
    super.initState();
    _burstController = AnimationController(
      vsync: this,
      duration: _burstDuration,
    )..addListener(() => setState(() {}));
    _particles = _generateParticles();
  }

  @override
  void didUpdateWidget(covariant PlayPauseButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.isPlaying && widget.isPlaying) {
      _particles = _generateParticles();
      _burstController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _burstController.dispose();
    super.dispose();
  }

  List<_BurstParticle> _generateParticles() {
    final random = Random();
    return List.generate(
      14,
      (_) => _BurstParticle(
        angle: random.nextDouble() * 2 * pi,
        distance: 0.55 + random.nextDouble() * 0.45,
        size: 1.5 + random.nextDouble() * 2.0,
        delay: random.nextDouble() * 0.25,
      ),
    );
  }

  void _togglePlayPause() {
    if (widget.isPlaying) {
      widget.onPause?.call();
    } else {
      widget.onPlay?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    const shape = OrganicScallopShape(petals: 10, depth: 0.09, seed: 5);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: _togglePlayPause,
        child: SizedBox(
          width: size,
          height: size,
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              if (_burstController.isAnimating)
                SizedBox(
                  width: size * 2.8,
                  height: size * 2.8,
                  child: CustomPaint(
                    painter: _BurstPainter(
                      progress: _burstController.value,
                      particles: _particles,
                      baseRadius: size / 2,
                    ),
                  ),
                ),
              Material(
                color: Default_Theme.accentColor2,
                shape: shape,
                child: InkWell(
                  customBorder: shape,
                  hoverColor: Default_Theme.accentColor2dark
                      .withValues(alpha: 0.06),
                  onTap: _togglePlayPause,
                  child: SizedBox(
                    width: size,
                    height: size,
                    child: Center(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeInCubic,
                        transitionBuilder: (child, animation) {
                          return RotationTransition(
                            turns: Tween<double>(begin: 0.5, end: 1.0)
                                .animate(CurvedAnimation(
                                  parent: animation,
                                  curve: Curves.easeOutCubic,
                                )),
                            child: FadeTransition(
                              opacity: animation,
                              child: child,
                            ),
                          );
                        },
                        child: widget.isPlaying
                            ? Icon(
                                FontAwesome.pause_solid,
                                key: const ValueKey('pause'),
                                size: size * 0.42,
                                color: Default_Theme.accentColor2dark,
                              )
                            : Icon(
                                MingCute.play_fill,
                                key: const ValueKey('play'),
                                size: size * 0.45,
                                color: Default_Theme.accentColor2dark,
                              ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BurstParticle {
  final double angle;
  final double distance;
  final double size;
  final double delay;
  const _BurstParticle({
    required this.angle,
    required this.distance,
    required this.size,
    required this.delay,
  });
}

class _BurstPainter extends CustomPainter {
  final double progress;
  final List<_BurstParticle> particles;
  final double baseRadius;

  _BurstPainter({
    required this.progress,
    required this.particles,
    required this.baseRadius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final maxDist = baseRadius * 1.9;

    // Soft expanding ring pulse behind the button.
    final ringPaint = Paint()
      ..color = Colors.white.withValues(alpha: (1 - progress) * 0.22)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final ringRadius = baseRadius * (1 + progress * 1.5);
    canvas.drawCircle(center, ringRadius, ringPaint);

    // Radiating particles, each with its own slight delay.
    final particlePaint = Paint()..color = Colors.white;
    for (final p in particles) {
      final t = (progress - p.delay) / (1 - p.delay);
      if (t <= 0 || t >= 1) continue;
      final eased = Curves.easeOutCubic.transform(t);
      final dist = baseRadius + maxDist * eased * p.distance;
      final fade = 1 - Curves.easeInCubic.transform(t);
      final pos = Offset(
        center.dx + cos(p.angle) * dist,
        center.dy + sin(p.angle) * dist,
      );
      particlePaint.color = Colors.white.withValues(alpha: fade * 0.8);
      canvas.drawCircle(pos, p.size * (1 - eased * 0.4), particlePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _BurstPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
