import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/design.dart';
import '../../core/util/format.dart';
import '../../data/models/attendance.dart';
import '../../data/models/learner_dashboard.dart';
import '../../data/models/schedule.dart';
import '../../router/routes_shared.dart';
import 'dashboard_widgets.dart' show DashCard, HomeworkRow;

// The student home, built from a few colourful, tappable blocks instead of one long list of cards:
//   UpNextCard (what is happening now) · QuickActionsGrid (what a student does) · StatsRow (three numbers)
//   TodayStrip (the day as a swipeable row) · ExamStrip · DueSoonCard · LatestNoticeCard.
// Colour comes from the theme's own palette (brand, accent and the chart hues), as a soft tint behind a strong icon,
// so it stays in step with light and dark mode. Motion is short and is skipped when the system asks for none.

bool _still(BuildContext c) => MediaQuery.maybeDisableAnimationsOf(c) ?? false;

/// A hue used as a soft tinted background plus a strong foreground, in both themes.
class _Hue {
  const _Hue(this.base);
  final Color base;
  Color soft(SchoolSyncTheme t) => Color.alphaBlend(base.withValues(alpha: t.dark ? .22 : .12), t.surface);
  Color strong(SchoolSyncTheme t) => t.dark ? Color.lerp(base, Colors.white, .4)! : base;
}

Color _onAccent(SchoolSyncTheme t) => t.dark ? const Color(0xFF1C1A17) : Colors.white;

int _minutes(String? hhmm) {
  final p = (hhmm ?? '').split(':');
  if (p.length < 2) return 0;
  return (int.tryParse(p[0]) ?? 0) * 60 + (int.tryParse(p[1]) ?? 0);
}

/// The running period / the next one: the API's own fields, or else the per-entry state of today's feed.
TimetableEntry? _currentOf(TimetableDay d) => d.current ?? d.entries.where((e) => e.state == 'current').firstOrNull;
TimetableEntry? _nextOf(TimetableDay d) => d.next ?? d.entries.where((e) => e.state == 'upcoming' && !e.isBreak).firstOrNull;

String _homeworkTasks(int n) => n == 1 ? '1 homework task' : '$n homework tasks';

IconData _subjectIcon(String? name) {
  final n = (name ?? '').toLowerCase();
  if (n.contains('math')) return Icons.calculate_rounded;
  if (n.contains('english') || n.contains('literature')) return Icons.menu_book_rounded;
  if (n.contains('hindi') || n.contains('tamil') || n.contains('language') || n.contains('sanskrit')) return Icons.translate_rounded;
  if (n.contains('science') || n.contains('physics') || n.contains('chem') || n.contains('bio')) return Icons.science_rounded;
  if (n.contains('computer') || n.contains('it')) return Icons.computer_rounded;
  if (n.contains('art') || n.contains('craft') || n.contains('draw')) return Icons.palette_rounded;
  if (n.contains('physical') || n.contains('sport') || n.contains('pe')) return Icons.sports_soccer_rounded;
  if (n.contains('social') || n.contains('history') || n.contains('geo')) return Icons.public_rounded;
  if (n.contains('music')) return Icons.music_note_rounded;
  return Icons.school_rounded;
}

/// Plays once per app session (the first time the home appears), not on every pull-to-refresh or tab switch.
class _Once {
  static final Set<String> _seen = {};
  static bool first(String key) => _seen.add(key);
}

// ── what is happening now ──────────────────────────────────────────────────────────────────────

class UpNextCard extends StatefulWidget {
  const UpNextCard({super.key, required this.day, required this.pendingHomework});
  final TimetableDay? day;
  final int pendingHomework;

  @override
  State<UpNextCard> createState() => _UpNextCardState();
}

