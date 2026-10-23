import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/design/design.dart';
import '../../core/providers.dart';
import '../../core/push/push_service.dart';
import '../../core/security/platform_bridge.dart';
import '../../data/models/me.dart';
import '../../router/routes.dart';
import '../auth/session.dart';
import '../security/app_lock.dart';
import '../security/secure_scope.dart';

/// Account, security, notifications, appearance and school. Opened from the
/// Profile tab (students) or More (everyone else).
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key, this.embedded = false, this.header});

  /// Rendered inside the Profile tab (no back button, tab-style title).
  final bool embedded;

  /// Extra content shown under the profile card (the student Profile tab puts "My school" links here).
  final Widget? header;

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool? _osNotifications;
  int _taps = 0;

  @override
  void initState() {
    super.initState();
    _refreshPermission();
  }

  Future<void> _refreshPermission() async {
    final granted = await ref.read(pushServiceProvider).isPermissionGranted();
    if (mounted) setState(() => _osNotifications = granted);
  }

  Future<void> _toggleNotifications(bool on) async {
    final push = ref.read(pushServiceProvider);
    if (!on) {
      await push.disable();
      if (mounted) setState(() {});
      return;
    }
    final granted = await push.enable();
    await _refreshPermission();
    if (!granted && mounted) {
      final messenger = ScaffoldMessenger.of(context);
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Notifications are blocked for SchoolSync in system settings.'),
          action: SnackBarAction(label: 'Open settings', onPressed: PlatformBridge.openNotificationSettings),
        ),
      );
    }
    if (mounted) setState(() {});
  }

  Future<void> _toggleLock(bool on) async {
    final lock = ref.read(appLockProvider.notifier);
    final ok = on ? await lock.enable() : await lock.disable();
    if (!ok && on && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Set up a screen lock or fingerprint in your phone settings first.')));
    }
  }

  Future<void> _confirmLogout() async {
    final ok = await _confirm(
      title: 'Sign out?',
      message: 'You will need your password to sign back in on this device.',
      action: 'Sign out',
    );
    if (ok == true) await ref.read(sessionProvider.notifier).logout();
  }

  Future<void> _confirmChangeSchool() async {
    final school = ref.read(sessionProvider).siteInfo?.displayName ?? 'this school';
    final ok = await _confirm(
      title: 'Change school?',
      message: 'This signs you out of $school and removes its data from this device. You can connect to another school next.',
      action: 'Change school',
      destructive: true,
    );
    if (ok == true) await ref.read(sessionProvider.notifier).changeSchool();
  }

  Future<bool?> _confirm({required String title, required String message, required String action, bool destructive = false}) => showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      icon: Icon(destructive ? Icons.swap_horiz_rounded : Icons.logout_rounded),
      title: Text(title, textAlign: TextAlign.center),
      content: Text(message, textAlign: TextAlign.center),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: FilledButton.styleFrom(minimumSize: const Size(120, 48), backgroundColor: destructive ? ctx.colors.error : null, foregroundColor: destructive ? ctx.colors.onError : null),
          child: Text(action),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);
    final me = session.me;
    if (me == null) return const SizedBox.shrink();
    final info = session.siteInfo;
    final lock = ref.watch(appLockProvider);
    final push = ref.watch(pushServiceProvider);
    final pushWanted = ref.watch(prefsProvider).pushEnabled;
    final themeMode = ref.watch(themeModeProvider);
    final device = ref.watch(deviceMetaProvider);

    final body = ListView(
      padding: EdgeInsets.fromLTRB(Gaps.page, widget.embedded ? MediaQuery.paddingOf(context).top + 18 : 8, Gaps.page, Gaps.huge),
      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      children: [
        if (widget.embedded) ...[
          Text('Profile', style: context.text.headlineMedium),
          const SizedBox(height: Gaps.lg),
        ],
        _ProfileCard(me: me),
        if (widget.header != null) widget.header!,
        const _Label('Security'),
        _Group(children: [
          _Tile(icon: Icons.password_rounded, title: 'Change password', onTap: () => context.push(Routes.changePassword)),
          _Tile(icon: Icons.devices_rounded, title: 'Signed-in devices', subtitle: 'See where you are signed in and sign out remotely', onTap: () => context.push(Routes.sessions)),
          if (lock.supported)
            SwitchListTile(
              secondary: _IconBox(lock.kindLabel == 'Face unlock' ? Icons.face_unlock_outlined : Icons.fingerprint_rounded),
              title: Text('App lock (${lock.kindLabel})'),
              subtitle: const Text('Ask to unlock when you come back to the app'),
              value: lock.enabled,
              onChanged: _toggleLock,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            ),
          if (lock.supported && lock.enabled)
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              leading: const _IconBox(Icons.timer_outlined),
              title: const Text('Lock after'),
              trailing: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  value: lock.minutes,
                  borderRadius: BorderRadius.circular(16),
                  items: const [
                    DropdownMenuItem(value: 0, child: Text('Immediately')),
                    DropdownMenuItem(value: 1, child: Text('1 minute')),
                    DropdownMenuItem(value: 5, child: Text('5 minutes')),
                    DropdownMenuItem(value: 15, child: Text('15 minutes')),
                  ],
                  onChanged: (v) => v == null ? null : ref.read(appLockProvider.notifier).setMinutes(v),
                ),
              ),
            ),
        ]),
        const _Label('Notifications'),
        _Group(children: [
          SwitchListTile(
            secondary: const _IconBox(Icons.notifications_active_outlined),
            title: const Text('Push notifications'),
            subtitle: Text(
              !push.available
                  ? 'Push delivery is not set up in this build.'
                  : (_osNotifications == false && pushWanted ? 'Blocked in system settings.' : 'Attendance, homework, fees and announcements.'),
            ),
            value: pushWanted && (_osNotifications ?? false),
            onChanged: _toggleNotifications,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
          ),
          const _Tile(icon: Icons.tune_rounded, title: 'System notification settings', onTap: PlatformBridge.openNotificationSettings),
        ]),
        const _Label('Appearance'),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Theme', style: context.text.titleSmall),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: SegmentedButton<ThemeMode>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(value: ThemeMode.system, icon: Icon(Icons.brightness_auto_rounded), label: Text('System')),
                    ButtonSegment(value: ThemeMode.light, icon: Icon(Icons.light_mode_rounded), label: Text('Light')),
                    ButtonSegment(value: ThemeMode.dark, icon: Icon(Icons.dark_mode_rounded), label: Text('Dark')),
                  ],
                  selected: {themeMode},
                  onSelectionChanged: (s) => ref.read(themeModeProvider.notifier).set(s.first),
                ),
              ),
            ],
          ),
        ),
        const _Label('School'),
        AppCard(
          child: Row(
            children: [
              SchoolLogo(info: info, size: 44),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(info?.name ?? 'Your school', style: context.text.titleSmall, maxLines: 2, overflow: TextOverflow.ellipsis),
                    Text(session.site?.host ?? '', style: context.text.bodySmall?.copyWith(color: context.colors.onSurfaceVariant)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: Gaps.md),
        _Group(children: [
          _Tile(icon: Icons.replay_circle_filled_outlined, title: 'Replay welcome tour', onTap: () => ref.read(sessionProvider.notifier).replayTour()),
          _Tile(icon: Icons.swap_horiz_rounded, title: 'Change school', subtitle: 'Signs you out and removes this school from the device', onTap: _confirmChangeSchool),
        ]),
        const SizedBox(height: Gaps.xl),
        OutlinedButton.icon(
          onPressed: _confirmLogout,
          icon: const Icon(Icons.logout_rounded),
          label: const Text('Sign out'),
          style: OutlinedButton.styleFrom(foregroundColor: context.colors.error, side: BorderSide(color: context.tokens.border)),
        ),
        const SizedBox(height: Gaps.xl),
        GestureDetector(
          onTap: () {
            if (kDebugMode && ++_taps >= 5) {
              _taps = 0;
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Debug build · API ${session.site?.baseUrl}')));
            }
          },
          child: Center(
            child: Text(
              'SchoolSync ${device.appVersion} (${device.buildNumber})\nAPI ${info?.apiVersion ?? '-'} · ${device.platform}',
              textAlign: TextAlign.center,
              style: context.text.bodySmall?.copyWith(color: context.colors.onSurfaceVariant),
            ),
          ),
        ),
        Center(
          child: TextButton(
            onPressed: () => showLicensePage(context: context, applicationName: 'SchoolSync', applicationVersion: device.appVersion),
            child: const Text('Open source licences'),
          ),
        ),
        Center(
          child: TextButton(
            onPressed: () => launchUrl(Uri.parse('https://schoolsync.app/privacy'), mode: LaunchMode.externalApplication),
            child: const Text('Privacy policy'),
          ),
        ),
      ],
    );

    return SecureScope(
      child: widget.embedded
          ? body
          : Scaffold(appBar: AppBar(title: const Text('Settings')), body: body),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.me});
  final Me me;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AppCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        children: [
          Row(
            children: [
              UserAvatar(name: me.displayName, url: me.avatarUrl, size: 60, ringColor: context.tokens.roleTint(me.experience)),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(me.displayName, style: context.text.titleLarge, maxLines: 2, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text(me.username.contains('@') ? me.username : '@${me.username}', style: context.text.bodyMedium?.copyWith(color: c.onSurfaceVariant)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              RoleChip(label: me.experience.label, tint: context.tokens.roleTint(me.experience)),
              for (final r in me.roles) StatusChip(r.split('_').map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}').join(' ')),
            ],
          ),
          if (me.email != null || me.phone != null) ...[
            const SizedBox(height: 14),
            const Divider(),
            const SizedBox(height: 10),
            if (me.email != null) _Info(Icons.mail_outline_rounded, me.email!),
            if (me.phone != null) _Info(Icons.phone_outlined, me.phone!),
          ],
        ],
      ),
    );
  }
}

