import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/design.dart';
import '../../../core/util/format.dart';
import '../../../router/routes_teacher.dart';
import '../../workspace/workspace.dart';
import 'classes_providers.dart';

/// The sections I teach or lead (Classes tab). Tap a class for its students, syllabus coverage and attendance.
class ClassesScreen extends ConsumerWidget {
  const ClassesScreen({super.key, this.embedded = true});
  final bool embedded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(myClassesProvider);
    Future<void> refresh() async {
      ref.invalidate(myClassesProvider);
      try {
        await ref.read(myClassesProvider.future);
      } catch (_) {}
    }

    return StaffFrame(
      title: 'My Classes',
      subtitle: 'The sections you teach, with their students.',
      embedded: embedded,
      body: AsyncBody<List<MyClass>>(
        value: value,
        onRetry: () => ref.invalidate(myClassesProvider),
        isEmpty: (l) => l.isEmpty,
        empty: const EmptyState(illo: Illo.emptyGeneric, title: 'No classes assigned yet', message: 'When the office assigns you to a class or a subject, it appears here.'),
        data: (classes) => RefreshOnFocus(
          onRefresh: () => ref.invalidate(myClassesProvider),
          child: RefreshScroll(
            onRefresh: refresh,
            children: [
              const ReadOnlyBanner(),
              for (final c in classes) Padding(padding: const EdgeInsets.only(bottom: Gaps.sm), child: _ClassCard(c)),
            ],
          ),
        ),
      ),
    );
  }
}

class _ClassCard extends StatelessWidget {
  const _ClassCard(this.c);
  final MyClass c;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final s = c.section;
    final detail = [plural(s.studentCount, 'student'), if (s.room != null && s.room!.isNotEmpty) 'Room ${s.room}'].join('  ·  ');
    return AppCard(
      onTap: () => context.push(TeacherRoutes.section(s.id)),
      semanticLabel: '${s.title}. $detail. ${c.leads ? 'You are the class teacher. ' : ''}${c.subjects.isEmpty ? '' : 'You teach ${c.subjects.join(', ')}.'}',
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // A Wrap: at 200% text the chip drops under the class name instead of overflowing.
                Wrap(
                  spacing: Gaps.sm,
                  runSpacing: Gaps.xs,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(s.title, style: context.text.titleMedium),
                    if (c.leads) const StatusChip('Class teacher', tone: StatusTone.brand, icon: Icons.verified_outlined),
                  ],
                ),
                const SizedBox(height: 2),
                Text(detail, style: context.text.bodySmall),
                if (c.subjects.isNotEmpty) Padding(padding: const EdgeInsets.only(top: Gaps.xs), child: Text(c.subjects.join(', '), style: context.text.bodyMedium?.copyWith(color: t.textSecondary))),
                if (!c.leads && s.classTeacherName != null) Padding(padding: const EdgeInsets.only(top: 2), child: Text('Class teacher: ${s.classTeacherName}', style: context.text.bodySmall)),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: t.textTertiary),
        ],
      ),
    );
  }
}
