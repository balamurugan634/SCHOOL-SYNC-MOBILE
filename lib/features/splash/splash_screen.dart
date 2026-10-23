import 'package:flutter/material.dart';

import '../../core/design/design.dart';

/// The logo on the surface colour. Shown while storage is read and the saved session is
/// checked; the router leaves it as soon as the session is ready.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Scaffold(
      backgroundColor: t.bg,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            BrandTile(color: t.brandDefault, size: 72),
            const SizedBox(height: Gaps.lg),
            Text('SchoolSync', style: context.text.headlineSmall),
          ],
        ).reveal(),
      ),
    );
  }
}
