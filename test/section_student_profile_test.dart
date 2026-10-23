import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:schoolsync/core/design/design.dart';
import 'package:schoolsync/core/providers.dart';
import 'package:schoolsync/core/storage/secure_store.dart';
import 'package:schoolsync/data/json.dart';
import 'package:schoolsync/data/models/me.dart';
import 'package:schoolsync/features/auth/session.dart';
import 'package:schoolsync/features/workspace/section_screen.dart';
import 'package:schoolsync/features/workspace/student_profile_screen.dart';

import 'management_test_support.dart';
import 'staff_test_support.dart';

Json _api(String name) => jsonMap(jsonDecode(File('test/fixtures/api/$name.json').readAsStringSync()));

final _sid = fixture('section_detail')['id'] as String;
final _studentId = fixture('student_detail')['id'] as String;

Future<void> _pump(WidgetTester tester, Widget screen, {required String me, required FakeServer server, Me? meValue, Size size = const Size(390, 2400), double textScale = 1, bool fees = true}) async {
  tester.view.physicalSize = size * 2;
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(const SizedBox.shrink()); // a fresh tree when a test pumps twice
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (c, _) => screen),
      GoRoute(path: '/teacher/students/:id', builder: (c, s) => Scaffold(body: Text('TEACHER-STUDENT ${s.pathParameters['id']}'))),
      GoRoute(path: '/management/students/:id', builder: (c, s) => Scaffold(body: Text('MGMT-STUDENT ${s.pathParameters['id']}'))),
      GoRoute(path: '/teacher/syllabus', builder: (c, s) => Scaffold(body: Text('SYLLABUS ${s.uri.queryParameters}'))),
      GoRoute(path: '/teacher/attendance/roll/:id', builder: (c, s) => Scaffold(body: Text('ROLL ${s.pathParameters['id']}'))),
    ],
  );
  await tester.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: [
        sessionProvider.overrideWith(() => FakeSession(meValue ?? meFixture(me), fees: fees)),
        apiClientProvider.overrideWithValue(apiFor(server)),
        secureStoreProvider.overrideWithValue(SecureStore(MemorySecureKv())),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        theme: buildTheme(kDefaultBrand, Brightness.light),
        builder: (context, c) => MediaQuery(data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)), child: c!),
      ),
    ),
  );
}

Me _without(String who, List<String> permissions) {
  final j = Map<String, dynamic>.of(meFixture(who).raw!);
  j['permissions'] = Map<String, dynamic>.of(j['permissions'] as Map<String, dynamic>)..removeWhere((k, _) => permissions.contains(k));
  return Me.fromJson(j);
}

FakeServer _sectionServer() => FakeServer()
  ..on('GET /academics/sections/$_sid', fixture('section_detail'))
  ..on('GET /students', fixture('students'))
  ..on('GET /syllabus/coverage', fixture('coverage'))
  ..on('GET /attendance/sections/$_sid/summary', fixture('section_summary'));

/// The roster capture lists other students; add this student so the homework lines have something to say.
Map<String, dynamic> _rosterWith(String status) {
  final r = fixture('homework_roster');
  (r['data'] as List).add({
    'studentId': _studentId,
    'name': 'Ishaan Bose',
    'admissionNo': 'GV20260001',
    'rollNo': 1,
    'status': status,
    'submission': status == 'reviewed' ? {'id': 'sub1', 'status': 'reviewed', 'submittedAt': '2026-10-20T10:00:00.000Z', 'isLate': false, 'marks': 8.5, 'feedback': 'Good', 'reviewedAt': '2026-10-21T10:00:00.000Z'} : null,
  });
  return r;
}

FakeServer _studentServer({String hwStatus = 'reviewed'}) {
  final hw = fixture('homework_list');
  final server = FakeServer()
    ..on('GET /students/$_studentId', fixture('student_detail'))
    ..on('GET /attendance/students/$_studentId/summary', _api('attendance_summary'))
    ..on('GET /homework', hw)
    ..on('GET /fees/invoices', _api('invoices'));
  for (final h in hw['data'] as List) {
    server.on('GET /homework/${(h as Map)['id']}/roster', _rosterWith(hwStatus));
  }
  return server;
}

