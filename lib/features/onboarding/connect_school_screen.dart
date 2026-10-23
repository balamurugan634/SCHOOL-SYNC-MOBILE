import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/dev_options.dart';
import '../../core/config/env.dart';
import '../../core/design/design.dart';
import '../../core/providers.dart';
import '../../core/util/app_version.dart';
import '../../core/util/site_address.dart';
import '../../data/models/site_info.dart';
import '../auth/session.dart';
import 'connect_errors.dart';

/// First-run step: tell the app which school this is. Shown until a site is saved.
class ConnectSchoolScreen extends ConsumerStatefulWidget {
  const ConnectSchoolScreen({super.key});

  @override
  ConsumerState<ConnectSchoolScreen> createState() => _ConnectSchoolScreenState();
}

class _ConnectSchoolScreenState extends ConsumerState<ConnectSchoolScreen> {
  final _field = TextEditingController();
  final _focus = FocusNode();
  bool _loading = false;
  ConnectFailure? _failure;
  SiteAddress? _address;
  SiteInfo? _found;

  @override
  void dispose() {
    _field.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _lookup() async {
    if (_loading) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _failure = null;
    });
    SiteAddress? address;
    try {
      address = normalizeSiteInput(
        _field.text,
        baseDomain: Env.baseDomain,
        devApi: ref.read(devApiProvider),
        allowInsecure: Env.allowInsecure,
      );
      final info = await ref.read(siteRepositoryProvider).fetchInfo(address);
      if (!mounted) return;
      setState(() {
        _address = address;
        _found = info;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _failure = describeConnectFailure(e, host: address?.host);
        _loading = false;
      });
    }
  }

  Future<void> _confirm() async {
    final a = _address, f = _found;
    if (a == null || f == null) return;
    setState(() => _loading = true);
    await ref.read(sessionProvider.notifier).saveSite(a, f);
  }

  void _reset() {
    setState(() {
      _found = null;
      _address = null;
      _failure = null;
    });
    _focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final confirming = _found != null;
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, box) => SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.symmetric(horizontal: Gaps.page),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: box.maxHeight),
              child: IntrinsicHeight(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: Gaps.lg),
                    Row(
                      children: [
                        BrandTile(color: context.tokens.brandDefault, size: 32),
                        const SizedBox(width: 10),
                        Text('SchoolSync', style: context.text.titleMedium),
                        const Spacer(),
                        if (ref.watch(devApiProvider).isNotEmpty) const StatusChip('Dev API', tone: StatusTone.warning, icon: Icons.bug_report_outlined),
                      ],
                    ),
                    const SizedBox(height: Gaps.huge),
                    AnimatedSwitcher(
                      duration: Motion.base,
                      transitionBuilder: (child, anim) => FadeTransition(opacity: anim, child: child),
                      child: confirming
                          ? _Confirmation(key: const ValueKey('confirm'), info: _found!, address: _address!, loading: _loading, onConfirm: _confirm, onBack: _reset)
                          : _EntryForm(
                              key: const ValueKey('entry'),
                              controller: _field,
                              focus: _focus,
                              loading: _loading,
                              failure: _failure,
                              onSubmit: _lookup,
                              onChanged: () {
                                if (_failure != null) setState(() => _failure = null);
                              },
                            ),
                    ),
                    const Spacer(),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EntryForm extends ConsumerWidget {
  const _EntryForm({super.key, required this.controller, required this.focus, required this.loading, required this.failure, required this.onSubmit, required this.onChanged});

  final TextEditingController controller;
  final FocusNode focus;
  final bool loading;
  final ConnectFailure? failure;
  final VoidCallback onSubmit;
  final VoidCallback onChanged;

  void _help(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(Gaps.page, 4, Gaps.page, Gaps.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Where do I find my school code?', style: ctx.text.titleLarge),
            const SizedBox(height: 14),
            for (final (icon, text) in const [
              (Icons.mail_outline_rounded, 'It is in the welcome message or letter from your school.'),
              (Icons.language_rounded, 'It is also the first part of your school\'s SchoolSync website, like greenvalley in greenvalley.${Env.baseDomain}.'),
              (Icons.support_agent_rounded, 'Still stuck? Ask the school office. They can see it in their settings.'),
            ])
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(icon, color: ctx.tokens.textSecondary, size: 20),
                  const SizedBox(width: 12),
                  Expanded(child: Text(text, style: ctx.text.bodyMedium)),
                ]),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Find your school', style: context.text.headlineMedium),
        const SizedBox(height: 6),
        Text(
          'Enter your school code or website address. You only need to do this once.',
          style: context.text.bodyMedium?.copyWith(color: c.onSurfaceVariant),
        ),
        const SizedBox(height: Gaps.xxl),
        TextField(
          controller: controller,
          focusNode: focus,
          enabled: !loading,
          autocorrect: false,
          enableSuggestions: false,
          keyboardType: TextInputType.url,
          textInputAction: TextInputAction.go,
          onSubmitted: (_) => onSubmit(),
          onChanged: (_) => onChanged(),
          inputFormatters: [FilteringTextInputFormatter.deny(RegExp(r'\s'))],
          style: context.text.bodyLarge,
          decoration: InputDecoration(
            labelText: 'School code or address',
            hintText: 'greenvalley',
            prefixIcon: const Icon(Icons.school_outlined),
            suffixIcon: ValueListenableBuilder<TextEditingValue>(
              valueListenable: controller,
              builder: (_, v, _) => v.text.isEmpty
                  ? IconButton(
                      tooltip: 'Paste',
                      icon: const Icon(Icons.content_paste_rounded),
                      onPressed: () async {
                        final data = await Clipboard.getData(Clipboard.kTextPlain);
                        if (data?.text != null) controller.text = data!.text!.trim();
                      },
                    )
                  : IconButton(tooltip: 'Clear', icon: const Icon(Icons.close_rounded), onPressed: controller.clear),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            'Example: greenvalley or greenvalley.${Env.baseDomain}',
            style: context.text.bodySmall?.copyWith(color: c.onSurfaceVariant),
          ),
        ),
        AnimatedSize(
          duration: Motion.base,
          curve: Motion.emphasized,
          alignment: Alignment.topCenter,
          child: failure == null
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsets.only(top: 18),
                  child: InfoBanner(
                    title: failure!.title,
                    message: failure!.message,
                    icon: failure!.icon,
                    tone: failure!.tone == ConnectTone.warning ? BannerTone.warning : BannerTone.danger,
                  ),
                ),
        ),
        const SizedBox(height: Gaps.xl),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: controller,
          builder: (_, v, _) => PrimaryButton(
            label: 'Find my school',
            trailingIcon: Icons.arrow_forward_rounded,
            loading: loading,
            onPressed: v.text.trim().isEmpty ? null : onSubmit,
          ),
        ),
        const SizedBox(height: Gaps.xs),
        Center(child: GhostButton(label: 'Where do I find my school code?', onPressed: () => _help(context))),
        // Compiled out of release builds: `kDebugMode` is a constant false there.
        if (kDebugMode && ref.watch(developerOptionsEnabledProvider)) ...[
          const SizedBox(height: 8),
          const _DeveloperOptions(),
        ],
        const SizedBox(height: 28),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.lock_outline_rounded, size: 16, color: c.onSurfaceVariant),
            const SizedBox(width: 8),
            Expanded(child: Text('The connection is encrypted. Your school is saved on this device only.', style: context.text.bodySmall)),
          ],
        ),
      ],
    );
  }
}

