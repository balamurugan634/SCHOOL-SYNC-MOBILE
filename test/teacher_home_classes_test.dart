import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:schoolsync/core/design/design.dart';
import 'package:schoolsync/core/providers.dart';
import 'package:schoolsync/core/storage/secure_store.dart';
import 'package:schoolsync/data/models/me.dart';
import 'package:schoolsync/features/auth/session.dart';
import 'package:schoolsync/features/teacher/classes/classes_screen.dart';
import 'package:schoolsync/features/teacher/home/teacher_home_providers.dart';
import 'package:schoolsync/features/teacher/home/teacher_home_screen.dart';
import 'package:schoolsync/features/workspace/focus_refresh.dart';

import 'management_test_support.dart';
import 'staff_test_support.dart';

const _tall = Size(390, 3600);
final _store = secureStoreProvider.overrideWithValue(SecureStore(MemorySecureKv()));

class _Flaky extends FakeServer {
  bool down = false;

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? body, Future<void>? cancel) {
    if (down) throw DioException(requestOptions: o, type: DioExceptionType.connectionError, error: 'SocketException: offline');
    return super.fetch(o, body, cancel);
  }
}

/// The teacher dashboard as captured, with the attendance / timetable blocks reshaped for one scenario.
Map<String, dynamic> _dash({bool marked = false, bool workingDay = true, bool withCurrent = false}) {
  final d = fixture('teacher_dashboard');
  final att = d['attendance'] as Map<String, dynamic>;
  att['isWorkingDay'] = workingDay;
  if (!workingDay) att['holiday'] = 'Diwali';
  final items = att['items'] as List;
  (items.first as Map)['marked'] = marked;
  att['pendingCount'] = marked ? 0 : 1;
  if (withCurrent) {
    final tt = d['timetable'] as Map<String, dynamic>;
    final entries = tt['entries'] as List;
    (entries[1] as Map)['state'] = 'current';
    tt['current'] = entries[1];
  }
  return d;
}

Future<void> _pumpRouted(WidgetTester tester, Widget screen, {required FakeServer server, Size size = _tall, double textScale = 1, bool readOnly = false, Me? me}) async {
  tester.view.physicalSize = size * 2;
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(const SizedBox.shrink()); // a fresh tree when a test pumps twice
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (c, _) => Scaffold(body: screen)),
      GoRoute(path: '/teacher/attendance/roll/:sectionId', builder: (c, s) => Scaffold(body: Text('ROLL ${s.pathParameters['sectionId']} ${s.uri.queryParameters}'))),
      GoRoute(path: '/teacher/classes/:sectionId', builder: (c, s) => Scaffold(body: Text('SECTION ${s.pathParameters['sectionId']}'))),
      GoRoute(path: '/teacher/marks/:sheetId', builder: (c, s) => Scaffold(body: Text('SHEET ${s.pathParameters['sheetId']}'))),
      GoRoute(path: '/teacher/attendance/leave', builder: (c, s) => const Scaffold(body: Text('LEAVE'))),
      GoRoute(path: '/teacher/homework/:id', builder: (c, s) => Scaffold(body: Text('HOMEWORK ${s.pathParameters['id']}'))),
      GoRoute(path: '/tab/:i', builder: (c, s) => Scaffold(body: Text('TAB ${s.pathParameters['i']}'))),
    ],
  );
  await tester.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: [
        sessionProvider.overrideWith(() => FakeSession(me ?? meFixture('teacher'), readOnly: readOnly)),
        apiClientProvider.overrideWithValue(apiFor(server)),
        _store,
      ],
      child: MaterialApp.router(
        routerConfig: router,
        theme: buildTheme(kDefaultBrand, Brightness.light),
        builder: (context, c) => MediaQuery(data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)), child: c!),
      ),
    ),
  );
}