class _UpNextCardState extends State<UpNextCard> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1300));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_still(context)) {
      _pulse.stop();
    } else if (!_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final d = widget.day;
    final now = appNow();
    final nowMin = now.hour * 60 + now.minute;
    final current = d == null ? null : _currentOf(d);
    final next = d == null ? null : _nextOf(d);

    late final String tag;
    late final String title;
    late final String sub;
    late final IconData icon;
    double? progress;
    var live = false;

    if (d == null || !d.isWorkingDay || d.entries.isEmpty) {
      tag = d != null && !d.isWorkingDay ? 'NO SCHOOL' : 'TODAY';
      title = d != null && !d.isWorkingDay ? 'Enjoy your day off' : 'No classes today';
      sub = widget.pendingHomework > 0 ? '${_homeworkTasks(widget.pendingHomework)} still to do' : 'Nothing is due. You are all caught up.';
      icon = Icons.wb_sunny_rounded;
    } else if (current != null) {
      live = true;
      tag = 'NOW';
      title = current.subjectName ?? current.periodName;
      sub = [formatTimeRange(current.startTime, current.endTime), if (current.room != null) 'Room ${current.room}', if (current.teacherName != null) current.teacherName!].join('  ·  ');
      icon = current.isBreak ? Icons.free_breakfast_rounded : _subjectIcon(current.subjectName);
      final s = _minutes(current.startTime), e = _minutes(current.endTime);
      progress = e > s ? ((nowMin - s) / (e - s)).clamp(0.0, 1.0) : null;
    } else if (next != null) {
      tag = 'NEXT';
      title = next.subjectName ?? next.periodName;
      final mins = _minutes(next.startTime) - nowMin;
      final when = mins > 0 && mins < 180 ? 'Starts in ${mins >= 60 ? '${mins ~/ 60} h ${mins % 60} min' : '$mins min'}' : 'At ${formatClock(next.startTime)}';
      sub = [when, if (next.room != null) 'Room ${next.room}'].join('  ·  ');
      icon = next.isBreak ? Icons.free_breakfast_rounded : _subjectIcon(next.subjectName);
    } else {
      tag = 'DONE';
      title = 'That is all for today';
      sub = widget.pendingHomework > 0 ? '${_homeworkTasks(widget.pendingHomework)} to do this evening' : 'No homework due. Well done!';
      icon = Icons.celebration_rounded;
    }

    final on = t.brand.onSolid;
    return Material(
      color: t.brand.solid,
      borderRadius: BorderRadius.circular(Radii.xl),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push(SharedRoutes.timetable),
        child: Stack(
          children: [
            // quiet flat shapes, no gradients
            Positioned(right: -34, top: -38, child: Container(width: 150, height: 150, decoration: BoxDecoration(shape: BoxShape.circle, color: on.withValues(alpha: .07)))),
            Positioned(right: 58, bottom: -46, child: Container(width: 84, height: 84, decoration: BoxDecoration(shape: BoxShape.circle, color: on.withValues(alpha: .06)))),
            Padding(
              padding: const EdgeInsets.all(Gaps.lg),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _TagPill(tag: tag, live: live, pulse: _pulse, on: on, t: t),
                        const SizedBox(height: Gaps.md),
                        Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: context.text.headlineSmall?.copyWith(color: on, height: 1.15)),
                        const SizedBox(height: 4),
                        Text(sub, maxLines: 2, overflow: TextOverflow.ellipsis, style: context.text.bodyMedium?.copyWith(color: on.withValues(alpha: .86))),
                        if (progress != null) ...[
                          const SizedBox(height: Gaps.md),
                          TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0, end: progress),
                            duration: _still(context) ? Duration.zero : const Duration(milliseconds: 900),
                            curve: Curves.easeOutCubic,
                            builder: (_, v, _) => ClipRRect(
                              borderRadius: BorderRadius.circular(3),
                              child: LinearProgressIndicator(value: v, minHeight: 6, backgroundColor: on.withValues(alpha: .24), color: on),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: Gaps.md),
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(color: on.withValues(alpha: .16), borderRadius: BorderRadius.circular(18)),
                    child: Icon(icon, size: 30, color: on),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TagPill extends StatelessWidget {
  const _TagPill({required this.tag, required this.live, required this.pulse, required this.on, required this.t});
  final String tag;
  final bool live;
  final Animation<double> pulse;
  final Color on;
  final SchoolSyncTheme t;

  @override
  Widget build(BuildContext context) {
    final bg = live ? t.accent : on.withValues(alpha: .18);
    final fg = live ? _onAccent(t) : on;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (live) ...[
            AnimatedBuilder(
              animation: pulse,
              builder: (_, _) => Container(width: 7, height: 7, decoration: BoxDecoration(shape: BoxShape.circle, color: fg.withValues(alpha: .45 + .55 * pulse.value))),
            ),
            const SizedBox(width: 6),
          ],
          Text(tag, style: context.text.labelSmall?.copyWith(color: fg, fontWeight: FontWeight.w700, letterSpacing: .6)),
        ],
      ),
    );
  }
}

// ── quick actions ──────────────────────────────────────────────────────────────────────────────

class QuickAction {
  const QuickAction({required this.icon, required this.label, required this.color, required this.onTap, this.badge = 0});
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  /// Shown as a small count on the icon (for example homework still to do).
  final int badge;
}

class QuickActionsGrid extends StatelessWidget {
  const QuickActionsGrid({super.key, required this.actions, this.animate = true});
  final List<QuickAction> actions;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final play = animate && !_still(context) && _Once.first('quick-actions');
    // rows of four that size themselves, so larger system text never overflows a fixed tile height
    return Column(
      children: [
        for (var r = 0; r * 4 < actions.length; r++) ...[
          if (r > 0) const SizedBox(height: Gaps.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var c = 0; c < 4; c++) ...[
                if (c > 0) const SizedBox(width: Gaps.xs),
                Expanded(child: r * 4 + c < actions.length ? _PopIn(index: r * 4 + c, play: play, child: _QuickTile(action: actions[r * 4 + c])) : const SizedBox.shrink()),
              ],
            ],
          ),
        ],
      ],
    );
  }
}

