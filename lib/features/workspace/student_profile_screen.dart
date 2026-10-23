import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design/design.dart';
import '../../core/network/app_exception.dart';
import '../../core/util/format.dart';
import '../../data/models/attendance.dart';
import '../../data/models/staff/finance.dart';
import '../../data/models/staff/people.dart';
import '../security/secure_scope.dart';
import 'student_profile_providers.dart';
import 'workspace.dart';

/// A student's read-only profile for staff: class, guardians (tap to call), attendance, recent homework and the fee
/// balance. Each part appears only when the person holds the permission and the API allows it; a part that comes back
/// 403 simply disappears. Screen capture is blocked (contact and fee details).
class StudentProfileScreen extends ConsumerWidget {
  const StudentProfileScreen({super.key, required this.studentId});
  final String studentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(studentDetailProvider(studentId));
    Future<void> refresh() async {
      ref
        ..invalidate(studentDetailProvider(studentId))
        ..invalidate(studentAttendanceProvider(studentId))
        ..invalidate(studentInvoicesProvider(studentId));
      try {
        await ref.read(studentDetailProvider(studentId).future);
      } catch (_) {}
    }

    return SecureScope(
      child: Scaffold(
        appBar: AppBar(title: Text(detail.value?.row.name ?? 'Student')),
        body: AsyncBody<StudentDetail>(
          value: detail,
          onRetry: () => ref.invalidate(studentDetailProvider(studentId)),
          data: (d) => RefreshScroll(
            onRefresh: refresh,
            children: [
              _Header(d),
              const SizedBox(height: Gaps.md),
              if (ref.can('attendance:view')) ...[_AttendanceCard(studentId: studentId), const SizedBox(height: Gaps.md)],
              if (ref.can('homework:view') && d.row.sectionId != null) ...[_HomeworkCard(studentId: studentId, sectionId: d.row.sectionId!), const SizedBox(height: Gaps.md)],
              _GuardiansCard(d),
              if (d.emergencyContacts.isNotEmpty || (d.medicalNotes != null && d.medicalNotes!.isNotEmpty)) ...[const SizedBox(height: Gaps.md), _SafetyCard(d)],
              if (ref.canAny(const ['fees:view', 'payments:view']) && ref.watch(feesEnabledProvider)) ...[const SizedBox(height: Gaps.md), _FeesCard(studentId: studentId)],
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(this.d);
  final StudentDetail d;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final r = d.row;
    final facts = <(String, String)>[
      ('Admission no.', r.admissionNo),
      if (r.rollNo != null) ('Roll no.', '${r.rollNo}'),
      if (r.dob != null) ('Born', fmtFull(r.dob!)),
      if (d.bloodGroup != null && d.bloodGroup!.isNotEmpty) ('Blood group', d.bloodGroup!),
      if (d.admissionDate != null) ('Admitted', fmtFull(d.admissionDate!)),
      if (d.address != null) ('Address', d.address!),
    ];
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              UserAvatar(name: r.name, url: r.photoUrl, size: 64),
              const SizedBox(width: Gaps.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Semantics(header: true, child: Text(r.name, style: context.text.headlineSmall)),
                    Text(r.classLabel, style: context.text.bodyMedium?.copyWith(color: t.textSecondary)),
                    if (r.status != 'active') Padding(padding: const EdgeInsets.only(top: Gaps.xs), child: StatusChip(_statusLabel(r.status), tone: StatusTone.warning, icon: Icons.info_outline_rounded)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: Gaps.md),
          const Divider(),
          for (final f in facts) FactRow(f.$1, f.$2),
        ],
      ),
    );
  }

  static String _statusLabel(String s) => switch (s) {
    'suspended' => 'Suspended',
    'transferred' => 'Transferred',
    'withdrawn' => 'Withdrawn',
    'alumni' => 'Alumni',
    _ => s,
  };
}

/// A part of the profile that loads on its own: skeleton, error with retry, or nothing when the API says no (403).
class _Part<T> extends StatelessWidget {
  const _Part({required this.title, required this.value, required this.onRetry, required this.builder, this.empty});
  final String title;
  final AsyncValue<T> value;
  final VoidCallback onRetry;
  final Widget Function(T data) builder;
  final String? empty;

  @override
  Widget build(BuildContext context) {
    if (value.hasError && !value.hasValue && AppException.from(value.error!).kind == ErrorKind.forbidden) return const SizedBox.shrink();
    return SectionCard(
      title: title,
      child: value.hasValue
          ? builder(value.requireValue)
          : value.hasError
          ? ErrorState(error: value.error!, compact: true, onRetry: onRetry)
          : const Skeletonize(),
    );
  }
}

/// Three grey lines while a part loads.
class Skeletonize extends StatelessWidget {
  const Skeletonize({super.key});

  @override
  Widget build(BuildContext context) => const SkeletonList(count: 1, padding: EdgeInsets.zero);
}

// ───────────────────────────── attendance ─────────────────────────────

class _AttendanceCard extends ConsumerWidget {
  const _AttendanceCard({required this.studentId});
  final String studentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = studentAttendanceProvider(studentId);
    return _Part<AttendanceSummary>(
      title: 'Attendance this year',
      value: ref.watch(provider),
      onRetry: () => ref.invalidate(provider),
      builder: (s) {
        final t = context.tokens;
        final c = s.totals;
        if (c.total == 0) return const QuietLine('No attendance has been recorded yet.', icon: Icons.fact_check_outlined);
        final here = c.present + c.late + c.halfDay;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: Gaps.md,
              crossAxisAlignment: WrapCrossAlignment.end,
              children: [
                Text('${c.percentage.toStringAsFixed(c.percentage % 1 == 0 ? 0 : 1)}%', style: figureStyle(context, size: 32)),
                Text('$here of ${c.total} days present', style: context.text.bodySmall),
              ],
            ),
            const SizedBox(height: Gaps.xs),
            MeterBar(value: c.percentage / 100, semanticLabel: 'Attendance'),
            const SizedBox(height: Gaps.sm),
            Wrap(
              spacing: Gaps.sm,
              runSpacing: Gaps.xs,
              children: [
                StatusChip('${c.present} present', tone: StatusTone.success, icon: attendanceIcon(AttendanceStatus.present)),
                StatusChip('${c.absent} absent', tone: StatusTone.danger, icon: attendanceIcon(AttendanceStatus.absent)),
                StatusChip('${c.late} late', tone: StatusTone.warning, icon: attendanceIcon(AttendanceStatus.late)),
                if (c.leave > 0) StatusChip('${c.leave} on leave', tone: StatusTone.info, icon: attendanceIcon(AttendanceStatus.leave)),
                if (c.halfDay > 0) StatusChip('${c.halfDay} half days', tone: StatusTone.warning, icon: attendanceIcon(AttendanceStatus.halfDay)),
              ],
            ),
            if (s.isShort) Padding(padding: const EdgeInsets.only(top: Gaps.sm), child: Text('Below the ${s.thresholdPercent.toStringAsFixed(0)}% attendance requirement.', style: context.text.labelMedium?.copyWith(color: t.danger))),
          ],
        );
      },
    );
  }
}

