import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/design.dart';
import '../../../core/network/app_exception.dart';
import '../../../core/util/format.dart';
import '../../../data/json.dart' show isoDay;
import '../../../data/models/attendance.dart';
import '../../../data/models/staff/roll_call.dart';
import '../../workspace/workspace.dart';
import 'attendance_providers.dart';
import 'correction_request_sheet.dart';
import 'roll_call_draft.dart';
import 'roll_call_widgets.dart';

enum _RollFilter { all, unmarked, exceptions }

/// Problems that mean "this roll call cannot be sent as it is": the screen keeps the choices and explains why.
const _blockingCodes = {'EDIT_WINDOW_CLOSED', 'NOT_A_WORKING_DAY', 'HOLIDAY', 'FUTURE_DATE', 'NOT_CLASS_TEACHER', 'NOT_YOUR_PERIOD', 'NOT_ALLOWED_TO_MARK', 'PERIOD_REQUIRED', 'OUTSIDE_ACADEMIC_YEAR', 'STUDENT_NOT_IN_SECTION', 'EMPTY_SECTION'};

/// Roll call for one section and date, built for one-handed use: big Present / Absent buttons (or swipe), a "more"
/// button for late / leave / half-day / remarks, "Mark all present", a progress counter and one sticky Submit.
/// When the roll call is closed (edit window, holiday, not your class ...) it opens read-only and says why;
/// closed roll calls offer "Request a correction" per student.
class RollCallScreen extends ConsumerStatefulWidget {
  const RollCallScreen({super.key, required this.sectionId, this.date, this.periodId});
  final String sectionId;
  final DateTime? date;
  final String? periodId;

  @override
  ConsumerState<RollCallScreen> createState() => _RollCallScreenState();
}

class _RollCallScreenState extends ConsumerState<RollCallScreen> {
  _RollFilter _filter = _RollFilter.all;
  bool _submitting = false;
  bool _discarded = false;
  String? _error;
  bool _errorNeedsReload = false;

  RollCallArgs get _args => (sectionId: widget.sectionId, date: widget.date == null ? null : isoDay(widget.date!), periodId: widget.periodId);
  RollCallController get _ctrl => ref.read(rollCallProvider(_args).notifier);

  Future<void> _refresh(bool dirty) async {
    if (dirty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Submit your changes first. Refreshing would discard them.')));
      return;
    }
    ref.invalidate(rollCallProvider(_args));
    try {
      await ref.read(rollCallProvider(_args).future);
    } catch (_) {}
  }

  Future<void> _markAll(RollCallDraft d) async {
    if (d.hasChosenStatuses) {
      final n = d.students.where((s) => !d.isLocked(s) && d.statusOf(s.studentId) != null && d.statusOf(s.studentId) != AttendanceStatus.present).length;
      final ok = await confirmAction(context, title: 'Mark everyone present?', message: '$n ${n == 1 ? 'student you marked' : 'students you marked'} as absent, late or half day will become present.', confirmLabel: 'Mark all present');
      if (!ok || !mounted) return;
    }
    _ctrl.markAllPresent();
  }

  void _more(RollCallDraft d, RosterStudent s) {
    showStatusSheet(context, student: s, current: d.statusOf(s.studentId), remark: d.remarkOf(s.studentId), onSave: (status, remark) {
      _ctrl.setStatus(s.studentId, status);
      _ctrl.setRemark(s.studentId, remark);
    });
  }

  Future<void> _correct(Roster roster, RosterStudent s) async {
    final id = s.recordId;
    if (id == null) return;
    final messenger = ScaffoldMessenger.of(context);
    final sent = await showCorrectionRequestSheet(context, recordId: id, studentName: s.name, date: roster.date, current: s.status);
    if (sent) messenger.showSnackBar(const SnackBar(content: Text('Correction requested. The class teacher or the office will decide.')));
  }

