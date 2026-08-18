// ignore_for_file: public_member_api_docs, sort_constructors_first

import 'package:music_deewane/core/theme/app_theme.dart';
import 'package:flutter/material.dart';

class SettingTile extends StatefulWidget {
  final String title;
  final String subtitle;
  final Function? onTap;
  final Widget? trailing;

  const SettingTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.trailing,
  });

  @override
  State<SettingTile> createState() => _SettingTileState();
}

class _SettingTileState extends State<SettingTile> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor:
          widget.onTap != null ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter:
          widget.onTap != null ? (_) => setState(() => _hovering = true) : null,
      onExit: widget.onTap != null
          ? (_) => setState(() => _hovering = false)
          : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        color: _hovering
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.transparent,
        child: ListTile(
          enabled: widget.onTap != null,
          title: Text(
            widget.title,
            style: const TextStyle(
                    color: Default_Theme.primaryColor1, fontSize: 16)
                .merge(Default_Theme.secondoryTextStyleMedium),
          ),
          subtitle: Text(
            widget.subtitle,
            style: TextStyle(
                    color: Default_Theme.primaryColor1.withValues(alpha: 0.5),
                    fontSize: 12)
                .merge(Default_Theme.secondoryTextStyleMedium),
          ),
          onTap: () {
            widget.onTap?.call();
          },
          dense: true,
          trailing: widget.trailing,
        ),
      ),
    );
  }
}
