import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design/design.dart';
import '../../core/network/app_exception.dart';
import '../../data/models/profile_details.dart';
import '../../data/repositories/profile_repository.dart';
import '../auth/session.dart';
import '../security/secure_scope.dart';

final profileDetailsProvider = FutureProvider<ProfileDetails>((ref) => ref.watch(profileRepositoryProvider).details());

/// Contact details, address and emergency contacts (what the school holds), with phone/address edits and photo.
class ProfileDetailsScreen extends ConsumerStatefulWidget {
  const ProfileDetailsScreen({super.key});

  @override
  ConsumerState<ProfileDetailsScreen> createState() => _ProfileDetailsScreenState();
}

class _ProfileDetailsScreenState extends ConsumerState<ProfileDetailsScreen> {
  bool _busy = false;

  Future<void> _photo() async {
    final f = await FilePicker.pickFile(type: FileType.image);
    final path = f?.path;
    if (path == null) return;
    setState(() => _busy = true);
    try {
      await ref.read(profileRepositoryProvider).setAvatar(path);
      ref.invalidate(profileDetailsProvider);
      await ref.read(sessionProvider.notifier).refreshMe();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Photo updated.')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppException.from(e).displayMessage)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _editContact(ProfileDetails d) async {
    final saved = await showModalBottomSheet<bool>(context: context, isScrollControlled: true, useSafeArea: true, builder: (_) => _ContactForm(d: d));
    if (saved == true) ref.invalidate(profileDetailsProvider);
  }

  @override
  Widget build(BuildContext context) {
    final v = ref.watch(profileDetailsProvider);
    final me = ref.watch(sessionProvider.select((s) => s.me));
    final readOnly = ref.watch(sessionProvider.select((s) => s.siteInfo?.readOnly ?? false));
    return SecureScope(
      child: Scaffold(
        appBar: AppBar(title: const Text('My details')),
        body: AsyncBody<ProfileDetails>(
          value: v,
          onRetry: () => ref.invalidate(profileDetailsProvider),
          data: (d) => RefreshScroll(
            onRefresh: () async => ref.invalidate(profileDetailsProvider),
            children: [
              AppCard(
                child: Row(
                  children: [
                    UserAvatar(name: d.displayName, url: d.avatarUrl ?? me?.avatarUrl, size: 64, ringColor: me == null ? null : context.tokens.roleTint(me.experience)),
                    const SizedBox(width: Gaps.lg),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(d.displayName, style: context.text.titleLarge), Text(d.username.contains('@') ? d.username : '@${d.username}', style: context.text.bodySmall)])),
                  ],
                ),
              ),
              if (!readOnly) Padding(padding: const EdgeInsets.only(top: Gaps.md), child: SecondaryButton(label: _busy ? 'Uploading' : 'Change photo', icon: Icons.photo_camera_outlined, onPressed: _busy ? null : _photo)),
              GroupLabel('Contact', trailing: readOnly ? null : TextButton(onPressed: () => _editContact(d), child: const Text('Edit'))),
              AppCard(child: Column(children: [FactRow('Phone', d.phone ?? 'Not set'), FactRow('Email', d.email ?? 'Not set'), FactRow('Address', d.address ?? 'Not set')])),
              if (d.emergency.any((c) => c.contacts.isNotEmpty)) ...[
                const GroupLabel('Emergency contacts'),
                for (final c in d.emergency.where((c) => c.contacts.isNotEmpty)) ...[
                  if (d.emergency.length > 1) Padding(padding: const EdgeInsets.only(bottom: 6, top: 4), child: Text(c.studentName, style: context.text.labelMedium?.copyWith(color: context.tokens.textSecondary))),
                  RowGroup(children: [for (final e in c.contacts) ListRow(title: e.name, subtitle: [if (e.relationship != null) e.relationship!, e.phone].join('  ·  '), leading: Icons.call_outlined, chevron: false, dense: true)]),
                  const SizedBox(height: Gaps.md),
                ],
              ],
              const SizedBox(height: Gaps.md),
              Text('To change a name, date of birth or medical details, ask the school office. They are updated through a correction request.', style: context.text.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}

class _ContactForm extends ConsumerStatefulWidget {
  const _ContactForm({required this.d});
  final ProfileDetails d;

  @override
  ConsumerState<_ContactForm> createState() => _ContactFormState();
}

class _ContactFormState extends ConsumerState<_ContactForm> {
  late final _phone = TextEditingController(text: widget.d.phone);
  final _line1 = TextEditingController();
  final _city = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _phone.dispose();
    _line1.dispose();
    _city.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final address = {if (_line1.text.trim().isNotEmpty) 'line1': _line1.text.trim(), if (_city.text.trim().isNotEmpty) 'city': _city.text.trim()};
      await ref.read(profileRepositoryProvider).update(phone: _phone.text, address: address.isEmpty ? null : address);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = AppException.from(e).displayMessage;
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(Gaps.page, 0, Gaps.page, MediaQuery.viewInsetsOf(context).bottom + Gaps.lg),
    child: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Edit contact details', style: context.text.headlineSmall),
          const SizedBox(height: Gaps.lg),
          TextField(controller: _phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone')),
          const SizedBox(height: Gaps.md),
          TextField(controller: _line1, textCapitalization: TextCapitalization.words, decoration: InputDecoration(labelText: 'Street address', helperText: widget.d.address == null ? null : 'Now: ${widget.d.address}')),
          const SizedBox(height: Gaps.md),
          TextField(controller: _city, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'City')),
          if (_error != null) ...[const SizedBox(height: Gaps.md), InfoBanner(tone: BannerTone.danger, message: _error!)],
          const SizedBox(height: Gaps.lg),
          PrimaryButton(label: 'Save', loading: _saving, onPressed: _save),
        ],
      ),
    ),
  );
}
