import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/design/design.dart';
import '../../../core/network/app_exception.dart';
import '../../../core/util/format.dart';
import '../../../data/models/attendance.dart';
import '../../../data/models/staff/roll_call.dart';
import '../../workspace/workspace.dart';

/// The plain-language reason a roll call cannot be changed (a `blockedReason` or warning code from the API).
String rollCallReasonCopy(String code) {
  if (code == 'PRE_MARKED_FROM_LEAVE') return 'Students on approved leave were marked as Leave automatically.';
  return friendlyError(AppException(kind: ErrorKind.unknown, code: code, message: 'This roll call cannot be changed.'));
}

/// Light tap feedback; never delays the action.
void _tick() => HapticFeedback.selectionClick();

/// One round 48 dp toggle used in the roll call row (Present / Absent). The label lives in the tooltip and
/// semantics; the row also prints the status label as a chip, so colour is never the only signal.
class _StatusButton extends StatelessWidget {
  const _StatusButton({required this.status, required this.selected, required this.onTap, required this.semanticLabel});
  final AttendanceStatus status;
  final bool selected;
  final VoidCallback? onTap;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final p = switch (attendanceTone(status)) {
      StatusTone.success => t.successPalette,
      StatusTone.danger => t.dangerPalette,
      StatusTone.warning => t.warningPalette,
      _ => t.brandPalette,
    };
    return Semantics(
      button: true,
      selected: selected,
      enabled: onTap != null,
      label: semanticLabel,
      excludeSemantics: true,
      child: Tooltip(
        message: status.label,
        child: SizedBox(
          width: 48,
          height: 48,
          child: Center(
            child: Material(
              color: selected ? p.bg : Colors.transparent,
              shape: CircleBorder(side: BorderSide(color: selected ? p.fg : t.borderStrong, width: selected ? 2 : 1)),
              child: InkResponse(
                onTap: onTap,
                customBorder: const CircleBorder(),
                radius: 26,
                child: SizedBox(width: 44, height: 44, child: Icon(attendanceIcon(status), size: 22, color: selected ? p.fg : t.textTertiary)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A roll call row (>= 64 dp): roll number, name, the current status as an icon + label chip, and one-hand controls:
/// Present, Absent, and "more" (late / leave / half-day / remark). Swipe right = Present, swipe left = Absent
/// (the buttons do the same, so swiping is never required).
class RollCallRow extends StatelessWidget {
  const RollCallRow({super.key, required this.student, required this.status, required this.remark, required this.editable, required this.locked, required this.onSet, required this.onMore, this.onCorrect});

  final RosterStudent student;
  final AttendanceStatus? status;
  final String? remark;
  final bool editable;

  /// On approved leave: the API records Leave, the row cannot be changed.
  final bool locked;
  final ValueChanged<AttendanceStatus> onSet;
  final VoidCallback onMore;

  /// Closed roll call: ask for a correction (null when this student has no saved record).
  final VoidCallback? onCorrect;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final showControls = editable && !locked;
    final exceptional = status == AttendanceStatus.late || status == AttendanceStatus.leave || status == AttendanceStatus.halfDay;
    final info = Expanded(
      child: MergeSemantics(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 32, child: Text(student.rollNo?.toString() ?? '', style: context.text.labelMedium?.copyWith(color: t.textSecondary, fontFeatures: const [FontFeature.tabularFigures()]))),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(student.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: context.text.bodyMedium?.copyWith(fontWeight: FontWeight.w500)),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      AttendanceChip(status),
                      if (locked) Text('On approved leave', style: context.text.labelSmall?.copyWith(color: t.textSecondary)),
                      if (remark != null && remark!.isNotEmpty) Text(remark!, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.text.labelSmall?.copyWith(color: t.textSecondary)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    final row = Container(
      constraints: const BoxConstraints(minHeight: 64),
      color: t.surface,
      padding: const EdgeInsets.only(left: Gaps.lg, right: Gaps.xs, top: 4, bottom: 4),
      child: Row(
        children: [
          info,
          if (showControls) ...[
            _StatusButton(status: AttendanceStatus.present, selected: status == AttendanceStatus.present, semanticLabel: 'Mark ${student.name} present', onTap: () => _set(AttendanceStatus.present)),
            _StatusButton(status: AttendanceStatus.absent, selected: status == AttendanceStatus.absent, semanticLabel: 'Mark ${student.name} absent', onTap: () => _set(AttendanceStatus.absent)),
            Semantics(
              button: true,
              label: 'More options for ${student.name}: late, leave, half day, remark',
              excludeSemantics: true,
              child: Tooltip(
                message: 'Late, leave, half day or a remark',
                child: SizedBox(
                  width: 48,
                  height: 48,
                  child: InkResponse(
                    onTap: onMore,
                    radius: 26,
                    child: Icon(exceptional ? attendanceIcon(status) : Icons.more_horiz_rounded, size: 22, color: exceptional ? (status == AttendanceStatus.leave ? t.info : t.warning) : t.textSecondary),
                  ),
                ),
              ),
            ),
          ] else if (onCorrect != null)
            IconButton(tooltip: 'Request a correction for ${student.name}', onPressed: onCorrect, icon: const Icon(Icons.edit_note_rounded), constraints: const BoxConstraints(minWidth: 48, minHeight: 48)),
        ],
      ),
    );

    Widget content = row;
    if (showControls) {
      content = Dismissible(
        key: ValueKey('swipe-${student.studentId}'),
        direction: DismissDirection.horizontal,
        confirmDismiss: (dir) async {
          _set(dir == DismissDirection.startToEnd ? AttendanceStatus.present : AttendanceStatus.absent);
          return false;
        },
        background: _SwipeHint(color: t.successTint, fg: t.success, icon: Icons.check_rounded, label: 'Present', alignment: Alignment.centerLeft),
        secondaryBackground: _SwipeHint(color: t.dangerTint, fg: t.danger, icon: Icons.close_rounded, label: 'Absent', alignment: Alignment.centerRight),
        child: row,
      );
    } else if (onCorrect != null) {
      content = InkWell(onTap: onCorrect, child: row);
    }
    return content;
  }

  void _set(AttendanceStatus s) {
    _tick();
    onSet(s);
  }
}

class _SwipeHint extends StatelessWidget {
  const _SwipeHint({required this.color, required this.fg, required this.icon, required this.label, required this.alignment});
  final Color color;
  final Color fg;
  final IconData icon;
  final String label;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) => Container(
    color: color,
    alignment: alignment,
    padding: const EdgeInsets.symmetric(horizontal: Gaps.xl),
    child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, color: fg), const SizedBox(width: 8), Text(label, style: context.text.labelLarge?.copyWith(color: fg))]),
  );
}

/// All five statuses plus a remark, for the cases the two big buttons do not cover.
Future<void> showStatusSheet(BuildContext context, {required RosterStudent student, required AttendanceStatus? current, required String? remark, required void Function(AttendanceStatus status, String remark) onSave}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _StatusSheet(student: student, current: current, remark: remark, onSave: onSave),
  );
}

class _StatusSheet extends StatefulWidget {
  const _StatusSheet({required this.student, required this.current, required this.remark, required this.onSave});
  final RosterStudent student;
  final AttendanceStatus? current;
  final String? remark;
  final void Function(AttendanceStatus status, String remark) onSave;

  @override
  State<_StatusSheet> createState() => _StatusSheetState();
}

class _StatusSheetState extends State<_StatusSheet> {
  late AttendanceStatus? _status = widget.current;
  late final _remark = TextEditingController(text: widget.remark ?? '');

  @override
  void dispose() {
    _remark.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(Gaps.page, 0, Gaps.page, Gaps.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(header: true, child: Text(widget.student.name, style: context.text.titleLarge)),
            if (widget.student.rollNo != null) Text('Roll no. ${widget.student.rollNo}', style: context.text.bodySmall),
            const SizedBox(height: Gaps.md),
            for (final s in AttendanceStatus.values)
              Semantics(
                button: true,
                selected: _status == s,
                child: InkWell(
                  borderRadius: BorderRadius.circular(Radii.md),
                  onTap: () => setState(() => _status = s),
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 56),
                    padding: const EdgeInsets.symmetric(horizontal: Gaps.md),
                    margin: const EdgeInsets.only(bottom: 2),
                    decoration: BoxDecoration(color: _status == s ? t.brand.soft : null, borderRadius: BorderRadius.circular(Radii.md)),
                    child: Row(
                      children: [
                        Icon(attendanceIcon(s), color: _status == s ? t.brand.ink : t.textSecondary),
                        const SizedBox(width: Gaps.md),
                        Expanded(child: Text(s.label, style: context.text.bodyLarge?.copyWith(fontWeight: _status == s ? FontWeight.w600 : FontWeight.w400))),
                        if (_status == s) Icon(Icons.check_rounded, color: t.brand.ink),
                      ],
                    ),
                  ),
                ),
              ),
            const SizedBox(height: Gaps.md),
            TextField(controller: _remark, maxLength: 300, minLines: 1, maxLines: 3, textCapitalization: TextCapitalization.sentences, decoration: const InputDecoration(labelText: 'Remark (optional)', hintText: 'For example: left at lunch')),
            const SizedBox(height: Gaps.sm),
            PrimaryButton(
              label: 'Save',
              onPressed: _status == null
                  ? null
                  : () {
                      widget.onSave(_status!, _remark.text);
                      Navigator.pop(context);
                    },
            ),
          ],
        ),
      ),
    );
  }
}

