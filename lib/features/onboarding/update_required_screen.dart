import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/config/env.dart';
import '../../core/design/design.dart';
import '../../core/providers.dart';
import '../auth/session.dart';

/// The school's API needs a newer app than this one.
class UpdateRequiredScreen extends ConsumerWidget {
  const UpdateRequiredScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final info = ref.watch(sessionProvider.select((s) => s.siteInfo));
    final version = ref.watch(deviceMetaProvider).appVersion;
    final c = context.colors;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(Gaps.page),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Spacer(),
              Icon(Icons.system_update_outlined, size: 32, color: c.onSurfaceVariant),
              const SizedBox(height: Gaps.lg),
              Text('Please update the app', style: context.text.headlineMedium),
              const SizedBox(height: 6),
              Text(
                '${info?.displayName ?? 'Your school'} now needs version ${info?.minAppVersion ?? 'newer'} or later. You are on $version.',
                style: context.text.bodyMedium?.copyWith(color: c.onSurfaceVariant),
              ),
              const Spacer(),
              PrimaryButton(label: 'Update now', onPressed: () => launchUrl(Uri.parse(Env.storeUrl), mode: LaunchMode.externalApplication)),
              const SizedBox(height: Gaps.xs),
              Center(child: GhostButton(label: 'Check again', onPressed: () => ref.read(sessionProvider.notifier).refreshSiteInfo())),
              Center(child: GhostButton(label: 'Change school', onPressed: () => ref.read(sessionProvider.notifier).changeSchool())),
            ],
          ),
        ),
      ),
    );
  }
}