void main() {
  group('TeacherHomeScreen', () {
    testWidgets('a section not yet marked is one tap from its roll call', (tester) async {
      final d = _dash();
      final server = FakeServer()..on('GET /dashboard/teacher', d);
      await _pumpRouted(tester, const TeacherHomeScreen(), server: server);
      await tester.pumpAndSettle();
      expect(find.text('Attendance'), findsOneWidget);
      expect(find.text('1 to mark'), findsOneWidget);
      expect(find.text('Roll call'), findsOneWidget);
      final section = ((d['attendance'] as Map)['items'] as List).first['sectionName'] as String;
      await tester.tap(find.text(section));
      await tester.pumpAndSettle();
      expect(find.textContaining('ROLL ${((d['attendance'] as Map)['items'] as List).first['sectionId']}'), findsOneWidget);
    });

    testWidgets('all marked: a calm confirmation instead of a button', (tester) async {
      final server = FakeServer()..on('GET /dashboard/teacher', _dash(marked: true));
      await _pumpRouted(tester, const TeacherHomeScreen(), server: server);
      await tester.pumpAndSettle();
      expect(find.text('All marked'), findsOneWidget);
      expect(find.text('Roll call'), findsNothing);
    });

    testWidgets('holiday: attendance is not asked for', (tester) async {
      final server = FakeServer()..on('GET /dashboard/teacher', _dash(workingDay: false));
      await _pumpRouted(tester, const TeacherHomeScreen(), server: server);
      await tester.pumpAndSettle();
      expect(find.textContaining('Holiday: Diwali'), findsOneWidget);
      expect(find.text('Roll call'), findsNothing);
    });

    testWidgets('timetable: the current period is marked Now (word and tint), covered lessons say you are free', (tester) async {
      final server = FakeServer()..on('GET /dashboard/teacher', _dash(withCurrent: true));
      await _pumpRouted(tester, const TeacherHomeScreen(), server: server);
      await tester.pumpAndSettle();
      expect(find.text('Today'), findsOneWidget);
      expect(find.text('Now'), findsOneWidget);
      expect(find.text('Free'), findsOneWidget, reason: 'period 1 is covered by a substitute in the capture');
      expect(find.textContaining('is covering your class'), findsOneWidget);
    });

    testWidgets('to do: homework to review, marks to enter, leave to decide; marks rows open the sheet', (tester) async {
      final d = _dash();
      final server = FakeServer()..on('GET /dashboard/teacher', d);
      await _pumpRouted(tester, const TeacherHomeScreen(), server: server);
      await tester.pumpAndSettle();
      expect(find.text('To do'), findsOneWidget);
      expect(find.text('Homework to review'), findsOneWidget);
      expect(find.text('Marks to enter'), findsOneWidget);
      expect(find.text('Student leave to decide'), findsOneWidget);
      final sheet = ((d['marks'] as Map)['items'] as List).first['sheetId'];
      await tester.tap(find.textContaining('Computer Science').first);
      await tester.pumpAndSettle();
      expect(find.text('SHEET $sheet'), findsOneWidget);
    });

    testWidgets('nothing waiting: To do says so; blocks without permission are hidden', (tester) async {
      final d = _dash();
      (d['homework'] as Map)['toReviewCount'] = 0;
      (d['marks'] as Map)..['pendingCount'] = 0..['returnedCount'] = 0..['items'] = <Object?>[];
      d['pendingLeaveCount'] = 0;
      final server = FakeServer()..on('GET /dashboard/teacher', d);
      await _pumpRouted(tester, const TeacherHomeScreen(), server: server);
      await tester.pumpAndSettle();
      expect(find.text('Nothing waiting for you. Nice.'), findsOneWidget);
      expect(find.text('Meetings'), findsOneWidget, reason: 'the teacher holds meetings:view');
    });

    testWidgets('no meetings permission: the card is hidden, not disabled', (tester) async {
      final j = Map<String, dynamic>.of(meFixture('teacher').raw!);
      j['permissions'] = Map<String, dynamic>.of(j['permissions'] as Map<String, dynamic>)..remove('meetings:view');
      final server = FakeServer()..on('GET /dashboard/teacher', _dash());
      await _pumpRouted(tester, const TeacherHomeScreen(), server: server, me: Me.fromJson(j));
      await tester.pumpAndSettle();
      expect(find.text('Meetings'), findsNothing);
      expect(find.text('Attendance'), findsOneWidget);
    });

    testWidgets('view-only school: a banner explains', (tester) async {
      final server = FakeServer()..on('GET /dashboard/teacher', _dash());
      await _pumpRouted(tester, const TeacherHomeScreen(), server: server, readOnly: true);
      await tester.pumpAndSettle();
      expect(find.text('View-only mode'), findsOneWidget);
    });

    testWidgets('failure with nothing to show: error with Retry, then recovers', (tester) async {
      final server = FakeServer()..on('GET /dashboard/teacher', {'title': 'Boom', 'code': 'INTERNAL', 'status': 500}, status: 500);
      await _pumpRouted(tester, const TeacherHomeScreen(), server: server);
      await tester.pumpAndSettle(const Duration(seconds: 2));
      expect(find.text('Try again'), findsOneWidget);
      server.on('GET /dashboard/teacher', _dash());
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(find.text('Attendance'), findsOneWidget);
    });

    testWidgets('offline after a good load: the saved copy is shown with an "as of" note', (tester) async {
      final server = _Flaky()..on('GET /dashboard/teacher', _dash());
      await _pumpRouted(tester, const TeacherHomeScreen(), server: server);
      await tester.pumpAndSettle();
      expect(find.textContaining('You are offline'), findsNothing);
      server.down = true;
      ProviderScope.containerOf(tester.element(find.byType(TeacherHomeScreen))).invalidate(teacherDashboardProvider);
      await tester.pumpAndSettle(const Duration(seconds: 5));
      expect(find.textContaining('You are offline. Showing your day as it was saved'), findsOneWidget);
      expect(find.text('Attendance'), findsOneWidget, reason: 'the cached day is still on screen');
    });

    testWidgets('200% text scale: no overflow anywhere on Home', (tester) async {
      final server = FakeServer()..on('GET /dashboard/teacher', _dash(withCurrent: true));
      await _pumpRouted(tester, const TeacherHomeScreen(), server: server, size: const Size(360, 3600), textScale: 2);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });

  group('RefreshOnFocus', () {
    testWidgets('refreshes after the tab was hidden for long enough, not after a blink', (tester) async {
      var refreshes = 0;
      final visible = ValueNotifier(true);
      Widget app() => MaterialApp(
        home: ValueListenableBuilder<bool>(
          valueListenable: visible,
          builder: (_, v, _) => TickerMode(enabled: v, child: RefreshOnFocus(minAway: const Duration(milliseconds: 50), onRefresh: () => refreshes++, child: const SizedBox())),
        ),
      );
      await tester.pumpWidget(app());
      visible.value = false;
      await tester.pump();
      visible.value = true;
      await tester.pump();
      expect(refreshes, 0, reason: 'back immediately: nothing to refresh');
      visible.value = false;
      await tester.pump();
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 80)));
      visible.value = true;
      await tester.pump();
      expect(refreshes, 1);
    });
  });

  group('ClassesScreen', () {
    Map<String, dynamic> sections() => fixture('sections');

    testWidgets('lists my sections, marks the one I lead, shows the subjects I teach', (tester) async {
      final server = FakeServer()
        ..on('GET /academics/sections', sections())
        ..on('GET /academics/teaching-assignments', fixture('assignments'));
      await _pumpRouted(tester, const ClassesScreen(embedded: false), server: server);
      await tester.pumpAndSettle();
      final list = (sections()['data'] as List).cast<Map<String, dynamic>>();
      expect(find.text('${list.first['gradeName']} ${list.first['name']}'), findsOneWidget);
      expect(find.text('Class teacher'), findsOneWidget, reason: 'the teacher leads exactly one class');
      expect(find.textContaining('English'), findsWidgets);
    });

    testWidgets('tap a class: opens it', (tester) async {
      final server = FakeServer()
        ..on('GET /academics/sections', sections())
        ..on('GET /academics/teaching-assignments', fixture('assignments'));
      await _pumpRouted(tester, const ClassesScreen(embedded: false), server: server);
      await tester.pumpAndSettle();
      final first = ((sections()['data'] as List).first as Map);
      await tester.tap(find.text('${first['gradeName']} ${first['name']}'));
      await tester.pumpAndSettle();
      expect(find.text('SECTION ${first['id']}'), findsOneWidget);
    });

    testWidgets('no classes: an explanation; the subject lookup failing does not hide the classes', (tester) async {
      final empty = FakeServer()..on('GET /academics/sections', {'data': <Object?>[], 'meta': {'page': 1, 'pageSize': 100, 'total': 0, 'totalPages': 1}});
      await _pumpRouted(tester, const ClassesScreen(embedded: false), server: empty);
      await tester.pumpAndSettle();
      expect(find.text('No classes assigned yet'), findsOneWidget);

      final partial = FakeServer()
        ..on('GET /academics/sections', sections())
        ..on('GET /academics/teaching-assignments', {'title': 'Boom', 'code': 'INTERNAL', 'status': 500}, status: 500);
      await _pumpRouted(tester, const ClassesScreen(embedded: false), server: partial);
      await tester.pumpAndSettle(const Duration(seconds: 2));
      expect(find.text('No classes assigned yet'), findsNothing);
      expect(find.text('Class teacher'), findsOneWidget);
    });

    testWidgets('error with retry; 200% text scale without overflow', (tester) async {
      final server = FakeServer()..on('GET /academics/sections', {'title': 'Boom', 'code': 'INTERNAL', 'status': 500}, status: 500);
      await _pumpRouted(tester, const ClassesScreen(embedded: false), server: server, size: const Size(360, 1200), textScale: 2);
      await tester.pumpAndSettle(const Duration(seconds: 2));
      expect(find.text('Try again'), findsOneWidget);
      server
        ..on('GET /academics/sections', sections())
        ..on('GET /academics/teaching-assignments', fixture('assignments'));
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });
}
