import 'package:flutter/material.dart';
import 'package:music_deewane/core/theme/app_theme.dart';
import 'package:iconsx_plus/iconsx_plus.dart';

class LikeBtnWidget extends StatefulWidget {
  final bool isLiked;
  final bool isPlaying;
  final double iconSize;
  final VoidCallback? onLiked;
  final VoidCallback? onDisliked;
  const LikeBtnWidget({
    super.key,
    this.isLiked = false,
    this.isPlaying = false,
    this.iconSize = 50,
    this.onLiked,
    this.onDisliked,
  });

  @override
  State<LikeBtnWidget> createState() => _LikeBtnWidgetState();
}

class _LikeBtnWidgetState extends State<LikeBtnWidget> {
  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: IconButton(
        onPressed: () {
          if (widget.isLiked) {
            widget.onDisliked?.call();
          } else {
            widget.onLiked?.call();
          }
        },
        icon: Icon(
          widget.isLiked ? AntDesign.heart_fill : AntDesign.heart_outline,
          color: widget.isLiked
              ? Default_Theme.accentColor2
              : Default_Theme.mutedColor,
          size: widget.iconSize,
        ),
      ),
    );
  }
}