  Future<void> _submit(RollCallDraft d) async {
    final c = d.counts;
    final go = await confirmSubmit(context, roster: d.roster, counts: c, absent: d.withStatus(AttendanceStatus.absent), late: d.withStatus(AttendanceStatus.late), halfDay: d.withStatus(AttendanceStatus.halfDay), resubmit: d.roster.alreadySubmitted);
    if (!go || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    setState(() {
      _submitting = true;
      _error = null;
    });
    SubmitResult? result;
    final ok = await runWrite(
      context,
      ref,
      () async => result = await _ctrl.submit(),
      onError: (e) {
        if (!mounted) return;
        final code = AppException.from(e).code;
        setState(() {
          _error = friendlyError(e);
          _errorNeedsReload = _blockingCodes.contains(code) || isStaleStateError(e);
        });
        messenger.showSnackBar(SnackBar(content: Text('The roll call was not submitted. ${friendlyError(e)}'), duration: const Duration(seconds: 7)));
      },
    );
    if (!mounted) return;
    setState(() => _submitting = false);
    final r = result;
    if (ok && r != null) {
      final parts = [
        '${r.counts.present} present',
        if (r.counts.absent > 0) '${r.counts.absent} absent',
        if (r.counts.late > 0) '${r.counts.late} late',
        if (r.counts.halfDay > 0) '${r.counts.halfDay} half day',
        if (r.counts.leave > 0) '${r.counts.leave} on leave',
      ];
      messenger.showSnackBar(
        SnackBar(
          content: Text('Roll call submitted: ${parts.join(', ')}.${r.notifiedGuardians > 0 ? ' ${plural(r.notifiedGuardians, 'guardian')} notified.' : ''}${r.editableUntil != null ? ' You can change it until ${fmtDateTime(r.editableUntil!)}.' : ''}'),
          duration: const Duration(seconds: 8),
        ),
      );
      _discarded = true;
      nav.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = rollCallProvider(_args);
    final v = ref.watch(provider);
    final draft = v.value?.draft;
    final editable = draft?.roster.canSubmit ?? false;
    final dirty = editable && (draft?.isDirty ?? false);

    return PopScope(
      canPop: _discarded || !dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop || _submitting) return;
        final nav = Navigator.of(context);
        final leave = await confirmAction(context, title: 'Leave without submitting?', message: 'You have changes to this roll call that are not submitted yet. They will be lost.', confirmLabel: 'Discard changes', destructive: true);
        if (leave && mounted) {
          setState(() => _discarded = true);
          nav.pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Roll call')),
        body: AsyncBody<RollCallState>(
          value: v,
          onRetry: () => ref.invalidate(provider),
          loading: const _RollSkeleton(),
          data: (s) => _content(s.draft, dirty),
        ),
        bottomNavigationBar: draft != null && editable && draft.total > 0 ? _SubmitBar(draft: draft, busy: _submitting, onSubmit: () => _submit(draft), onShowUnmarked: () => setState(() => _filter = _RollFilter.unmarked)) : null,
      ),
    );
  }

  Widget _content(RollCallDraft d, bool dirty) {
    final roster = d.roster;
    final editable = roster.canSubmit;
    final counts = d.counts;
    final visible = switch (_filter) {
      _RollFilter.all => d.students,
      _RollFilter.unmarked => d.students.where((s) => d.statusOf(s.studentId) == null).toList(growable: false),
      _RollFilter.exceptions => d.students.where((s) => d.statusOf(s.studentId) == AttendanceStatus.absent || d.statusOf(s.studentId) == AttendanceStatus.late).toList(growable: false),
    };

    final header = <Widget>[
      Padding(
        padding: const EdgeInsets.fromLTRB(Gaps.page, Gaps.sm, Gaps.page, 0),
        child: _RollHeader(roster: roster, error: _error, onReload: _errorNeedsReload ? () => ref.invalidate(rollCallProvider(_args)) : null),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(Gaps.page, Gaps.md, Gaps.page, Gaps.sm),
        child: _Progress(draft: d, editable: editable, onMarkAll: editable ? () => _markAll(d) : null),
      ),
      if (editable && d.total > 0)
        Padding(
          padding: const EdgeInsets.only(bottom: Gaps.sm),
          child: FilterChips<_RollFilter>(
            options: _RollFilter.values,
            selected: _filter,
            onSelected: (f) => setState(() => _filter = f),
            labelOf: (f) => switch (f) {
              _RollFilter.all => 'All ${d.total}',
              _RollFilter.unmarked => 'Not marked ${counts.unmarked}',
              _RollFilter.exceptions => 'Absent or late ${counts.absent + counts.late}',
            },
          ),
        ),
    ];

    Widget body;
    if (d.total == 0) {
      body = const EmptyState(icon: Icons.groups_outlined, title: 'No students in this class yet', message: 'When students are enrolled in this section they will appear here.');
    } else if (visible.isEmpty) {
      body = EmptyState(
        illo: Illo.noResults,
        title: _filter == _RollFilter.unmarked ? 'Everyone has a status' : 'No students match this filter',
        compact: true,
        actionLabel: 'Show everyone',
        onAction: () => setState(() => _filter = _RollFilter.all),
      );
    } else {
      body = const SizedBox.shrink();
    }

    return RefreshIndicator(
      onRefresh: () => _refresh(dirty),
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: Gaps.huge),
        itemCount: header.length + (visible.isEmpty ? 1 : visible.length),
        itemBuilder: (context, i) {
          if (i < header.length) return header[i];
          if (visible.isEmpty) return body;
          final s = visible[i - header.length];
          final row = RollCallRow(
            student: s,
            status: d.statusOf(s.studentId),
            remark: d.remarkOf(s.studentId),
            editable: editable,
            locked: d.isLocked(s),
            onSet: (st) => _ctrl.setStatus(s.studentId, st),
            onMore: () => _more(d, s),
            onCorrect: !editable && roster.canRequestCorrection && s.recordId != null ? () => _correct(roster, s) : null,
          );
          return Column(children: [if (i == header.length) const Divider(), row, const Divider()]);
        },
      ),
    );
  }
}

