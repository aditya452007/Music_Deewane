import 'dart:math';

import 'package:flutter/material.dart';

import 'package:music_deewane/core/theme/app_theme.dart';

/// A progress bar whose played portion flows as a gentle, continuously
/// undulating wave instead of a straight line. The wave only moves while
/// playing; it freezes on pause. Flat white, no glow.
class WaveProgressBar extends StatefulWidget {
  final Duration progress;
  final Duration total;
  final Duration buffered;
  final ValueChanged<Duration>? onSeek;
  final bool isPlaying;
  final double trackHeight;
  final double thumbRadius;
  final bool showTimeLabels;
  final TextStyle? timeLabelStyle;
  final Color activeColor;
  final Color inactiveColor;
  final Color bufferedColor;

  const WaveProgressBar({
    super.key,
    required this.progress,
    required this.total,
    this.buffered = Duration.zero,
    this.onSeek,
    this.isPlaying = true,
    this.trackHeight = 6.0,
    this.thumbRadius = 8.0,
    this.showTimeLabels = true,
    this.timeLabelStyle,
    this.activeColor = Colors.white,
    this.inactiveColor = Default_Theme.surfaceElevatedColor,
    this.bufferedColor = Default_Theme.borderColor,
  });

  @override
  State<WaveProgressBar> createState() => _WaveProgressBarState();
}

class _WaveProgressBarState extends State<WaveProgressBar>
    with SingleTickerProviderStateMixin {
  bool _isDragging = false;
  double _dragValue = 0.0;
  late final AnimationController _waveController;

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3400),
    );
    if (widget.isPlaying) _waveController.repeat();
  }

  @override
  void didUpdateWidget(covariant WaveProgressBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isPlaying != widget.isPlaying) {
      if (widget.isPlaying) {
        _waveController.repeat();
      } else {
        _waveController.stop();
      }
    }
  }

  @override
  void dispose() {
    _waveController.dispose();
    super.dispose();
  }

  double get _progressRatio {
    if (widget.total.inMilliseconds == 0) return 0.0;
    if (_isDragging) return _dragValue.clamp(0.0, 1.0);
    return (widget.progress.inMilliseconds / widget.total.inMilliseconds)
        .clamp(0.0, 1.0);
  }

  double get _bufferedRatio {
    if (widget.total.inMilliseconds == 0) return 0.0;
    return (widget.buffered.inMilliseconds / widget.total.inMilliseconds)
        .clamp(0.0, 1.0);
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  Duration get _displayProgress {
    if (_isDragging) {
      final ms = (_dragValue.clamp(0.0, 1.0) * widget.total.inMilliseconds)
          .round()
          .clamp(0, widget.total.inMilliseconds);
      return Duration(milliseconds: ms);
    }
    return widget.progress;
  }

  void _handleDragStart(DragStartDetails details, BoxConstraints constraints) {
    setState(() {
      _isDragging = true;
      _dragValue =
          (details.localPosition.dx / constraints.maxWidth).clamp(0.0, 1.0);
    });
  }

  void _handleDragUpdate(
      DragUpdateDetails details, BoxConstraints constraints) {
    if (!_isDragging) return;
    setState(() {
      _dragValue =
          (details.localPosition.dx / constraints.maxWidth).clamp(0.0, 1.0);
    });
  }

  void _handleDragEnd(DragEndDetails details) {
    if (!_isDragging) return;
    final seekPosition = Duration(
      milliseconds: (_dragValue.clamp(0.0, 1.0) * widget.total.inMilliseconds)
          .round()
          .clamp(0, widget.total.inMilliseconds),
    );
    widget.onSeek?.call(seekPosition);
    setState(() => _isDragging = false);
  }

  void _handleTap(TapUpDetails details, BoxConstraints constraints) {
    final tapValue = (details.localPosition.dx / constraints.maxWidth)
        .clamp(0.0, 1.0);
    final seekPosition = Duration(
      milliseconds: (tapValue * widget.total.inMilliseconds)
          .round()
          .clamp(0, widget.total.inMilliseconds),
    );
    widget.onSeek?.call(seekPosition);
  }

  @override
  Widget build(BuildContext context) {
    final labelStyle = widget.timeLabelStyle ??
        const TextStyle(
          fontSize: 12,
          color: Default_Theme.mutedColor,
          fontWeight: FontWeight.w500,
        );

    final progressBar = LayoutBuilder(
      builder: (context, constraints) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragStart: (d) => _handleDragStart(d, constraints),
        onHorizontalDragUpdate: (d) => _handleDragUpdate(d, constraints),
        onHorizontalDragEnd: _handleDragEnd,
        onHorizontalDragCancel: () {
          if (_isDragging) setState(() => _isDragging = false);
        },
        onTapUp: (d) => _handleTap(d, constraints),
        child: Container(
          height: widget.thumbRadius * 2 + 18,
          width: double.infinity,
          color: Colors.transparent,
          alignment: Alignment.center,
          child: AnimatedBuilder(
            animation: _waveController,
            builder: (context, child) => CustomPaint(
              size: Size(constraints.maxWidth, widget.thumbRadius * 2 + 18),
              painter: _WaveProgressPainter(
                progressRatio: _progressRatio,
                bufferedRatio: _bufferedRatio,
                phase: _waveController.value * 2 * pi,
                trackHeight: widget.trackHeight,
                thumbRadius: widget.thumbRadius,
                activeColor: widget.activeColor,
                inactiveColor: widget.inactiveColor,
                bufferedColor: widget.bufferedColor,
                isDragging: _isDragging,
              ),
            ),
          ),
        ),
      ),
    );

    if (!widget.showTimeLabels) return progressBar;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(_formatDuration(_displayProgress), style: labelStyle),
            Text(_formatDuration(widget.total), style: labelStyle),
          ],
        ),
        const SizedBox(height: 8),
        progressBar,
      ],
    );
  }
}