// ───────────────────────────── homework ─────────────────────────────

class _HomeworkCard extends ConsumerWidget {
  const _HomeworkCard({required this.studentId, required this.sectionId});
  final String studentId;
  final String sectionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = studentHomeworkProvider((studentId: studentId, sectionId: sectionId));
    return _Part<List<StudentHomeworkLine>>(
      title: 'Recent homework',
      value: ref.watch(provider),
      onRetry: () => ref.invalidate(provider),
      builder: (lines) {
        if (lines.isEmpty) return const QuietLine('No homework has been set for this class yet.', icon: Icons.assignment_outlined);
        final handedIn = lines.where((l) => l.row != null && l.row!.status != 'missing').length;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Handed in $handedIn of ${lines.length}', style: context.text.bodySmall),
            const SizedBox(height: Gaps.xs),
            for (final l in lines)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: Gaps.xs),
                child: ChipLine(
                  chip: _HomeworkChip(l),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l.homework.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: context.text.bodyMedium?.copyWith(fontWeight: FontWeight.w500)),
                      Text('${l.homework.subjectName}  ·  due ${fmtShort(l.homework.dueAt)}', style: context.text.bodySmall),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _HomeworkChip extends StatelessWidget {
  const _HomeworkChip(this.l);
  final StudentHomeworkLine l;

  @override
  Widget build(BuildContext context) {
    final row = l.row;
    if (row == null) return const StatusChip('Unknown', icon: Icons.help_outline_rounded);
    final overdue = l.homework.dueAt.isBefore(DateTime.now());
    return switch (row.status) {
      'submitted' => const StatusChip('Handed in', tone: StatusTone.info, icon: Icons.inbox_rounded),
      'late' => const StatusChip('Handed in late', tone: StatusTone.warning, icon: Icons.schedule_rounded),
      'reviewed' => StatusChip(row.submission?.marks == null ? 'Reviewed' : 'Reviewed, ${_num(row.submission!.marks!)}', tone: StatusTone.success, icon: Icons.check_rounded),
      'returned' => const StatusChip('Returned', tone: StatusTone.warning, icon: Icons.undo_rounded),
      _ => overdue ? const StatusChip('Missing', tone: StatusTone.danger, icon: Icons.close_rounded) : const StatusChip('Not yet', icon: Icons.hourglass_empty_rounded),
    };
  }

  static String _num(double v) => v % 1 == 0 ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
}

// ───────────────────────────── guardians and safety ─────────────────────────────

class _GuardiansCard extends StatelessWidget {
  const _GuardiansCard(this.d);
  final StudentDetail d;

  @override
  Widget build(BuildContext context) => SectionCard(
    title: 'Parents and guardians',
    padding: EdgeInsets.zero,
    child: d.guardians.isEmpty
        ? const Padding(padding: EdgeInsets.fromLTRB(Gaps.lg, 0, Gaps.lg, Gaps.sm), child: QuietLine('No guardian is linked yet.', icon: Icons.family_restroom_rounded))
        : Column(children: [for (final (i, g) in d.guardians.indexed) ...[if (i > 0) const Divider(indent: Gaps.lg), _GuardianRow(g)]]),
  );
}

class _GuardianRow extends StatelessWidget {
  const _GuardianRow(this.g);
  final GuardianLink g;

  @override
  Widget build(BuildContext context) {
    final rel = g.relationship.isEmpty ? '' : '${g.relationship[0].toUpperCase()}${g.relationship.substring(1)}';
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 64),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Gaps.lg, Gaps.sm, Gaps.sm, Gaps.sm),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(g.name, style: context.text.bodyMedium?.copyWith(fontWeight: FontWeight.w500)),
                  Text([rel, if (g.phone != null) g.phone!].where((e) => e.isNotEmpty).join('  ·  '), style: context.text.bodySmall),
                  Padding(
                    padding: const EdgeInsets.only(top: Gaps.xs),
                    child: Wrap(
                      spacing: Gaps.xs,
                      runSpacing: Gaps.xs,
                      children: [
                        if (g.isPrimary) const StatusChip('Primary', tone: StatusTone.brand, icon: Icons.star_outline_rounded),
                        if (!g.verified) const StatusChip('Not verified', tone: StatusTone.warning, icon: Icons.help_outline_rounded),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (g.phone != null && g.phone!.isNotEmpty) IconButton(tooltip: 'Call ${g.name}', onPressed: () => callPhone(context, g.phone), icon: const Icon(Icons.call_outlined), style: IconButton.styleFrom(minimumSize: const Size(48, 48))),
          ],
        ),
      ),
    );
  }
}

