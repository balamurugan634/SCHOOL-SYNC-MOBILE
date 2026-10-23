import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../data/models/site_info.dart';
import 'theme.dart';

/// The school's logo, or a monogram in a brand-tint tile when it has none.
class SchoolLogo extends StatelessWidget {
  const SchoolLogo({super.key, required this.info, this.size = 48});

  final SiteInfo? info;
  final double size;

  static String monogram(String name) {
    final words = name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) return 'S';
    if (words.length == 1) return words.first[0].toUpperCase();
    return (words[0][0] + words[1][0]).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final i = info;
    final radius = BorderRadius.circular(size * .2);
    final url = i?.logoUrl;
    final hasUrl = url != null && url.isNotEmpty && Uri.tryParse(url)?.hasScheme == true;

    Widget monogramTile() => Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(borderRadius: radius, color: t.brand.tint, border: Border.all(color: t.border)),
      child: Text(monogram(i?.displayName ?? 'S'), style: context.text.titleMedium?.copyWith(fontSize: size * .36, color: t.brand.solid)),
    );

    if (!hasUrl) return monogramTile();
    return ClipRRect(
      borderRadius: radius,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: Colors.white, border: Border.all(color: t.border), borderRadius: radius),
        padding: EdgeInsets.all(size * .08),
        child: CachedNetworkImage(imageUrl: url, fit: BoxFit.contain, errorWidget: (_, _, _) => monogramTile(), placeholder: (_, _) => monogramTile()),
      ),
    );
  }
}
