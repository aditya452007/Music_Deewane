import 'dart:math';

import 'package:flutter/material.dart';

import 'package:music_deewane/core/theme/app_theme.dart';

/// Softly scalloped, flower-petal-like shape with rounded organic curves.
///
/// The radius is modulated by a cosine wave so the outline alternates between
/// gentle peaks (petals) and valleys. Each petal gets a deterministic,
/// seed-based amplitude so the flower feels hand-made, never machine-perfect.
class OrganicScallopShape extends ShapeBorder {
  /// Number of petals around the flower.
  final int petals;

  /// How deep the scallops cut in (0 = perfect circle, ~0.15 = pronounced).
  final double depth;

  /// Seed for per-petal amplitude variation (0.8x–1.2x).
  final int seed;

  const OrganicScallopShape({
    this.petals = 10,
    this.depth = 0.09,
    this.seed = 7,
  });

  double _ampForPetal(int idx) {
    final h = ((idx + 1) * 0x9E3779B1) & 0xFFFFFFFF;
    return 0.8 + ((h >> 16) % 100) / 250;
  }

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.zero;

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      getOuterPath(rect, textDirection: textDirection);

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    final center = rect.center;
    final radius = rect.shortestSide / 2;
    const segments = 96;
    final path = Path();
    for (int i = 0; i < segments; i++) {
      final t = i / segments * 2 * pi;
      final petalIdx = (i * petals / segments).floor();
      final amp = _ampForPetal(petalIdx);
      final r = radius * (1 + depth * amp * cos(petals * t));
      final p = Offset(center.dx + cos(t) * r, center.dy + sin(t) * r);
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    path.close();
    return path;
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {}

  @override
  ShapeBorder scale(double t) => this;
}

/// A control button in the organic player language.
///
/// Inactive (default): white surface with a black icon — matches the play
/// button. Active: dark surface with a white icon — the inverse cue when a
/// toggle (loop, shuffle) is engaged.
class OrganicIconButton extends StatelessWidget {
  final IconData icon;
  final double iconSize;
  final double size;
  final VoidCallback? onPressed;
  final bool isActive;
  final int petals;
  final double depth;

  const OrganicIconButton({
    super.key,
    required this.icon,
    this.iconSize = 22,
    this.size = 52,
    this.onPressed,
    this.isActive = false,
    this.petals = 10,
    this.depth = 0.09,
  });

  @override
  Widget build(BuildContext context) {
    final shape = OrganicScallopShape(petals: petals, depth: depth, seed: 3);
    final icon = Icon(
      this.icon,
      size: iconSize,
      color: isActive
          ? Default_Theme.primaryColor1
          : Default_Theme.accentColor2dark,
    );
    final content = SizedBox(width: size, height: size, child: Center(child: icon));

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: Material(
        color:
            isActive ? Default_Theme.surfaceColor : Default_Theme.accentColor2,
        shape: shape,
        child: onPressed != null
            ? InkWell(
                customBorder: shape,
                hoverColor: isActive
                    ? Colors.white.withValues(alpha: 0.08)
                    : Default_Theme.accentColor2dark.withValues(alpha: 0.06),
                onTap: onPressed,
                child: content,
              )
            : content,
      ),
    );
  }
}