class _Info extends StatelessWidget {
  const _Info(this.icon, this.text);
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(children: [Icon(icon, size: 18, color: context.colors.onSurfaceVariant), const SizedBox(width: 10), Expanded(child: Text(text, style: context.text.bodyMedium))]),
  );
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, Gaps.xl, 0, Gaps.sm),
    child: Text(text, style: context.text.labelMedium?.copyWith(color: context.tokens.textSecondary)),
  );
}

class _Group extends StatelessWidget {
  const _Group({required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => AppCard(
    padding: EdgeInsets.zero,
    child: Column(children: [for (final (i, w) in children.indexed) ...[if (i > 0) const Divider(indent: 56), w]]),
  );
}

class _IconBox extends StatelessWidget {
  const _IconBox(this.icon);
  final IconData icon;
  @override
  Widget build(BuildContext context) => Icon(icon, size: 22, color: context.tokens.textSecondary);
}

class _Tile extends StatelessWidget {
  const _Tile({required this.icon, required this.title, this.subtitle, this.onTap});
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => ListTile(
    onTap: onTap,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
    leading: _IconBox(icon),
    title: Text(title),
    subtitle: subtitle == null ? null : Text(subtitle!),
    trailing: const Icon(Icons.chevron_right_rounded),
  );
}