class _SafetyCard extends StatelessWidget {
  const _SafetyCard(this.d);
  final StudentDetail d;

  @override
  Widget build(BuildContext context) => SectionCard(
    title: 'Emergency and health',
    padding: const EdgeInsets.fromLTRB(Gaps.lg, 0, Gaps.sm, Gaps.sm),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final c in d.emergencyContacts)
          Row(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: Gaps.xs),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(c.name, style: context.text.bodyMedium?.copyWith(fontWeight: FontWeight.w500)),
                      Text([if (c.relationship != null) c.relationship!, if (c.phone != null) c.phone!].join('  ·  '), style: context.text.bodySmall),
                    ],
                  ),
                ),
              ),
              if (c.phone != null && c.phone!.isNotEmpty) IconButton(tooltip: 'Call ${c.name}', onPressed: () => callPhone(context, c.phone), icon: const Icon(Icons.call_outlined), style: IconButton.styleFrom(minimumSize: const Size(48, 48))),
            ],
          ),
        if (d.medicalNotes != null && d.medicalNotes!.isNotEmpty) Padding(padding: const EdgeInsets.only(top: Gaps.sm, right: Gaps.md), child: DetailBlock('Medical notes', d.medicalNotes!)),
      ],
    ),
  );
}

// ───────────────────────────── fees ─────────────────────────────

class _FeesCard extends ConsumerWidget {
  const _FeesCard({required this.studentId});
  final String studentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = studentInvoicesProvider(studentId);
    final currency = ref.watch(currencyProvider);
    return _Part<List<InvoiceLine>>(
      title: 'Fees',
      value: ref.watch(provider),
      onRetry: () => ref.invalidate(provider),
      builder: (invoices) {
        final live = invoices.where((i) => i.status != 'void').toList();
        if (live.isEmpty) return const QuietLine('No invoices yet.', icon: Icons.receipt_long_outlined);
        final balance = live.fold<int>(0, (a, i) => a + i.balanceMinor);
        final overdue = live.where((i) => i.overdue && i.balanceMinor > 0).fold<int>(0, (a, i) => a + i.balanceMinor);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: Gaps.md,
              runSpacing: Gaps.xs,
              crossAxisAlignment: WrapCrossAlignment.end,
              children: [
                Text(formatMinor(balance, currency: currency), style: figureStyle(context, size: 28)),
                Text(balance == 0 ? 'Nothing to pay' : 'balance to pay', style: context.text.bodySmall),
                if (overdue > 0) StatusChip('${formatMinor(overdue, currency: currency)} overdue', tone: StatusTone.danger, icon: Icons.warning_amber_rounded),
              ],
            ),
            const SizedBox(height: Gaps.sm),
            for (final i in live.take(5))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: Gaps.xs),
                child: ChipLine(
                  chip: i.status == 'paid'
                      ? const StatusChip('Paid', tone: StatusTone.success, icon: Icons.check_rounded)
                      : i.overdue
                      ? StatusChip(formatMinor(i.balanceMinor, currency: currency), tone: StatusTone.danger, icon: Icons.warning_amber_rounded)
                      : StatusChip(formatMinor(i.balanceMinor, currency: currency), tone: StatusTone.warning, icon: Icons.hourglass_empty_rounded),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(i.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: context.text.bodyMedium),
                      Text('${i.invoiceNo}${i.dueDate == null ? '' : '  ·  due ${fmtShort(i.dueDate!)}'}', style: context.text.bodySmall),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
