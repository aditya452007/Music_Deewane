import 'package:flutter/material.dart';

/// Wraps any child with cursor + hover overlay.
/// Unlike [HoverWrapper], does NOT add a GestureDetector —
/// the child handles its own taps.
class Hoverable extends StatefulWidget {
  final Widget child;
  final BorderRadius borderRadius;

  const Hoverable({
    super.key,
    required this.child,
    this.borderRadius = BorderRadius.zero,
  });

  @override
  State<Hoverable> createState() => _HoverableState();
}

class _HoverableState extends State<Hoverable> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: _hovering
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.transparent,
          borderRadius: widget.borderRadius,
        ),
        child: widget.child,
      ),
    );
  }
}

class HoverWrapper extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final BorderRadius borderRadius;

  const HoverWrapper({
    super.key,
    required this.child,
    this.onTap,
    this.borderRadius = BorderRadius.zero,
  });

  @override
  State<HoverWrapper> createState() => _HoverWrapperState();
}

class _HoverWrapperState extends State<HoverWrapper> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: _hovering
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.transparent,
            borderRadius: widget.borderRadius,
          ),
          child: widget.child,
        ),
      ),
    );
  }
}
