import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schoolsync/core/design/design.dart';
import 'package:schoolsync/core/network/app_exception.dart';
import 'package:schoolsync/core/paged.dart';
import 'package:schoolsync/core/providers.dart';
import 'package:schoolsync/core/storage/prefs.dart';
import 'package:schoolsync/data/json.dart';
import 'package:schoolsync/data/models/me.dart';
import 'package:schoolsync/data/models/site_info.dart';
import 'package:schoolsync/features/auth/session.dart';
import 'package:schoolsync/features/home/child_selector.dart';
import 'package:schoolsync/features/learner/learner_context.dart';
import 'package:schoolsync/features/shell/role_nav.dart';
import 'package:schoolsync/features/shell/tab_screen.dart';
import 'package:schoolsync/router/role_modules.dart';
import 'package:shared_preferences/shared_preferences.dart';

Me _me(String role, {Map<String, dynamic>? patch}) {
  final j = (jsonDecode(File('test/fixtures/me_$role.json').readAsStringSync()) as Map).cast<String, dynamic>();
  return Me.fromJson({...j, ...?patch});
}

class _FixedSession extends SessionController {
  _FixedSession(this.value);
  final AppSession value;
  @override
  AppSession build() => value;
}

const _info = SiteInfo(code: 'demo', name: 'Demo School', primaryColor: '#0E5A63');

Future<ProviderContainer> _container(AppSession session) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = AppPrefs(await SharedPreferences.getInstance());
  final c = ProviderContainer(overrides: [prefsProvider.overrideWithValue(prefs), sessionProvider.overrideWith(() => _FixedSession(session))]);
  addTearDown(c.dispose);
  return c;
}

// ---------------------------------------------------------------------------------------------

class _Numbers extends PagedNotifier<int, int> {
  _Numbers(super.arg);
  static final calls = <int>[];
  static bool failNext = false;

  @override
  Future<Paged<int>> fetch(int page) async {
    calls.add(page);
    if (failNext && page > 1) {
      failNext = false;
      throw const AppException(kind: ErrorKind.network, code: 'NETWORK', message: 'offline');
    }
    return Paged([for (var i = 0; i < 2; i++) (page - 1) * 2 + i], PageMeta(page: page, pageSize: 2, total: 5, totalPages: 3));
  }
}

final _numbers = AsyncNotifierProvider.family<_Numbers, PagedList<int>, int>(_Numbers.new);

class _Cursored extends CursorNotifier<String, int> {
  _Cursored(super.arg);
  @override
  Future<CursorPage<String>> fetch(String? cursor) async => switch (cursor) {
    null => const CursorPage(['a', 'b'], 'c1'),
    'c1' => const CursorPage(['c'], null),
    _ => throw StateError('bad cursor'),
  };
}

final _cursored = AsyncNotifierProvider.family<_Cursored, CursorList<String>, int>(_Cursored.new);

