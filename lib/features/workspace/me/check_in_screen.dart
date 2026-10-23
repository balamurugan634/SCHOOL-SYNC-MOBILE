import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/design.dart';
import '../../../core/util/format.dart';
import '../../../data/models/attendance.dart';
import '../../../data/models/staff/leave.dart';
import '../../../data/repositories/staff/staff_leave_repository.dart';
import '../workspace.dart';
import 'check_in_logic.dart';
import 'me_providers.dart';

/// My own attendance: check in on arrival, check out on leaving, and the last 30 days.
class CheckInScreen extends ConsumerStatefulWidget {
  const CheckInScreen({super.key});

  @override
  ConsumerState<CheckInScreen> createState() => _CheckInScreenState();
}

class _CheckInScreenState extends ConsumerState<CheckInScreen> {
  bool _busy = false;

  Future<void> _run(bool checkIn) async {
    if (!checkIn) {
      final ok = await confirmAction(context, title: 'Check out now?', message: 'This records the time you are leaving school today.', confirmLabel: 'Check out');
      if (!ok || !mounted) return;
    }
    setState(() => _busy = true);
    final repo = ref.read(staffLeaveRepositoryProvider);
    await runWrite(context, ref, () => checkIn ? repo.checkIn() : repo.checkOut(), success: checkIn ? 'You are checked in.' : 'You are checked out. Have a good evening.');
    // Success or not, show what the server now says (another device or the office may have recorded it).
    ref.invalidate(myStaffAttendanceProvider);
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final value = ref.watch(myStaffAttendanceProvider);
    Future<void> refresh() async {
      ref.invalidate(myStaffAttendanceProvider);
      try {
        await ref.read(myStaffAttendanceProvider.future);
      } catch (_) {}
    }

    return FeatureGate(
      label: 'My attendance',
      anyPermission: const ['staff_attendance:create', 'staff_attendance:view'],
      child: StaffFrame(
        title: 'My attendance',
        body: AsyncBody<MyStaffAttendance>(
          value: value,
          onRetry: () => ref.invalidate(myStaffAttendanceProvider),
          data: (a) => RefreshScroll(
            onRefresh: refresh,
            children: [
              const ReadOnlyBanner(),
              _TodayCard(a: a, busy: _busy, canMark: ref.can('staff_attendance:create'), onCheckIn: () => _run(true), onCheckOut: () => _run(false)),
              const SizedBox(height: Gaps.md),
              _Summary(a),
              const GroupLabel('Daily record'),
              if (a.records.isEmpty)
                const AppCard(child: QuietLine('No attendance recorded yet.', icon: Icons.event_note_outlined))
              else
                RowGroup(children: [for (final r in a.records) _DayRow(r)]),
            ],
          ),
        ),
      ),
    );
  }
}

