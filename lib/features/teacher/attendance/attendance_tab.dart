import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/design.dart';
import '../../workspace/workspace.dart';
import 'history_section.dart';
import 'requests_section.dart';
import 'today_section.dart';

/// The Attendance tab: Today (take attendance), History (earlier roll calls and per-student percentages),
/// Requests (corrections and student leave). Segments load when first opened and keep their place.
class TeacherAttendanceTab extends ConsumerStatefulWidget {
  const TeacherAttendanceTab({super.key});

  @override
  ConsumerState<TeacherAttendanceTab> createState() => _TeacherAttendanceTabState();
}

class _TeacherAttendanceTabState extends ConsumerState<TeacherAttendanceTab> {
  int _index = 0;
  final _opened = <int>{0};

  @override
  Widget build(BuildContext context) {
    return FeatureGate(
      label: 'Attendance',
      anyPermission: const ['attendance:create', 'attendance:view'],
      child: StaffFrame(
        title: 'Attendance',
        subtitle: 'Mark attendance in seconds.',
        embedded: true,
        headerExtra: Padding(
          padding: const EdgeInsets.only(bottom: Gaps.sm),
          child: FilterChips<int>(
            options: const [0, 1, 2],
            selected: _index,
            labelOf: (i) => const ['Today', 'History', 'Requests'][i],
            onSelected: (i) => setState(() {
              _index = i;
              _opened.add(i);
            }),
          ),
        ),
        body: IndexedStack(
          index: _index,
          sizing: StackFit.expand,
          children: [
            _opened.contains(0) ? const TodaySection() : const SizedBox.shrink(),
            _opened.contains(1) ? const HistorySection() : const SizedBox.shrink(),
            _opened.contains(2) ? const RequestsSection() : const SizedBox.shrink(),
          ],
        ),
      ),
    );
  }
}