class _WaveProgressPainter extends CustomPainter {
  final double progressRatio;
  final double bufferedRatio;
  final double phase;
  final double trackHeight;
  final double thumbRadius;
  final Color activeColor;
  final Color inactiveColor;
  final Color bufferedColor;
  final bool isDragging;

  _WaveProgressPainter({
    required this.progressRatio,
    required this.bufferedRatio,
    required this.phase,
    required this.trackHeight,
    required this.thumbRadius,
    required this.activeColor,
    required this.inactiveColor,
    required this.bufferedColor,
    required this.isDragging,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final centerY = size.height / 2;
    final thumbMinX = thumbRadius;
    final thumbMaxX = size.width - thumbRadius;
    final thumbX = thumbMinX + (thumbMaxX - thumbMinX) * progressRatio.clamp(0.0, 1.0);
    final bufferedX = size.width * bufferedRatio.clamp(0.0, 1.0);

    // 1. Inactive track — thin straight line, full width.
    final inactivePaint = Paint()
      ..color = inactiveColor
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(0, centerY), Offset(size.width, centerY), inactivePaint);

    // 2. Buffered — slightly thicker straight line.
    if (bufferedRatio > 0 && bufferedX > 0) {
      final bufferedPaint = Paint()
        ..color = bufferedColor
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(Offset(0, centerY), Offset(bufferedX, centerY), bufferedPaint);
    }

    // 3. Active portion — a flowing sine wave, animated while playing.
    if (progressRatio > 0 && thumbX > 0) {
      const wavelength = 44.0;
      final amplitude = trackHeight * 0.35;
      final wavePath = Path();
      const step = 3.0;
      for (double x = 0; x <= thumbX + step; x += step) {
        final clampedX = min(x, thumbX);
        final y = centerY +
            sin(phase + clampedX / wavelength * 2 * pi) * amplitude;
        if (clampedX == 0) {
          wavePath.moveTo(0, y);
        } else {
          wavePath.lineTo(clampedX, y);
        }
        if (clampedX >= thumbX) break;
      }
      final activePaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = trackHeight
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..shader = LinearGradient(
          colors: [
            activeColor,
            activeColor.withValues(alpha: 0.85),
          ],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
      canvas.drawPath(wavePath, activePaint);
    }

    // 4. Thumb — plain white circle, no glow.
    final thumbPaint = Paint()..color = Colors.white;
    canvas.drawCircle(Offset(thumbX, centerY), thumbRadius, thumbPaint);
    if (isDragging) {
      final ringPaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      canvas.drawCircle(
          Offset(thumbX, centerY), thumbRadius + 3, ringPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _WaveProgressPainter oldDelegate) {
    return oldDelegate.progressRatio != progressRatio ||
        oldDelegate.bufferedRatio != bufferedRatio ||
        oldDelegate.phase != phase ||
        oldDelegate.isDragging != isDragging;
  }
}
