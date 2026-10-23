import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/design.dart';
import '../../../core/network/app_exception.dart';
import '../../../core/util/format.dart';
import '../../../data/json.dart';
import '../../../data/models/staff/comms.dart';
import '../../../data/repositories/staff/comms_repository.dart';
import '../workspace.dart';
import 'announcement_logic.dart';
import 'announcement_providers.dart';
import 'audience_picker.dart';

enum _Submit { draft, publish, schedule }

/// Write or edit an announcement. Teachers can only address the classes they lead or teach; school-scope authors
/// can also address everyone, a user type or a grade. A draft is editable; a published announcement can only change
/// its expiry.
class AnnouncementFormScreen extends ConsumerStatefulWidget {
  const AnnouncementFormScreen({super.key, this.announcementId});
  final String? announcementId;

  @override
  ConsumerState<AnnouncementFormScreen> createState() => _AnnouncementFormScreenState();
}

class _AnnouncementFormScreenState extends ConsumerState<AnnouncementFormScreen> {
  final _title = TextEditingController();
  final _body = TextEditingController();
  String _priority = 'normal';
  List<AudienceTarget> _audience = const [];
  bool _requiresAck = false;
  List<Attachment> _attachments = const [];
  DateTime? _publishAt;
  DateTime? _expiresAt;

  /// The server id once saved (so a retry after a failed publish never creates a duplicate).
  String? _id;
  String _loadedState = 'draft';
  bool _loading = false;
  Object? _loadError;
  bool _dirty = false;
  bool _busy = false;
  bool _createdThisSession = false;
  String? _bannerError;
  Map<String, String> _errors = const {};

  bool get _editing => _id != null;
  bool get _wasScheduled => _loadedState == 'scheduled';

  /// Published announcements accept only a new expiry.
  bool get _expiryOnly => _loadedState == 'published';
  bool get _locked => _loadedState == 'archived' || _loadedState == 'expired';

