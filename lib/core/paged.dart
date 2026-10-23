import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/json.dart';
import 'design/design.dart';

/// Items loaded so far from a page-numbered list endpoint (`{ data, meta }`).
class PagedList<T> {
  const PagedList(this.items, this.meta, {this.loadingMore = false, this.loadMoreError});
  final List<T> items;
  final PageMeta meta;
  final bool loadingMore;
  final Object? loadMoreError;

  bool get hasMore => meta.hasMore;
  int get total => meta.total;

  PagedList<T> copyWith({List<T>? items, PageMeta? meta, bool? loadingMore, Object? loadMoreError, bool clearError = false}) =>
      PagedList(items ?? this.items, meta ?? this.meta, loadingMore: loadingMore ?? this.loadingMore, loadMoreError: clearError ? null : (loadMoreError ?? this.loadMoreError));
}

/// Base class for an infinite list: subclass it, implement [fetch], and expose it with
/// `AsyncNotifierProvider.family<Sub, PagedList<T>, Arg>(Sub.new)`.
abstract class PagedNotifier<T, A> extends AsyncNotifier<PagedList<T>> {
  PagedNotifier(this.arg);
  final A arg;

  Future<Paged<T>> fetch(int page);

  @override
  Future<PagedList<T>> build() async {
    final p = await fetch(1);
    return PagedList(p.items, p.meta);
  }

  Future<void> loadMore() async {
    final cur = state.value;
    if (cur == null || !cur.hasMore || cur.loadingMore) return;
    state = AsyncData(cur.copyWith(loadingMore: true, clearError: true));
    try {
      final p = await fetch(cur.meta.page + 1);
      state = AsyncData(PagedList([...cur.items, ...p.items], p.meta));
    } catch (e) {
      state = AsyncData(cur.copyWith(loadingMore: false, loadMoreError: e));
    }
  }
}

/// "Load more" row at the end of a paged list.
class LoadMoreFooter extends StatelessWidget {
  const LoadMoreFooter({super.key, required this.paged, required this.onMore});
  final PagedList<dynamic> paged;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    if (!paged.hasMore) return const SizedBox(height: Gaps.sm);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Gaps.md),
      child: Center(
        child: paged.loadingMore
            ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.2))
            : TextButton(onPressed: onMore, child: Text(paged.loadMoreError != null ? 'Could not load more. Try again' : 'Load more (${paged.total - paged.items.length} left)')),
      ),
    );
  }
}

/// Items loaded so far from a cursor-paginated endpoint (`{ data, nextCursor }`).
class CursorList<T> {
  const CursorList(this.items, this.nextCursor, {this.loadingMore = false, this.loadMoreError});
  final List<T> items;
  final String? nextCursor;
  final bool loadingMore;
  final Object? loadMoreError;
  bool get hasMore => nextCursor != null;
}

/// Base class for an infinite cursor list (attendance history, notifications).
abstract class CursorNotifier<T, A> extends AsyncNotifier<CursorList<T>> {
  CursorNotifier(this.arg);
  final A arg;

  Future<CursorPage<T>> fetch(String? cursor);

  @override
  Future<CursorList<T>> build() async {
    final p = await fetch(null);
    return CursorList(p.items, p.nextCursor);
  }

  Future<void> loadMore() async {
    final cur = state.value;
    if (cur == null || !cur.hasMore || cur.loadingMore) return;
    state = AsyncData(CursorList(cur.items, cur.nextCursor, loadingMore: true));
    try {
      final p = await fetch(cur.nextCursor);
      state = AsyncData(CursorList([...cur.items, ...p.items], p.nextCursor));
    } catch (e) {
      state = AsyncData(CursorList(cur.items, cur.nextCursor, loadMoreError: e));
    }
  }

  /// Local edit (mark read, delete) without refetching.
  void edit(List<T> Function(List<T> items) change) {
    final cur = state.value;
    if (cur == null) return;
    state = AsyncData(CursorList(change(cur.items), cur.nextCursor));
  }
}

/// "Load more" row for a [CursorList].
class CursorFooter extends StatelessWidget {
  const CursorFooter({super.key, required this.list, required this.onMore});
  final CursorList<dynamic> list;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    if (!list.hasMore) return const SizedBox(height: Gaps.sm);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Gaps.md),
      child: Center(
        child: list.loadingMore
            ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.2))
            : TextButton(onPressed: onMore, child: Text(list.loadMoreError != null ? 'Could not load more. Try again' : 'Load more')),
      ),
    );
  }
}