class _RollHeader extends StatelessWidget {
  const _RollHeader({required this.roster, required this.error, required this.onReload});
  final Roster roster;
  final String? error;
  final VoidCallback? onReload;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final s = roster.session;
    final blocked = roster.blockedReason;
    // When the roll call is closed the "Read-only" banner already explains why; otherwise warnings are shown as they are.
    final extraWarnings = roster.warnings.where((w) => w != blocked && (roster.canSubmit || w == 'PRE_MARKED_FROM_LEAVE')).toSet();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(header: true, child: Text(roster.title, style: context.text.titleLarge)),
              const SizedBox(height: 2),
              Text(fmtDayLong(roster.date), style: context.text.bodyMedium?.copyWith(color: t.textSecondary)),
              if (roster.periodName != null || roster.subjectName != null) ...[
                const SizedBox(height: Gaps.sm),
                Wrap(spacing: 6, runSpacing: 4, children: [if (roster.periodName != null) StatusChip(roster.periodName!, icon: Icons.schedule_rounded), if (roster.subjectName != null) StatusChip(roster.subjectName!, icon: Icons.menu_book_outlined)]),
              ],
              if (s != null && s.submitted) ...[
                const SizedBox(height: Gaps.md),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.check_circle_outline_rounded, size: 18, color: t.success),
                    const SizedBox(width: Gaps.sm),
                    Expanded(
                      child: Text(
                        [
                          'Submitted${s.takenByName != null ? ' by ${s.takenByName}' : ''}${s.submittedAt != null ? ' on ${fmtDateTime(s.submittedAt!)}' : ''}.',
                          if (s.editableUntil != null) roster.canSubmit ? 'You can change it until ${fmtDateTime(s.editableUntil!)}.' : 'Changes closed on ${fmtDateTime(s.editableUntil!)}.',
                        ].join(' '),
                        style: context.text.bodySmall,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        if (!roster.canSubmit) ...[
          const SizedBox(height: Gaps.sm),
          InfoBanner(
            tone: BannerTone.warning,
            icon: Icons.lock_outline_rounded,
            title: 'Read-only',
            message: [
              if (blocked != null) rollCallReasonCopy(blocked) else 'You cannot change this roll call.',
              if (roster.canRequestCorrection) 'Tap a student to ask for a correction.',
            ].join(' '),
          ),
        ],
        for (final w in extraWarnings) ...[const SizedBox(height: Gaps.sm), InfoBanner(tone: BannerTone.info, message: rollCallReasonCopy(w))],
        if (error != null) ...[
          const SizedBox(height: Gaps.sm),
          InfoBanner(tone: BannerTone.danger, title: 'Not submitted', message: error!, action: onReload == null ? null : 'Reload roll call', onAction: onReload),
        ],
        const ReadOnlyBanner(),
      ],
    );
  }
}

class _Progress extends StatelessWidget {
  const _Progress({required this.draft, required this.editable, required this.onMarkAll});
  final RollCallDraft draft;
  final bool editable;
  final VoidCallback? onMarkAll;

  @override
  Widget build(BuildContext context) {
    if (draft.total == 0) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (editable) ...[
          MeterBar(value: draft.progress, label: '${draft.markedCount} of ${draft.total} marked', semanticLabel: 'Students marked'),
          const SizedBox(height: Gaps.md),
        ],
        CountChips(counts: draft.counts),
        if (onMarkAll != null) ...[const SizedBox(height: Gaps.md), SecondaryButton(label: 'Mark all present', icon: Icons.done_all_rounded, onPressed: onMarkAll)],
      ],
    );
  }
}

class _SubmitBar extends StatelessWidget {
  const _SubmitBar({required this.draft, required this.busy, required this.onSubmit, required this.onShowUnmarked});
  final RollCallDraft draft;
  final bool busy;
  final VoidCallback onSubmit;
  final VoidCallback onShowUnmarked;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final left = draft.unmarkedCount;
    return DecoratedBox(
      decoration: BoxDecoration(color: t.surface, border: Border(top: BorderSide(color: t.border))),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Gaps.page, Gaps.sm, Gaps.page, Gaps.sm),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (left > 0)
                Row(
                  children: [
                    Expanded(child: Text('${plural(left, 'student')} still ${left == 1 ? 'needs' : 'need'} a status before you can submit.', style: context.text.bodySmall?.copyWith(color: t.textSecondary))),
                    TextButton(onPressed: onShowUnmarked, child: const Text('Show')),
                  ],
                ),
              PrimaryButton(label: draft.roster.alreadySubmitted ? 'Submit changes' : 'Submit roll call', icon: Icons.send_rounded, loading: busy, onPressed: draft.isComplete ? onSubmit : null),
            ],
          ),
        ),
      ),
    );
  }
}

class _RollSkeleton extends StatelessWidget {
  const _RollSkeleton();

  @override
  Widget build(BuildContext context) => const SingleChildScrollView(
    physics: NeverScrollableScrollPhysics(),
    child: Padding(padding: EdgeInsets.only(top: Gaps.sm), child: SkeletonList(count: 7)),
  );
}