  @override
  void initState() {
    super.initState();
    _id = widget.announcementId;
    _title.addListener(_touch);
    _body.addListener(_touch);
    if (_id != null) _load();
  }

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  void _touch() {
    if (!_dirty && !_loading) setState(() => _dirty = true);
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final a = await ref.read(commsRepositoryProvider).announcement(_id!);
      if (!mounted) return;
      setState(() {
        _title.text = a.title;
        _body.text = a.body;
        _priority = a.priority;
        _audience = [for (final t in a.audience) t.type == 'all' ? everyoneTarget : t];
        _requiresAck = a.requiresAck;
        _attachments = a.attachments;
        _publishAt = a.isScheduled ? a.publishAt : null;
        _expiresAt = a.expiresAt;
        _loadedState = a.state;
        _loading = false;
        _dirty = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadError = e;
        });
      }
    }
  }

  void _mark(VoidCallback change) => setState(() {
    change();
    _dirty = true;
  });

  AudiencePolicy get _policy => AudiencePolicy.forScope(ref.read(staffMeProvider)?.scopeOf('announcements:create'));

  AnnouncementDraft _draft({required bool withSchedule}) => AnnouncementDraft(title: _title.text, body: _body.text, priority: _priority, audience: _audience, requiresAck: _requiresAck, attachments: _attachments, publishAt: withSchedule ? _publishAt : null, expiresAt: _expiresAt);

  Future<void> _pickPublishAt() async {
    final at = await pickDayTime(context, initial: _publishAt ?? DateTime.now().add(const Duration(hours: 2)), firstDate: DateTime.now(), help: 'Publish on');
    if (at != null) _mark(() => _publishAt = at);
  }

  Future<void> _pickExpiry() async {
    final at = await pickDayTime(context, initial: _expiresAt ?? (_publishAt ?? DateTime.now()).add(const Duration(days: 7)), firstDate: DateTime.now(), help: 'Expires on');
    if (at != null) _mark(() => _expiresAt = at);
  }

  Future<void> _submit(_Submit action) async {
    setState(() => _bannerError = null);
    if (_expiryOnly) return _saveExpiry();

    final errors = validateAnnouncementForm(
      title: _title.text,
      body: _body.text,
      audience: _audience,
      policy: _policy,
      publishAt: action == _Submit.schedule ? _publishAt : null,
      expiresAt: _expiresAt,
    );
    if (action == _Submit.schedule && _publishAt == null) errors['publishAt'] = 'Pick when to publish.';
    setState(() => _errors = errors);
    if (errors.isNotEmpty) return;

    if (action != _Submit.draft) {
      final audience = describeAudience(_audience);
      final ok = await confirmAction(
        context,
        title: action == _Submit.publish ? 'Publish now?' : 'Schedule this announcement?',
        message: action == _Submit.publish
            ? '"${_title.text.trim()}" will be sent to $audience right away, and they will be notified. You will not be able to edit the message afterwards.'
            : '"${_title.text.trim()}" will be sent to $audience on ${fmtDateTime(_publishAt!)}. Until then you can still edit or unschedule it.',
        confirmLabel: action == _Submit.publish ? 'Publish' : 'Schedule',
      );
      if (!ok || !mounted) return;
    }

    setState(() => _busy = true);
    final repo = ref.read(commsRepositoryProvider);
    final done = await runWrite(
      context,
      ref,
      () async {
        // Saved first, so a failure in the second step leaves a draft rather than nothing.
        if (_id == null) {
          final created = await repo.createAnnouncement(_draft(withSchedule: action == _Submit.schedule));
          _id = created.id;
          _createdThisSession = action != _Submit.draft;
        } else {
          await repo.updateDraftAnnouncement(_id!, _draft(withSchedule: false));
          if (action == _Submit.schedule) await repo.scheduleAnnouncement(_id!, _publishAt!);
          if (action == _Submit.draft && _wasScheduled) await repo.unscheduleAnnouncement(_id!);
        }
        if (action == _Submit.publish) await repo.publishAnnouncement(_id!);
      },
      success: switch (action) {
        _Submit.draft => 'Saved as a draft.',
        _Submit.publish => 'Published to ${describeAudience(_audience)}.',
        _Submit.schedule => 'Scheduled for ${fmtDateTime(_publishAt!)}.',
      },
      onError: _handleError,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (done) _finish();
  }

  Future<void> _saveExpiry() async {
    final problems = validateSchedule(expiresAt: _expiresAt);
    setState(() => _errors = problems);
    if (problems.isNotEmpty) return;
    setState(() => _busy = true);
    final done = await runWrite(context, ref, () => ref.read(commsRepositoryProvider).setAnnouncementExpiry(_id!, _expiresAt), success: _expiresAt == null ? 'The expiry was removed.' : 'The expiry was updated.', onError: _handleError);
    if (!mounted) return;
    setState(() => _busy = false);
    if (done) _finish();
  }

  void _handleError(Object e) {
    final ex = AppException.from(e);
    final fields = <String, String>{};
    switch (ex.code) {
      case 'AUDIENCE_NOT_ALLOWED' || 'AUDIENCE_EMPTY' || 'AUDIENCE_INVALID':
        fields['audience'] = friendlyError(e);
      case 'SCHEDULED_AT_IN_PAST' || 'PUBLISH_AT_IN_PAST':
        fields['publishAt'] = 'Pick a publish time in the future.';
      case 'EXPIRES_BEFORE_PUBLISH' || 'EXPIRES_IN_PAST':
        fields['expiresAt'] = ex.displayMessage;
    }
    if (ex.kind == ErrorKind.validation) {
      for (final fe in ex.errors) {
        final key = fe.path.split('.').first;
        if (const {'title', 'body', 'audience', 'publishAt', 'expiresAt'}.contains(key)) fields[key] = fe.message;
      }
    }
    final savedNote = _createdThisSession ? ' Your text was saved as a draft, so nothing is lost.' : '';
    setState(() {
      _errors = {..._errors, ...fields};
      _bannerError = fields.isEmpty ? '${friendlyError(e)}$savedNote' : null;
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${friendlyError(e)}$savedNote'), duration: const Duration(seconds: 6)));
  }

  void _finish() {
    _dirty = false;
    ref.invalidate(managedAnnouncementsProvider);
    if (_id != null) {
      ref.invalidate(announcementDetailProvider(_id!));
      ref.invalidate(announcementStatsProvider(_id!));
    }
    if (mounted) Navigator.of(context).maybePop();
  }

  Future<bool> _confirmDiscard() => confirmAction(context, title: 'Discard your changes?', message: 'What you have written here has not been saved.', confirmLabel: 'Discard', destructive: true);

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final readOnly = ref.watch(readOnlyProvider);
    final title = _editing ? (_expiryOnly ? 'Change expiry' : 'Edit announcement') : 'New announcement';
    final body = _loading
        ? const SingleChildScrollView(physics: NeverScrollableScrollPhysics(), child: Padding(padding: EdgeInsets.only(top: Gaps.sm), child: SkeletonList(count: 4)))
        : _loadError != null
        ? ErrorState(error: _loadError!, onRetry: _load)
        : _locked
        ? EmptyState(icon: Icons.lock_outline_rounded, title: 'This announcement can no longer be edited', message: friendlyError(const AppException(kind: ErrorKind.conflict, code: 'ANNOUNCEMENT_NOT_EDITABLE', message: 'Not editable')))
        : _form(context, t, readOnly);

    return PopScope(
      canPop: !_dirty || _busy,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final nav = Navigator.of(context);
        if (await _confirmDiscard()) {
          _dirty = false;
          nav.pop();
        }
      },
      child: StaffFrame(title: title, body: body),
    );
  }

  Widget _form(BuildContext context, SchoolSyncTheme t, bool readOnly) {
    final fixed = _expiryOnly || _busy;
    final stackButtons = MediaQuery.textScalerOf(context).scale(14) > 20;
    final primaryLabel = _expiryOnly ? 'Save expiry' : (_publishAt != null ? 'Schedule' : 'Publish now');
    final primaryAction = _expiryOnly ? _Submit.draft : (_publishAt != null ? _Submit.schedule : _Submit.publish);

    final draftBtn = SecondaryButton(label: _wasScheduled ? 'Back to draft' : 'Save draft', onPressed: _busy || readOnly ? null : () => _submit(_Submit.draft));
    final mainBtn = PrimaryButton(label: primaryLabel, loading: _busy, onPressed: readOnly ? null : () => _submit(primaryAction));

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(Gaps.page, Gaps.md, Gaps.page, Gaps.xl),
            children: [
              const ReadOnlyBanner(),
              if (_expiryOnly) const Padding(padding: EdgeInsets.only(bottom: Gaps.md), child: InfoBanner(message: 'This announcement is already published, so only its expiry can change. To change the message, archive it and write a new one.')),
              if (_bannerError != null) Padding(padding: const EdgeInsets.only(bottom: Gaps.md), child: InfoBanner(tone: BannerTone.danger, message: _bannerError!)),
              TextField(
                controller: _title,
                enabled: !fixed,
                maxLength: 200,
                textInputAction: TextInputAction.next,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(labelText: 'Title', errorText: _errors['title']),
              ),
              const SizedBox(height: Gaps.md),
              TextField(
                controller: _body,
                enabled: !fixed,
                minLines: 5,
                maxLines: 12,
                maxLength: 10000,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(labelText: 'Message', alignLabelWithHint: true, errorText: _errors['body']),
              ),
              const SizedBox(height: Gaps.md),
              Text('Priority', style: context.text.titleMedium),
              const SizedBox(height: Gaps.sm),
              Wrap(
                spacing: Gaps.sm,
                runSpacing: Gaps.xs,
                children: [
                  for (final p in const [('normal', 'Normal', Icons.notes_rounded), ('important', 'Important', Icons.label_important_outline_rounded), ('urgent', 'Urgent', Icons.priority_high_rounded)])
                    ChoiceChip(avatar: Icon(p.$3, size: 18), label: Text(p.$2), selected: _priority == p.$1, onSelected: fixed ? null : (_) => _mark(() => _priority = p.$1)),
                ],
              ),
              const SizedBox(height: Gaps.lg),
              AudiencePicker(policy: _policy, selected: _audience, enabled: !fixed, error: _errors['audience'], onChanged: (a) => _mark(() => _audience = a)),
              const SizedBox(height: Gaps.md),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Ask people to acknowledge'),
                subtitle: const Text('Recipients tap "I have read this" and you see who has.'),
                value: _requiresAck,
                onChanged: fixed ? null : (v) => _mark(() => _requiresAck = v),
              ),
              const SizedBox(height: Gaps.sm),
              AttachmentEditor(purpose: 'announcement', attachments: _attachments, enabled: !fixed, onChanged: (a) => _mark(() => _attachments = a)),
              const SizedBox(height: Gaps.lg),
              if (!_expiryOnly) ...[
                _TimeField(
                  label: 'Publish later (optional)',
                  value: _publishAt,
                  emptyText: 'Not scheduled. Publish now, or save as a draft.',
                  error: _errors['publishAt'],
                  helper: _publishAt == null ? null : 'Tap Schedule to send then. "Save draft" keeps it unscheduled.',
                  enabled: !_busy,
                  onPick: _pickPublishAt,
                  onClear: () => _mark(() => _publishAt = null),
                ),
                const SizedBox(height: Gaps.md),
              ],
              _TimeField(label: 'Expires (optional)', value: _expiresAt, emptyText: 'Stays visible until archived.', error: _errors['expiresAt'], enabled: !_busy, onPick: _pickExpiry, onClear: () => _mark(() => _expiresAt = null)),
            ],
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(color: t.surface, border: Border(top: BorderSide(color: t.border))),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(Gaps.page, Gaps.md, Gaps.page, Gaps.md),
              child: _expiryOnly
                  ? mainBtn
                  : stackButtons
                  ? Column(mainAxisSize: MainAxisSize.min, children: [mainBtn, const SizedBox(height: Gaps.sm), draftBtn])
                  : Row(children: [Expanded(child: draftBtn), const SizedBox(width: Gaps.md), Expanded(child: mainBtn)]),
            ),
          ),
        ),
      ],
    );
  }
}