class _TodayCard extends ConsumerWidget {
  const _TodayCard({required this.a, required this.busy, required this.canMark, required this.onCheckIn, required this.onCheckOut});
  final MyStaffAttendance a;
  final bool busy;
  final bool canMark;
  final VoidCallback onCheckIn;
  final VoidCallback onCheckOut;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final readOnly = ref.watch(readOnlyProvider);
    final phase = checkInPhase(a);
    final today = a.today;
    final (headline, detail, tone, icon) = switch (phase) {
      CheckInPhase.notCheckedIn => ('Not checked in yet', 'Check in when you arrive at school.', StatusTone.warning, Icons.login_rounded),
      CheckInPhase.checkedIn => ('Checked in at ${formatClock(today?.checkIn)}', 'Check out when you leave.', StatusTone.success, Icons.check_rounded),
      CheckInPhase.checkedOut => ('Checked out at ${formatClock(today?.checkOut)}', _worked(today), StatusTone.info, Icons.logout_rounded),
      CheckInPhase.recordedByOffice => ('Recorded by the office', 'The office marked you ${(AttendanceStatus.parse(today?.status)?.label ?? 'present').toLowerCase()} today, so you do not need to check in.', StatusTone.info, Icons.badge_outlined),
    };
    final stateLabel = switch (phase) {
      CheckInPhase.notCheckedIn => 'Not checked in',
      CheckInPhase.checkedIn => 'Checked in',
      CheckInPhase.checkedOut => 'Done for today',
      CheckInPhase.recordedByOffice => 'Recorded',
    };

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [Expanded(child: Text(fmtDayLong(DateTime.now()), maxLines: 2, overflow: TextOverflow.ellipsis, style: context.text.labelMedium?.copyWith(color: t.textSecondary))), const SizedBox(width: Gaps.sm), Flexible(child: StatusChip(stateLabel, tone: tone, icon: icon))]),
          const SizedBox(height: Gaps.sm),
          Semantics(liveRegion: true, child: Text(headline, style: context.text.headlineSmall)),
          const SizedBox(height: 2),
          Text(detail, style: context.text.bodyMedium?.copyWith(color: t.textSecondary)),
          const SizedBox(height: Gaps.lg),
          if (phase == CheckInPhase.notCheckedIn)
            _BigButton(label: 'Check in', icon: Icons.login_rounded, busy: busy, onPressed: !canMark || readOnly ? null : onCheckIn, primary: true)
          else if (phase == CheckInPhase.checkedIn)
            _BigButton(label: 'Check out', icon: Icons.logout_rounded, busy: busy, onPressed: !canMark || readOnly ? null : onCheckOut, primary: false),
          if (!canMark && phase != CheckInPhase.recordedByOffice) Padding(padding: const EdgeInsets.only(top: Gaps.sm), child: Text('Your role does not include recording your own attendance.', style: context.text.bodySmall)),
        ],
      ),
    );
  }

  static String _worked(StaffDayRecord? r) {
    final w = workedDuration(r?.checkIn, r?.checkOut);
    return w == null ? 'See you tomorrow.' : 'You were at school for $w.';
  }
}

class _BigButton extends StatelessWidget {
  const _BigButton({required this.label, required this.icon, required this.busy, required this.onPressed, required this.primary});
  final String label;
  final IconData icon;
  final bool busy;
  final VoidCallback? onPressed;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final child = SizedBox(
      height: 56,
      width: double.infinity,
      child: primary
          ? PrimaryButton(label: label, icon: icon, loading: busy, onPressed: onPressed)
          : OutlinedButton.icon(onPressed: busy ? null : onPressed, icon: busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : Icon(icon), label: Text(label), style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(56))),
    );
    return child;
  }
}

class _Summary extends StatelessWidget {
  const _Summary(this.a);
  final MyStaffAttendance a;

  @override
  Widget build(BuildContext context) {
    final p = a.percentage;
    return SectionCard(
      title: 'Attendance rate',
      child: a.total == 0
          ? const QuietLine('Nothing recorded yet.')
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(crossAxisAlignment: CrossAxisAlignment.end, children: [Text(p == null ? '-' : '${p.toStringAsFixed(p % 1 == 0 ? 0 : 1)}%', style: figureStyle(context, size: 32)), const SizedBox(width: Gaps.sm), Expanded(child: Padding(padding: const EdgeInsets.only(bottom: 6), child: Text('${a.present} of ${a.total} days present over the last 30 days', style: context.text.bodyMedium)))]),
                const SizedBox(height: Gaps.sm),
                MeterBar(value: (p ?? 0) / 100, semanticLabel: 'Attendance over the last 30 days'),
              ],
            ),
    );
  }
}

class _DayRow extends StatelessWidget {
  const _DayRow(this.r);
  final StaffDayRecord r;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final times = [if (r.checkIn != null) 'In ${formatClock(r.checkIn)}', if (r.checkOut != null) 'Out ${formatClock(r.checkOut)}'].join('  ·  ');
    final status = AttendanceStatus.parse(r.status);
    return Semantics(
      container: true,
      label: '${fmtDay(r.date)}, ${status?.label ?? r.status}. $times',
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: Gaps.lg, vertical: Gaps.sm),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(relativeDay(r.date), style: context.text.bodyMedium?.copyWith(fontWeight: FontWeight.w500)),
                    if (times.isNotEmpty) Text(times, style: context.text.bodySmall?.copyWith(color: t.textSecondary)),
                  ],
                ),
              ),
              AttendanceChip(status),
            ],
          ),
        ),
      ),
    );
  }
}