class _PopIn extends StatelessWidget {
  const _PopIn({required this.index, required this.play, required this.child});
  final int index;
  final bool play;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!play) return child;
    final delay = 40 * index;
    final total = 300 + delay;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: total),
      curve: Interval(delay / total, 1, curve: Curves.easeOutBack),
      builder: (_, v, child) => Opacity(opacity: v.clamp(0.0, 1.0), child: Transform.scale(scale: .8 + .2 * v, child: child)),
      child: child,
    );
  }
}

class _QuickTile extends StatefulWidget {
  const _QuickTile({required this.action});
  final QuickAction action;

  @override
  State<_QuickTile> createState() => _QuickTileState();
}

class _QuickTileState extends State<_QuickTile> {
  bool _down = false;

  void _set(bool v) {
    if (_down != v && mounted) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final a = widget.action;
    final hue = _Hue(a.color);
    return Semantics(
      button: true,
      label: a.badge > 0 ? '${a.label}, ${a.badge}' : a.label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _set(true),
        onTapCancel: () => _set(false),
        onTapUp: (_) => _set(false),
        onTap: a.onTap,
        child: AnimatedScale(
          scale: _down ? .92 : 1,
          duration: Motion.press,
          child: Column(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(color: hue.soft(t), borderRadius: BorderRadius.circular(18)),
                    child: Icon(a.icon, size: 27, color: hue.strong(t)),
                  ),
                  if (a.badge > 0)
                    Positioned(
                      right: -5,
                      top: -5,
                      child: Container(
                        constraints: const BoxConstraints(minWidth: 20),
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(color: t.accent, borderRadius: BorderRadius.circular(999), border: Border.all(color: t.bg, width: 2)),
                        child: Text(a.badge > 99 ? '99+' : '${a.badge}', textAlign: TextAlign.center, style: context.text.labelSmall?.copyWith(color: _onAccent(t), fontWeight: FontWeight.w700, fontSize: 11, height: 1.25)),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 7),
              Text(a.label, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: context.text.labelMedium?.copyWith(fontWeight: FontWeight.w500, height: 1.15, color: t.text)),
            ],
          ),
        ),
      ),
    );
  }
}

/// The rest of the destinations, in a sheet, so the home itself stays short.
Future<void> showMoreActions(BuildContext context, List<QuickAction> actions) => showModalBottomSheet<void>(
  context: context,
  useSafeArea: true,
  showDragHandle: true,
  isScrollControlled: true,
  builder: (sheet) => SingleChildScrollView(
    padding: const EdgeInsets.fromLTRB(Gaps.page, 0, Gaps.page, Gaps.xxl),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('More', style: sheet.text.headlineSmall),
        const SizedBox(height: Gaps.lg),
        QuickActionsGrid(
          animate: false,
          actions: [
            for (final a in actions)
              QuickAction(
                icon: a.icon,
                label: a.label,
                color: a.color,
                badge: a.badge,
                onTap: () {
                  Navigator.of(sheet).pop();
                  a.onTap();
                },
              ),
          ],
        ),
      ],
    ),
  ),
);