/// DEBUG BUILDS ONLY. Lets a physical phone point at the laptop's API without rebuilding.
class _DeveloperOptions extends ConsumerStatefulWidget {
  const _DeveloperOptions();

  @override
  ConsumerState<_DeveloperOptions> createState() => _DeveloperOptionsState();
}

class _DeveloperOptionsState extends ConsumerState<_DeveloperOptions> {
  late final TextEditingController _c = TextEditingController(text: ref.read(devApiProvider));
  bool _open = false;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final current = ref.watch(devApiProvider);
    final typed = normalizeDevApi(_c.text);
    final invalid = typed == null;
    return AppCard(
      tone: CardTone.subtle,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: Radii.card,
            onTap: () => setState(() => _open = !_open),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Icon(Icons.developer_mode_rounded, size: 20, color: c.onSurfaceVariant),
                  const SizedBox(width: 12),
                  Expanded(child: Text('Developer options', style: context.text.titleSmall)),
                  AnimatedRotation(turns: _open ? .5 : 0, duration: Motion.base, child: const Icon(Icons.expand_more_rounded)),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: Motion.base,
            curve: Motion.emphasized,
            alignment: Alignment.topCenter,
            child: !_open
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextField(
                          controller: _c,
                          autocorrect: false,
                          enableSuggestions: false,
                          keyboardType: TextInputType.url,
                          onChanged: (v) {
                            setState(() {});
                            ref.read(devApiProvider.notifier).set(v);
                          },
                          decoration: InputDecoration(
                            labelText: 'API address',
                            hintText: 'http://192.168.1.20:4000',
                            prefixIcon: const Icon(Icons.dns_outlined),
                            errorText: invalid ? 'Enter an address like http://192.168.1.20:4000' : null,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          current.isEmpty
                              ? 'Empty: school codes are expanded to https://<code>.${Env.baseDomain}.'
                              : 'Active: the school code you type is sent as X-Tenant to $current.',
                          style: context.text.bodySmall?.copyWith(color: c.onSurfaceVariant),
                        ),
                        const SizedBox(height: 4),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () async {
                              await ref.read(devApiProvider.notifier).reset();
                              _c.text = ref.read(devApiProvider);
                              if (mounted) setState(() {});
                            },
                            child: const Text('Reset to build default'),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

/// "Is this your school?": a plain card with the school's name and address.
class _Confirmation extends ConsumerWidget {
  const _Confirmation({super.key, required this.info, required this.address, required this.loading, required this.onConfirm, required this.onBack});

  final SiteInfo info;
  final SiteAddress address;
  final bool loading;
  final VoidCallback onConfirm;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final needsUpdate = isBelowMinimum(ref.read(deviceMetaProvider).appVersion, info.minAppVersion);
    final features = [if (info.features.fees) 'Fees', if (info.features.transport) 'Transport', if (info.features.library) 'Library'];
    final devMode = ref.watch(devApiProvider).isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Is this your school?', style: context.text.headlineMedium),
        const SizedBox(height: 6),
        Text('Check the name below, then continue.', style: context.text.bodyMedium?.copyWith(color: t.textSecondary)),
        const SizedBox(height: Gaps.xl),
        AppCard(
          padding: const EdgeInsets.all(Gaps.lg),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SchoolLogo(info: info, size: 48),
              const SizedBox(width: Gaps.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(info.name, style: context.text.titleMedium),
                    const SizedBox(height: 2),
                    Text(devMode ? 'School code: ${info.code}' : address.host, style: context.text.bodySmall),
                    if (features.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(features.join('  \u00b7  '), style: context.text.bodySmall),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        if (needsUpdate) ...[
          const SizedBox(height: Gaps.md),
          const InfoBanner(
            tone: BannerTone.warning,
            title: 'App update needed',
            message: 'This school requires a newer version of the app. You can continue, then update to sign in.',
          ),
        ],
        const SizedBox(height: Gaps.xl),
        PrimaryButton(label: 'Continue to ${info.displayName}', loading: loading, onPressed: onConfirm),
        const SizedBox(height: Gaps.xs),
        Center(child: GhostButton(label: 'Not my school', onPressed: loading ? null : onBack)),
      ],
    );
  }
}