void main() {
  group('whose data a screen shows', () {
    test('a student sees themselves and never sends studentId', () async {
      final me = _me('student');
      final c = await _container(AppSession(auth: AuthStatus.signedIn, me: me, siteInfo: _info));
      expect(c.read(isParentProvider), isFalse);
      expect(c.read(learnerStudentIdProvider), me.profile.studentId);
      expect(c.read(learnerQueryIdProvider), isNull);
      expect(c.read(learnerNameProvider), me.displayName);
    });

    test('a parent sees the selected child and every request carries studentId', () async {
      final me = _me('parent');
      final c = await _container(AppSession(auth: AuthStatus.signedIn, me: me, siteInfo: _info));
      final child = me.profile.children.first;
      expect(c.read(isParentProvider), isTrue);
      expect(c.read(learnerStudentIdProvider), child.studentId);
      expect(c.read(learnerQueryIdProvider), child.studentId);
      expect(c.read(learnerNameProvider), child.name);
    });

    test('a parent with two children switches and the learner follows', () async {
      final base = _me('parent');
      final first = base.profile.children.first;
      final j = (jsonDecode(File('test/fixtures/me_parent.json').readAsStringSync()) as Map).cast<String, dynamic>();
      final profile = (j['profile'] as Map).cast<String, dynamic>();
      final kids = [...(profile['children'] as List), {...(profile['children'] as List).first as Map, 'studentId': 'second-child', 'name': 'Second Child', 'firstName': 'Second'}];
      final me = Me.fromJson({...j, 'profile': {...profile, 'children': kids}});
      final c = await _container(AppSession(auth: AuthStatus.signedIn, me: me, siteInfo: _info));
      expect(c.read(learnerQueryIdProvider), first.studentId);
      await c.read(selectedChildIdProvider.notifier).select('second-child');
      expect(c.read(learnerQueryIdProvider), 'second-child');
      expect(c.read(learnerNameProvider), 'Second Child');
    });
  });

  group('tab gating by permission and school features', () {
    TabSpec tab(Experience e, String label) => tabsFor(e).firstWhere((t) => t.label == label);

    test('a usable tab has no blocked view', () {
      expect(TabScreen.blockedView(tab(Experience.parent, 'Fees'), AppSession(me: _me('parent'), siteInfo: _info)), isNull);
      expect(TabScreen.blockedView(tab(Experience.student, 'Calendar'), AppSession(me: _me('student'), siteInfo: _info)), isNull);
    });

    test('fees switched off at the school is "not turned on"', () {
      const off = SiteInfo(code: 'demo', name: 'Demo School', primaryColor: '#0E5A63', features: SiteFeatures(fees: false));
      final v = TabScreen.blockedView(tab(Experience.parent, 'Fees'), AppSession(me: _me('parent'), siteInfo: off));
      expect(v, isA<EmptyState>().having((e) => e.title, 'title', 'Fees is not turned on'));
    });

    test('a role without the permission gets "No access"', () {
      final noFees = _me('parent', patch: {'permissions': <String, dynamic>{}});
      final v = TabScreen.blockedView(tab(Experience.parent, 'Fees'), AppSession(me: noFees, siteInfo: _info));
      expect(v, isA<EmptyState>().having((e) => e.title, 'title', 'No access'));
    });
  });

  group('infinite lists', () {
    setUp(() {
      _Numbers.calls.clear();
      _Numbers.failNext = false;
    });

    test('page numbered list appends and stops at the end', () async {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      final sub = c.listen(_numbers(1), (_, _) {});
      addTearDown(sub.close);
      var s = await c.read(_numbers(1).future);
      expect(s.items, [0, 1]);
      expect(s.hasMore, isTrue);
      await c.read(_numbers(1).notifier).loadMore();
      await c.read(_numbers(1).notifier).loadMore();
      s = c.read(_numbers(1)).requireValue;
      expect(s.items, [0, 1, 2, 3, 4, 5]);
      expect(s.hasMore, isFalse);
      await c.read(_numbers(1).notifier).loadMore();
      expect(_Numbers.calls, [1, 2, 3], reason: 'no request once everything is loaded');
    });

    test('a failed "load more" keeps what is on screen and can retry', () async {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      final sub = c.listen(_numbers(1), (_, _) {});
      addTearDown(sub.close);
      await c.read(_numbers(1).future);
      _Numbers.failNext = true;
      await c.read(_numbers(1).notifier).loadMore();
      var s = c.read(_numbers(1)).requireValue;
      expect(s.items, [0, 1]);
      expect(s.loadMoreError, isA<AppException>());
      expect(s.loadingMore, isFalse);
      await c.read(_numbers(1).notifier).loadMore();
      s = c.read(_numbers(1)).requireValue;
      expect(s.items, [0, 1, 2, 3]);
      expect(s.loadMoreError, isNull);
    });

    test('cursor list follows nextCursor, supports local edits', () async {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      final sub = c.listen(_cursored(1), (_, _) {});
      addTearDown(sub.close);
      var s = await c.read(_cursored(1).future);
      expect(s.items, ['a', 'b']);
      expect(s.hasMore, isTrue);
      await c.read(_cursored(1).notifier).loadMore();
      s = c.read(_cursored(1)).requireValue;
      expect(s.items, ['a', 'b', 'c']);
      expect(s.hasMore, isFalse);
      c.read(_cursored(1).notifier).edit((l) => l.where((e) => e != 'b').toList());
      expect(c.read(_cursored(1)).requireValue.items, ['a', 'c']);
    });
  });

  group('AsyncBody states', () {
    Widget host(Widget child) => MaterialApp(theme: buildTheme(const Color(0xFF0E5A63), Brightness.light), home: Scaffold(body: child));

    testWidgets('error with nothing to show offers Try again', (tester) async {
      var retried = 0;
      await tester.pumpWidget(host(AsyncBody<int>(value: const AsyncError(AppException(kind: ErrorKind.network, code: 'NETWORK', message: 'x'), StackTrace.empty), data: (_) => const Text('data'), onRetry: () => retried++)));
      await tester.pump();
      expect(find.text('You are offline'), findsOneWidget);
      await tester.tap(find.text('Try again'));
      expect(retried, 1);
      expect(find.text('data'), findsNothing);
    });

    testWidgets('a refresh failure keeps the last data and says so', (tester) async {
      var fail = false;
      final provider = FutureProvider<int>((ref) async {
        if (fail) throw const AppException(kind: ErrorKind.network, code: 'NETWORK', message: 'x');
        return 7;
      });
      final container = ProviderContainer(retry: (_, _) => null);
      addTearDown(container.dispose);
      await tester.pumpWidget(UncontrolledProviderScope(container: container, child: host(Consumer(builder: (context, ref, _) => AsyncBody<int>(value: ref.watch(provider), data: (d) => Text('value $d'), onRetry: () {})))));
      await tester.pump();
      await tester.pump();
      expect(find.text('value 7'), findsOneWidget);
      fail = true;
      container.invalidate(provider);
      await tester.pump();
      await tester.pump();
      expect(find.text('value 7'), findsOneWidget, reason: 'last data stays on screen');
      expect(find.textContaining('offline'), findsOneWidget);
    });

    testWidgets('empty data shows the empty view', (tester) async {
      await tester.pumpWidget(host(AsyncBody<List<int>>(value: const AsyncData([]), data: (d) => const Text('list'), isEmpty: (d) => d.isEmpty, empty: const EmptyState(title: 'Nothing here'))));
      await tester.pump();
      expect(find.text('Nothing here'), findsOneWidget);
      expect(find.text('list'), findsNothing);
    });

    testWidgets('loading shows a skeleton, not an error', (tester) async {
      await tester.pumpWidget(host(AsyncBody<int>(value: const AsyncLoading(), data: (_) => const Text('data'))));
      await tester.pump();
      expect(find.byType(SkeletonList), findsOneWidget);
      expect(find.text('data'), findsNothing);
    });
  });
}