// ── three numbers ──────────────────────────────────────────────────────────────────────────────

class StatsRow extends StatelessWidget {
  const StatsRow({super.key, required this.attendance, required this.today, required this.homework, required this.tasks, required this.overdueTasks});
  final AttendanceSummary? attendance;
  final AttendanceStatus? today;
  final HomeworkSnapshot homework;
  final int tasks;
  final int overdueTasks;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final pct = attendance?.totals.percentage;
    final short = attendance?.isShort ?? false;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _StatCard(
              hue: _Hue(short ? t.warning : t.chart[5]),
              onTap: () => context.push(SharedRoutes.attendance),
              semantic: 'Attendance ${pct == null ? 'not available' : '${pct.round()} percent'}',
              top: _Ring(value: pct == null ? 0 : (pct / 100).clamp(0.0, 1.0), label: pct == null ? '-' : '${pct.round()}%', hue: _Hue(short ? t.warning : t.chart[5])),
              label: 'Attendance',
              foot: today == null ? 'Not marked yet' : '${today!.label} today',
            ),
          ),
          const SizedBox(width: Gaps.sm),
          Expanded(
            child: _StatCard(
              hue: _Hue(t.chart[2]),
              onTap: () => context.push(SharedRoutes.homework),
              semantic: '${homework.pendingCount} homework to do',
              top: Text('${homework.pendingCount}', style: figureStyle(context, size: 34, color: _Hue(t.chart[2]).strong(t))),
              label: 'Homework',
              foot: homework.overdueCount > 0 ? '${homework.overdueCount} overdue' : 'On track',
              footColor: homework.overdueCount > 0 ? t.danger : null,
            ),
          ),
          const SizedBox(width: Gaps.sm),
          Expanded(
            child: _StatCard(
              hue: _Hue(t.chart[4]),
              onTap: () => context.go('/tab/1'),
              semantic: '$tasks open tasks',
              top: Text('$tasks', style: figureStyle(context, size: 34, color: _Hue(t.chart[4]).strong(t))),
              label: 'My tasks',
              foot: overdueTasks > 0 ? '$overdueTasks overdue' : 'Open',
              footColor: overdueTasks > 0 ? t.danger : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.hue, required this.onTap, required this.semantic, required this.top, required this.label, required this.foot, this.footColor});
  final _Hue hue;
  final VoidCallback onTap;
  final String semantic;
  final Widget top;
  final String label;
  final String foot;
  final Color? footColor;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Semantics(
      button: true,
      label: semantic,
      excludeSemantics: true,
      child: Material(
        color: hue.soft(t),
        borderRadius: BorderRadius.circular(Radii.xl),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(Gaps.md, Gaps.md, Gaps.md, Gaps.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 52, child: Align(alignment: Alignment.centerLeft, child: top)),
                const SizedBox(height: 6),
                Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.text.labelLarge?.copyWith(color: t.text, fontWeight: FontWeight.w600)),
                Text(foot, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.text.labelSmall?.copyWith(color: footColor ?? t.textSecondary)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Ring extends StatelessWidget {
  const _Ring({required this.value, required this.label, required this.hue});
  final double value;
  final String label;
  final _Hue hue;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value),
      duration: _still(context) ? Duration.zero : const Duration(milliseconds: 1000),
      curve: Curves.easeOutCubic,
      builder: (_, v, _) => SizedBox(
        width: 52,
        height: 52,
        child: CustomPaint(
          painter: _RingPainter(v, hue.strong(t), hue.base.withValues(alpha: t.dark ? .25 : .18)),
          child: Center(child: Text(label, style: context.text.labelSmall?.copyWith(color: t.text, fontWeight: FontWeight.w700, fontSize: 10.5))),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.value, this.color, this.track);
  final double value;
  final Color color;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 5.5;
    final r = (math.min(size.width, size.height) - stroke) / 2;
    final c = size.center(Offset.zero);
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(c, r, p..color = track);
    if (value > 0) canvas.drawArc(Rect.fromCircle(center: c, radius: r), -math.pi / 2, 2 * math.pi * value, false, p..color = color);
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.value != value || old.color != color || old.track != track;
}

// ── the day as a row ───────────────────────────────────────────────────────────────────────────

class TodayStrip extends StatefulWidget {
  const TodayStrip({super.key, required this.day});
  final TimetableDay? day;

  @override
  State<TodayStrip> createState() => _TodayStripState();
}

class _TodayStripState extends State<TodayStrip> {
  static const _lesson = 132.0, _brk = 92.0, _gap = 8.0;
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focusNow());
  }

  void _focusNow() {
    final d = widget.day;
    if (d == null || !_scroll.hasClients) return;
    var offset = 0.0;
    for (final e in d.entries) {
      if (e.state == 'current' || (_currentOf(d) == null && _nextOf(d) != null && e.ordinal == _nextOf(d)!.ordinal)) break;
      offset += (e.isBreak ? _brk : _lesson) + _gap;
    }
    _scroll.jumpTo(offset.clamp(0.0, _scroll.position.maxScrollExtent));
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.day;
    if (d == null || !d.isWorkingDay || d.entries.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text('Today’s classes', style: context.text.titleMedium)),
            TextButton(onPressed: () => context.push(SharedRoutes.timetable), style: TextButton.styleFrom(visualDensity: VisualDensity.compact), child: const Text('Full timetable')),
          ],
        ),
        const SizedBox(height: Gaps.xs),
        SizedBox(
          height: 100 * MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.7), // grows with the system text size
          child: ListView.separated(
            controller: _scroll,
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none, // let the row run to the screen edge instead of stopping at the page margin
            physics: const BouncingScrollPhysics(),
            itemCount: d.entries.length,
            separatorBuilder: (_, _) => const SizedBox(width: _gap),
            itemBuilder: (_, i) => _LessonChip(entry: d.entries[i], isNext: _currentOf(d) == null && _nextOf(d) != null && d.entries[i].ordinal == _nextOf(d)!.ordinal),
          ),
        ),
      ],
    );
  }
}

