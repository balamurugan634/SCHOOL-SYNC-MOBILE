import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'theme.dart';

/// Initials on a neutral circle (a photo when there is one). [ringColor] draws the role-tint ring
/// and is meant for the signed-in user only.
class UserAvatar extends StatelessWidget {
  const UserAvatar({super.key, required this.name, this.url, this.size = 40, this.ringColor});

  final String name;
  final String? url;
  final double size;
  final Color? ringColor;

  static String initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    return (parts.first.characters.first + parts.last.characters.first).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final inner = ringColor == null ? size : size - 6;
    Widget fallback() => Container(
      color: t.sunken,
      alignment: Alignment.center,
      child: Text(initials(name), style: context.text.labelMedium?.copyWith(color: t.textSecondary, fontSize: inner * .36, fontWeight: FontWeight.w600, height: 1)),
    );
    final hasUrl = url != null && url!.isNotEmpty && Uri.tryParse(url!)?.hasScheme == true;
    final avatar = ClipOval(
      child: SizedBox(
        width: inner,
        height: inner,
        child: hasUrl ? CachedNetworkImage(imageUrl: url!, fit: BoxFit.cover, errorWidget: (_, _, _) => fallback(), placeholder: (_, _) => fallback()) : fallback(),
      ),
    );
    return Semantics(
      label: name,
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: ringColor ?? t.border, width: ringColor == null ? 1 : 2)),
        child: avatar,
      ),
    );
  }
}