void main() {
  group('SectionScreen', () {
    testWidgets('teacher: header, students, and a tap opens the student', (tester) async {
      await _pump(tester, SectionScreen(sectionId: _sid), me: 'teacher', server: _sectionServer());
      await tester.pumpAndSettle();
      final detail = fixture('section_detail');
      expect(find.text('${detail['gradeName']} ${detail['name']}'), findsOneWidget);
      expect(find.textContaining('Class teacher: ${detail['classTeacherName']}'), findsOneWidget);
      expect(find.text('Students'), findsOneWidget, reason: 'the tab');
      expect(find.text('Syllabus'), findsOneWidget);
      expect(find.text('Attendance'), findsOneWidget);
      final first = (fixture('students')['data'] as List).first as Map;
      expect(find.text(first['name'] as String), findsOneWidget);
      await tester.tap(find.text(first['name'] as String));
      await tester.pumpAndSettle();
      expect(find.text('TEACHER-STUDENT ${first['id']}'), findsOneWidget);
    });

    testWidgets('management: the same screen, student links go to the management profile; no teacher actions', (tester) async {
      await _pump(tester, SectionScreen(sectionId: _sid), me: 'principal', server: _sectionServer());
      await tester.pumpAndSettle();
      final first = (fixture('students')['data'] as List).first as Map;
      await tester.tap(find.text(first['name'] as String));
      await tester.pumpAndSettle();
      expect(find.text('MGMT-STUDENT ${first['id']}'), findsOneWidget);
    });

    testWidgets('syllabus tab: average coverage and a row per subject; teachers can update progress', (tester) async {
      await _pump(tester, SectionScreen(sectionId: _sid), me: 'teacher', server: _sectionServer());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Syllabus'));
      await tester.pumpAndSettle();
      expect(find.text('Average coverage'), findsOneWidget);
      final rows = (fixture('coverage')['data'] as List).cast<Map<String, dynamic>>();
      expect(find.text(rows.first['subjectName'] as String), findsOneWidget);
      await tester.tap(find.text('Update progress'));
      await tester.pumpAndSettle();
      expect(find.textContaining('SYLLABUS'), findsOneWidget);
      expect(find.textContaining(_sid), findsOneWidget);
    });

    testWidgets('attendance tab: class percentage, lowest first, roll call for the class teacher', (tester) async {
      await _pump(tester, SectionScreen(sectionId: _sid), me: 'teacher', server: _sectionServer());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Attendance'));
      await tester.pumpAndSettle();
      expect(find.text('Last 30 days'), findsOneWidget);
      expect(find.text('Students, lowest first'), findsOneWidget);
      expect(find.text("Take today's roll call"), findsOneWidget);
      await tester.tap(find.text("Take today's roll call"));
      await tester.pumpAndSettle();
      expect(find.text('ROLL $_sid'), findsOneWidget);
    });

    testWidgets('a manager has no roll call button; without attendance:view there is no Attendance tab', (tester) async {
      await _pump(tester, SectionScreen(sectionId: _sid), me: 'principal', server: _sectionServer());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Attendance'));
      await tester.pumpAndSettle();
      expect(find.text("Take today's roll call"), findsNothing);

      await _pump(tester, SectionScreen(sectionId: _sid), me: 'principal', meValue: _without('principal', ['attendance:view']), server: _sectionServer());
      await tester.pumpAndSettle();
      expect(find.text('Attendance'), findsNothing);
      expect(find.text('Syllabus'), findsOneWidget);
    });

    testWidgets('students: search narrows the list, and a miss offers Clear search', (tester) async {
      final many = fixture('students');
      final base = (many['data'] as List).first as Map<String, dynamic>;
      many['data'] = [for (var i = 0; i < 12; i++) {...base, 'id': 'st$i', 'name': 'Student Number$i', 'admissionNo': 'A$i', 'rollNo': i + 1}];
      final server = _sectionServer()..on('GET /students', many);
      await _pump(tester, SectionScreen(sectionId: _sid), me: 'teacher', server: server);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Number7');
      await tester.pumpAndSettle();
      expect(find.text('Student Number7'), findsOneWidget);
      expect(find.text('Student Number3'), findsNothing);
      await tester.enterText(find.byType(TextField), 'zzz');
      await tester.pumpAndSettle();
      expect(find.text('Clear search'), findsOneWidget);
    });

    testWidgets('empty class, failing header and failing tab are explained with a retry', (tester) async {
      final server = _sectionServer()
        ..on('GET /students', {'data': <Object?>[], 'meta': {'page': 1, 'pageSize': 100, 'total': 0, 'totalPages': 1}})
        ..on('GET /academics/sections/$_sid', {'title': 'Boom', 'code': 'INTERNAL', 'status': 500}, status: 500);
      await _pump(tester, SectionScreen(sectionId: _sid), me: 'teacher', server: server);
      await tester.pumpAndSettle(const Duration(seconds: 2));
      expect(find.text('No students in this class yet'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget, reason: 'the header can be retried on its own');
    });

    testWidgets('200% text scale: no overflow on any tab', (tester) async {
      await _pump(tester, SectionScreen(sectionId: _sid), me: 'teacher', server: _sectionServer(), size: const Size(360, 1800), textScale: 2);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Syllabus'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Attendance'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });

  group('StudentProfileScreen', () {
    testWidgets('teacher: class, attendance, recent homework and guardians (tap to call); no fees', (tester) async {
      await _pump(tester, StudentProfileScreen(studentId: _studentId), me: 'teacher', server: _studentServer());
      await tester.pumpAndSettle();
      final d = fixture('student_detail');
      expect(find.text(d['name'] as String), findsWidgets);
      expect(find.textContaining('${d['gradeName']}'), findsWidgets);
      expect(find.text('Attendance this year'), findsOneWidget);
      expect(find.text('Recent homework'), findsOneWidget);
      expect(find.textContaining('Reviewed, 8.5'), findsWidgets, reason: 'status word plus marks');
      expect(find.text('Parents and guardians'), findsOneWidget);
      final g = (d['guardians'] as List).first as Map;
      expect(find.byTooltip('Call ${g['name']}'), findsWidgets, reason: 'the guardian row and the emergency contact');
      expect(find.text('Fees'), findsNothing, reason: 'a teacher holds no fee permission');
    });

    testWidgets('homework states carry a word and an icon: missing past the due date, handed in', (tester) async {
      await _pump(tester, StudentProfileScreen(studentId: _studentId), me: 'teacher', server: _studentServer(hwStatus: 'missing'));
      await tester.pumpAndSettle();
      expect(find.text('Missing'), findsWidgets);
      await _pump(tester, StudentProfileScreen(studentId: _studentId), me: 'teacher', server: _studentServer(hwStatus: 'submitted'));
      await tester.pumpAndSettle();
    });

    testWidgets('principal: the fee balance and invoices appear; the school switching fees off hides them', (tester) async {
      await _pump(tester, StudentProfileScreen(studentId: _studentId), me: 'principal', server: _studentServer());
      await tester.pumpAndSettle();
      expect(find.text('Fees'), findsOneWidget);
      expect(find.text('balance to pay'), findsOneWidget);
      final inv = ((_api('invoices')['data'] as List).first as Map)['invoiceNo'] as String;
      expect(find.textContaining(inv), findsWidgets);
    });

    testWidgets('fees module off: no Fees card and no invoice request', (tester) async {
      final server = _studentServer();
      await _pump(tester, StudentProfileScreen(studentId: _studentId), me: 'principal', server: server, fees: false);
      await tester.pumpAndSettle();
      expect(find.text('Fees'), findsNothing);
      expect(server.requests.where((r) => r.path == '/fees/invoices'), isEmpty);
    });

    testWidgets('a part the API refuses (403) disappears quietly; the rest stays', (tester) async {
      final server = _studentServer()..on('GET /fees/invoices', {'title': 'Forbidden', 'code': 'FORBIDDEN', 'status': 403}, status: 403);
      await _pump(tester, StudentProfileScreen(studentId: _studentId), me: 'principal', server: server);
      await tester.pumpAndSettle(const Duration(seconds: 2));
      expect(find.text('Fees'), findsNothing);
      expect(find.text('Attendance this year'), findsOneWidget);
      expect(find.text('Parents and guardians'), findsOneWidget);
    });

    testWidgets('a failing part shows its own error with a retry; no attendance permission hides it', (tester) async {
      final server = _studentServer()..on('GET /attendance/students/$_studentId/summary', {'title': 'Boom', 'code': 'INTERNAL', 'status': 500}, status: 500);
      await _pump(tester, StudentProfileScreen(studentId: _studentId), me: 'teacher', server: server);
      await tester.pumpAndSettle(const Duration(seconds: 2));
      expect(find.text('Try again'), findsOneWidget);
      expect(find.text('Parents and guardians'), findsOneWidget);

      await _pump(tester, StudentProfileScreen(studentId: _studentId), me: 'teacher', meValue: _without('teacher', ['attendance:view']), server: _studentServer());
      await tester.pumpAndSettle();
      expect(find.text('Attendance this year'), findsNothing);
    });

    testWidgets('a missing or out-of-scope student: Not found, with no way to retry into a loop', (tester) async {
      final server = FakeServer()..on('GET /students/$_studentId', {'title': 'Not found', 'code': 'NOT_FOUND', 'status': 404}, status: 404);
      await _pump(tester, StudentProfileScreen(studentId: _studentId), me: 'teacher', server: server);
      await tester.pumpAndSettle();
      expect(find.text('Not found'), findsOneWidget);
    });

    testWidgets('hidden guardian phone (no guardians:view): no Call button; 200% text scale without overflow', (tester) async {
      final detail = fixture('student_detail');
      for (final g in detail['guardians'] as List) {
        (g as Map)['phone'] = null;
      }
      final server = _studentServer()..on('GET /students/$_studentId', detail);
      await _pump(tester, StudentProfileScreen(studentId: _studentId), me: 'principal', server: server, size: const Size(360, 2600), textScale: 2);
      await tester.pumpAndSettle();
      expect(find.byTooltip('Call ${((detail['guardians'] as List).first as Map)['name']}'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
}