class _LessonChip extends StatelessWidget {
  const _LessonChip({required this.entry, required this.isNext});
  final TimetableEntry entry;
  final bool isNext;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final e = entry;
    final current = e.state == 'current';
    final past = e.state == 'past';

    if (e.isBreak) {
      final lunch = e.periodName.toLowerCase().contains('lunch');
      return Container(
        width: _TodayStripState._brk,
        padding: const EdgeInsets.all(Gaps.md),
        decoration: BoxDecoration(color: t.subtle, borderRadius: BorderRadius.circular(Radii.xl)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(formatClock(e.startTime), style: context.text.labelSmall?.copyWith(color: t.textSecondary)),
            Icon(lunch ? Icons.restaurant_rounded : Icons.free_breakfast_rounded, size: 20, color: t.textTertiary),
            Text(e.periodName, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.text.labelMedium?.copyWith(color: t.textSecondary)),
          ],
        ),
      );
    }

    final hue = _Hue(t.chart[(e.ordinal.abs()) % 6]);
    final bg = current ? t.brand.solid : (isNext ? t.brand.soft : t.surface);
    final fg = current ? t.brand.onSolid : t.text;
    final fg2 = current ? t.brand.onSolid.withValues(alpha: .85) : t.textSecondary;
    return Opacity(
      opacity: past ? .6 : 1,
      child: Container(
        width: _TodayStripState._lesson,
        padding: const EdgeInsets.all(Gaps.md),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(Radii.xl),
          border: current ? null : Border.all(color: isNext ? t.brand.solid.withValues(alpha: .4) : t.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Expanded(child: Text(formatClock(e.startTime), style: context.text.labelSmall?.copyWith(color: fg2, fontFeatures: const [FontFeature.tabularFigures()]))),
                SizedBox(
                  height: 18,
                  child: current
                      ? Center(child: Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: t.accent)))
                      : Icon(past ? Icons.check_circle_rounded : _subjectIcon(e.subjectName), size: 16, color: past ? t.success : hue.strong(t)),
                ),
              ],
            ),
            Text(e.subjectName ?? e.periodName, maxLines: 2, overflow: TextOverflow.ellipsis, style: context.text.titleSmall?.copyWith(color: fg, fontWeight: FontWeight.w600, height: 1.15)),
            Text(e.room == null ? (e.teacherName ?? '') : 'Room ${e.room}', maxLines: 1, overflow: TextOverflow.ellipsis, style: context.text.labelSmall?.copyWith(color: fg2)),
          ],
        ),
      ),
    );
  }
}