class _TimeField extends StatelessWidget {
  const _TimeField({required this.label, required this.value, required this.emptyText, required this.onPick, required this.onClear, this.error, this.helper, this.enabled = true});
  final String label;
  final DateTime? value;
  final String emptyText;
  final String? error;
  final String? helper;
  final bool enabled;
  final VoidCallback onPick;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: context.text.titleMedium),
        const SizedBox(height: Gaps.xs),
        Row(
          children: [
            Expanded(child: Text(value == null ? emptyText : '${fmtDay(value!)}, ${fmtTime(value!)}', style: context.text.bodyMedium?.copyWith(color: value == null ? t.textSecondary : t.text))),
            TextButton.icon(onPressed: enabled ? onPick : null, icon: Icon(value == null ? Icons.event_outlined : Icons.edit_calendar_outlined, size: 18), label: Text(value == null ? 'Pick' : 'Change')),
            if (value != null) IconButton(tooltip: 'Remove', onPressed: enabled ? onClear : null, icon: const Icon(Icons.close_rounded)),
          ],
        ),
        if (helper != null) Text(helper!, style: context.text.bodySmall),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Semantics(liveRegion: true, child: Row(children: [Icon(Icons.error_outline_rounded, size: 16, color: t.danger), const SizedBox(width: 6), Expanded(child: Text(error!, style: context.text.bodySmall?.copyWith(color: t.danger)))])),
          ),
      ],
    );
  }
}
