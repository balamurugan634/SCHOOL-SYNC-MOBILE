import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/design/design.dart';
import '../../core/network/app_exception.dart';
import '../../core/paged.dart';
import '../../core/util/format.dart';
import '../../data/models/materials.dart';
import '../../data/repositories/files_repository.dart';
import '../learner/learner_context.dart';
import '../learner/screen_frame.dart';
import 'learning_providers.dart';

/// Study materials shared by teachers (files or links), searchable.
class MaterialsScreen extends ConsumerStatefulWidget {
  const MaterialsScreen({super.key});

  @override
  ConsumerState<MaterialsScreen> createState() => _MaterialsScreenState();
}

class _MaterialsScreenState extends ConsumerState<MaterialsScreen> {
  final _search = TextEditingController();
  String _q = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _open(StudyMaterial m) async {
    try {
      if (m.fileId != null) {
        await ref.read(filesRepositoryProvider).openFileId(m.fileId!, name: m.title);
      } else if (m.url != null) {
        final uri = Uri.tryParse(m.url!);
        if (uri != null && (uri.scheme == 'https' || uri.scheme == 'http')) await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppException.from(e).displayMessage)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final q = (studentId: ref.watch(learnerQueryIdProvider), q: _q);
    final provider = materialsProvider(q);
    final v = ref.watch(provider);
    Future<void> refresh() async {
      ref.invalidate(provider);
      try {
        await ref.read(provider.future);
      } catch (_) {}
    }

    return ScreenFrame(
      title: 'Study materials',
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(Gaps.page, 0, Gaps.page, Gaps.sm),
            child: TextField(controller: _search, textInputAction: TextInputAction.search, onSubmitted: (s) => setState(() => _q = s.trim()), decoration: InputDecoration(hintText: 'Search materials', prefixIcon: const Icon(Icons.search_rounded), suffixIcon: _q.isEmpty ? null : IconButton(tooltip: 'Clear', icon: const Icon(Icons.close_rounded), onPressed: () => setState(() {
              _q = '';
              _search.clear();
            })))),
          ),
          Expanded(
            child: AsyncBody<PagedList<StudyMaterial>>(
              value: v,
              onRetry: refresh,
              isEmpty: (p) => p.items.isEmpty,
              empty: EmptyState(illo: _q.isEmpty ? Illo.emptyGeneric : Illo.noResults, title: _q.isEmpty ? 'No materials yet' : 'No materials match "$_q"', message: _q.isEmpty ? 'Notes and resources from your teachers will appear here.' : null),
              data: (p) => RefreshScroll(
                onRefresh: refresh,
                children: [
                  RowGroup(
                    children: [
                      for (final m in p.items)
                        ListRow(
                          title: m.title,
                          subtitle: [m.subjectName, if (m.createdByName != null) m.createdByName!, if (m.createdAt != null) fmtShort(m.createdAt!)].join('  ·  '),
                          leading: m.fileId != null ? Icons.insert_drive_file_outlined : Icons.link_rounded,
                          trailing: const Icon(Icons.open_in_new_rounded, size: 18),
                          chevron: false,
                          onTap: () => _open(m),
                        ),
                    ],
                  ),
                  LoadMoreFooter(paged: p, onMore: () => ref.read(provider.notifier).loadMore()),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
