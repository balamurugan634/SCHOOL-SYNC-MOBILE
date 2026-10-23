import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design/design.dart';
import '../../core/providers.dart';
import '../../data/models/me.dart';
import '../auth/session.dart';

/// Parent only: which linked child the screens are about.
class SelectedChild extends Notifier<String?> {
  @override
  String? build() {
    final children = ref.watch(sessionProvider.select((s) => s.me?.profile.children)) ?? const [];
    final saved = ref.read(prefsProvider).selectedChild;
    if (saved != null && children.any((c) => c.studentId == saved)) return saved;
    return children.isEmpty ? null : children.first.studentId;
  }

  Future<void> select(String studentId) async {
    state = studentId;
    await ref.read(prefsProvider).setSelectedChild(studentId);
  }
}

final selectedChildIdProvider = NotifierProvider<SelectedChild, String?>(SelectedChild.new);

/// The currently selected child (or null when none are linked yet).
final selectedChildProvider = Provider<LinkedChild?>((ref) {
  final id = ref.watch(selectedChildIdProvider);
  final children = ref.watch(sessionProvider.select((s) => s.me?.profile.children)) ?? const [];
  for (final c in children) {
    if (c.studentId == id) return c;
  }
  return null;
});

/// Horizontal switcher of linked children: outlined chips, the selected one in brand tint.
class ChildSelector extends ConsumerWidget {
  const ChildSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final children = ref.watch(sessionProvider.select((s) => s.me?.profile.children)) ?? const [];
    final selected = ref.watch(selectedChildIdProvider);
    final t = context.tokens;
    if (children.isEmpty) {
      return const Padding(padding: EdgeInsets.symmetric(horizontal: Gaps.page), child: Align(alignment: Alignment.centerLeft, child: StatusChip('No children linked yet', tone: StatusTone.warning)));
    }
    // The chips keep up to 130% text size; the strip grows with it instead of clipping.
    final scale = MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.3).scale(14) / 14;
    return SizedBox(
      height: 52 * scale.clamp(1.0, 1.3),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: Gaps.page),
        itemCount: children.length,
        separatorBuilder: (_, _) => const SizedBox(width: Gaps.sm),
        itemBuilder: (_, i) {
          final child = children[i];
          final isSel = child.studentId == selected;
          return Semantics(
            selected: isSel,
            button: true,
            label: 'Show ${child.name}',
            child: InkWell(
              borderRadius: Radii.field,
              onTap: () => ref.read(selectedChildIdProvider.notifier).select(child.studentId),
              child: AnimatedContainer(
                duration: Motion.fast,
                padding: const EdgeInsets.fromLTRB(8, 6, 14, 6),
                decoration: BoxDecoration(
                  color: isSel ? t.brand.tint : t.surface,
                  borderRadius: Radii.field,
                  border: Border.all(color: isSel ? t.brand.solid.withValues(alpha: .5) : t.border),
                ),
                child: MediaQuery.withClampedTextScaling(
                  maxScaleFactor: 1.3,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      UserAvatar(name: child.name, url: child.photoUrl, size: 32),
                      const SizedBox(width: 8),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(child.firstName, style: context.text.labelLarge?.copyWith(color: isSel ? t.brand.solid : t.text, height: 1.1)),
                          Text(child.classLabel, style: context.text.labelSmall?.copyWith(color: t.textSecondary, height: 1.2)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