// ── one reminder, one due list, one notice ─────────────────────────────────────────────────────

class ExamStrip extends StatelessWidget {
  const ExamStrip({super.key, required this.exams});
  final List<DashboardExam> exams;

  @override
  Widget build(BuildContext context) {
    if (exams.isEmpty) return const SizedBox.shrink();
    final t = context.tokens;
    final e = exams.first;
    final hue = _Hue(t.chart[3]);
    final when = [if (e.date != null) relativeDay(e.date!), if (e.startTime != null) formatClock(e.startTime), if (e.room != null) e.room!].join('  ·  ');
    return Material(
      color: hue.soft(t),
      borderRadius: BorderRadius.circular(Radii.xl),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push(SharedRoutes.exams),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: Gaps.lg, vertical: Gaps.md),
          child: Row(
            children: [
              Icon(Icons.quiz_rounded, color: hue.strong(t), size: 26),
              const SizedBox(width: Gaps.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Next exam · ${e.subject}', maxLines: 1, overflow: TextOverflow.ellipsis, style: context.text.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                    Text(when, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.text.bodySmall?.copyWith(color: t.textSecondary)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: t.textTertiary),
            ],
          ),
        ),
      ),
    );
  }
}

class DueSoonCard extends StatelessWidget {
  const DueSoonCard({super.key, required this.snapshot});
  final HomeworkSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final items = snapshot.items.take(2).toList();
    return DashCard(
      title: 'Due soon',
      action: 'All homework',
      onAction: () => context.push(SharedRoutes.homework),
      padding: EdgeInsets.zero,
      child: items.isEmpty
          ? Padding(
              padding: const EdgeInsets.fromLTRB(Gaps.lg, 0, Gaps.lg, Gaps.md),
              child: Row(children: [Icon(Icons.check_circle_rounded, color: t.success, size: 20), const SizedBox(width: 8), Expanded(child: Text('Nothing is due. You are all caught up.', style: context.text.bodyMedium?.copyWith(color: t.textSecondary)))]),
            )
          : Column(children: [for (final h in items) HomeworkRow(h, compact: true)]),
    );
  }
}

class LatestNoticeCard extends StatelessWidget {
  const LatestNoticeCard({super.key, required this.snapshot});
  final AnnouncementsSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    if (snapshot.latest.isEmpty) return const SizedBox.shrink();
    final t = context.tokens;
    final a = snapshot.latest.first;
    final hue = _Hue(a.urgent ? t.danger : t.accent);
    return Material(
      color: t.surface,
      borderRadius: BorderRadius.circular(Radii.xl),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push(SharedRoutes.announcementDetail(a.id)),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: Gaps.lg, vertical: Gaps.md),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(Radii.xl), border: Border.all(color: t.border)),
          child: Row(
            children: [
              Container(width: 40, height: 40, decoration: BoxDecoration(color: hue.soft(t), borderRadius: BorderRadius.circular(12)), child: Icon(Icons.campaign_rounded, color: hue.strong(t), size: 22)),
              const SizedBox(width: Gaps.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(a.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.text.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                    Text(snapshot.unreadCount > 1 ? '${snapshot.unreadCount} unread announcements' : a.body.replaceAll(RegExp(r'\s+'), ' '), maxLines: 1, overflow: TextOverflow.ellipsis, style: context.text.bodySmall?.copyWith(color: t.textSecondary)),
                  ],
                ),
              ),
              const SizedBox(width: Gaps.sm),
              if (snapshot.unreadCount > 0) StatusChip('${snapshot.unreadCount} new', tone: StatusTone.accent) else Icon(Icons.chevron_right_rounded, color: t.textTertiary),
            ],
          ),
        ),
      ),
    );
  }
}