/// Counts as chips: Present 20, Absent 2 ... (only the non-zero ones) plus "Not marked n".
class CountChips extends StatelessWidget {
  const CountChips({super.key, required this.counts});
  final StatusCounts counts;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 6,
    runSpacing: 6,
    children: [
      for (final s in AttendanceStatus.values)
        if (counts.of(s) > 0) StatusChip('${s.label} ${counts.of(s)}', tone: attendanceTone(s), icon: attendanceIcon(s)),
      if (counts.unmarked > 0) StatusChip('Not marked ${counts.unmarked}', tone: StatusTone.neutral, icon: Icons.remove_rounded),
    ],
  );
}

/// "Submit roll call?" with a summary the teacher can check at a glance. Returns true to submit.
Future<bool> confirmSubmit(BuildContext context, {required Roster roster, required StatusCounts counts, required List<RosterStudent> absent, required List<RosterStudent> late, required List<RosterStudent> halfDay, required bool resubmit}) async {
  final ok = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) {
      String names(List<RosterStudent> l) {
        final shown = l.take(10).map((s) => s.name).join(', ');
        return l.length > 10 ? '$shown and ${l.length - 10} more' : shown;
      }

      Widget group(String label, List<RosterStudent> l) => l.isEmpty
          ? const SizedBox.shrink()
          : Padding(
              padding: const EdgeInsets.only(bottom: Gaps.sm),
              child: Text.rich(TextSpan(children: [TextSpan(text: '$label (${l.length}): ', style: const TextStyle(fontWeight: FontWeight.w600)), TextSpan(text: names(l))]), style: ctx.text.bodyMedium),
            );
      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(Gaps.page, 0, Gaps.page, Gaps.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(header: true, child: Text(resubmit ? 'Submit your changes?' : 'Submit this roll call?', style: ctx.text.titleLarge)),
            const SizedBox(height: 2),
            Text('${roster.title} · ${fmtDay(roster.date)}${roster.periodName != null ? ' · ${roster.periodName}' : ''}', style: ctx.text.bodySmall),
            const SizedBox(height: Gaps.md),
            CountChips(counts: counts),
            const SizedBox(height: Gaps.md),
            group('Absent', absent),
            group('Late', late),
            group('Half day', halfDay),
            Text(
              [
                if (counts.absent > 0) 'Guardians of absent students are notified.',
                if (resubmit) 'This replaces the roll call you submitted earlier.' else 'You can still change it until the edit window closes.',
              ].join(' '),
              style: ctx.text.bodySmall?.copyWith(color: ctx.tokens.textSecondary),
            ),
            const SizedBox(height: Gaps.lg),
            Row(
              children: [
                Expanded(child: SecondaryButton(label: 'Back', onPressed: () => Navigator.pop(ctx, false))),
                const SizedBox(width: Gaps.md),
                Expanded(child: PrimaryButton(label: 'Submit', onPressed: () => Navigator.pop(ctx, true))),
              ],
            ),
          ],
        ),
      );
    },
  );
  return ok ?? false;
}
