import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design/design.dart';
import '../../core/util/format.dart';
import '../../data/models/learner_extras.dart';
import '../auth/session.dart';
import '../learner/screen_frame.dart';
import 'learning_providers.dart';

/// Books on loan, with due dates and any fine.
class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = ref.watch(libraryLoansProvider);
    final currency = ref.watch(sessionProvider.select((s) => s.siteInfo?.currency ?? 'INR'));
    Future<void> refresh() async {
      ref.invalidate(libraryLoansProvider);
      try {
        await ref.read(libraryLoansProvider.future);
      } catch (_) {}
    }

    return ScreenFrame(
      title: 'Library',
      body: AsyncBody<List<LibraryLoan>>(
        value: v,
        onRetry: refresh,
        isEmpty: (l) => l.isEmpty,
        empty: const EmptyState(illo: Illo.emptyGeneric, title: 'No books on loan', message: 'Books borrowed from the school library appear here.'),
        data: (loans) => RefreshScroll(
          onRefresh: refresh,
          children: [
            RowGroup(
              children: [
                for (final l in loans)
                  ListRow(
                    title: l.title,
                    subtitle: [if (l.author != null) l.author!, if (l.dueOn != null) 'Due ${fmtShort(l.dueOn!)}'].join('  ·  '),
                    leading: Icons.menu_book_outlined,
                    chevron: false,
                    trailing: l.overdue ? Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.end, children: [StatusChip('${plural(l.daysOverdue, 'day')} late', tone: StatusTone.danger), if (l.fineMinor > 0) Text('Fine ${formatMinor(l.fineMinor, currency: currency)}', style: context.text.labelSmall)]) : (l.returnedOn != null ? const StatusChip('Returned') : null),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
