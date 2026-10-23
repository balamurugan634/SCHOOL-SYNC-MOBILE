// Renders the teacher and management screens to PNG files for the product brochure.
//
// It is skipped in a normal `flutter test` run. To (re)write the images:
//
//   BROCHURE=1 /home/bala/SCHOOL-SYNC/scripts/dev/heavy.sh -m 3G -- \
//     flutter test test/brochure_staff_screens_test.dart --concurrency=2
//
// Output: $BROCHURE_OUT (default /home/bala/SCHOOL-SYNC/brochure/assets/mobile), files 10-16 only.
// The screens are the real ones, in the real theme (Green Valley Public School, #1B6B4F, light), with the real bundled
// fonts and responses recorded from the demo school (test/fixtures/brochure/). Only display flags are adjusted
// where the recording is an unflattering moment (for example "everything is already marked" becomes "one class still
// to mark"); names, subjects, sections, amounts and dates are the demo data as recorded.
import 'dart:async' show unawaited;
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart' show ByteData, FontLoader;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:schoolsync/core/design/design.dart';
import 'package:schoolsync/core/providers.dart';
import 'package:schoolsync/core/storage/secure_store.dart';
import 'package:schoolsync/data/json.dart';
import 'package:schoolsync/data/models/me.dart';
import 'package:schoolsync/data/models/site_info.dart';
import 'package:schoolsync/features/auth/session.dart';
import 'package:schoolsync/features/management/approvals/approval_list_screen.dart';
import 'package:schoolsync/features/management/finance/finance_screen.dart';
import 'package:schoolsync/features/management/home/management_home_screen.dart';
import 'package:schoolsync/features/teacher/attendance/roll_call_screen.dart';
import 'package:schoolsync/features/teacher/home/teacher_home_screen.dart';
import 'package:schoolsync/features/teacher/homework/homework_tab.dart';
import 'package:schoolsync/features/teacher/marks/marks_entry_screen.dart';
import 'package:schoolsync/router/role_modules.dart';

import 'staff_test_support.dart';
import 'support/fonts.dart';

final _enabled = Platform.environment['BROCHURE'] == '1';

/// The test engine draws icons as empty boxes; load the real Material Icons font from the Flutter SDK.
Future<void> _loadMaterialIcons() async {
  final root =
      Platform.environment['FLUTTER_ROOT'] ?? '/home/bala/development/flutter';
  final font = File(
    '$root/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
  );
  final loader = FontLoader('MaterialIcons')
    ..addFont(Future.value(ByteData.sublistView(font.readAsBytesSync())));
  await loader.load();
}

final _outDir =
    Platform.environment['BROCHURE_OUT'] ??
    '/home/bala/SCHOOL-SYNC/brochure/assets/mobile';

const _phone = Size(390, 844);
const _ratio = 2.5;
const _statusBar = 30.0;
const _brand = Color(0xFF1B6B4F);

Json _fx(String name) => jsonMap(
  jsonDecode(File('test/fixtures/brochure/$name.json').readAsStringSync()),
);

Me _me(String name) {
  final j = _fx('me_$name');
  // The app greets people by the first word of their name; "Dr." is a title, so the principal appears without it.
  if (name == 'principal') j['displayName'] = 'Meenakshi Raman';
  return Me.fromJson(j);
}

class _Session extends SessionController {
  _Session(this.me);
  final Me me;

  @override
  AppSession build() => AppSession(
    ready: true,
    introSeen: true,
    auth: AuthStatus.signedIn,
    me: me,
    tourSeen: true,
    primerStage: primerStageDone,
    siteInfo: const SiteInfo(
      code: 'demo',
      name: 'Green Valley Public School',
      shortName: 'Green Valley',
      primaryColor: '#1B6B4F',
      currency: 'INR',
    ),
  );
}

/// A plain status bar: the time on the left, signal / Wi-Fi / battery on the right.
class _StatusBar extends StatelessWidget {
  const _StatusBar();

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Material(
      type: MaterialType.transparency,
      child: SizedBox(
        height: _statusBar,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22),
          child: Row(
            children: [
              Text(
                '9:41',
                style: TextStyle(
                  fontFamily: kFontSans,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: t.text,
                  height: 1,
                ),
              ),
              const Spacer(),
              Icon(Icons.signal_cellular_alt_rounded, size: 15, color: t.text),
              const SizedBox(width: 5),
              Icon(Icons.wifi_rounded, size: 15, color: t.text),
              const SizedBox(width: 5),
              Icon(Icons.battery_full_rounded, size: 17, color: t.text),
            ],
          ),
        ),
      ),
    );
  }
}

enum _Chrome { none, teacherTab, managementTab }

/// Renders [screen] on a 390 x 844 phone (975 x 2110 px) and writes [file] into the output folder.
Future<void> _shoot(
  WidgetTester tester, {
  required String file,
  required Widget screen,
  required Me me,
  required FakeServer server,
  _Chrome chrome = _Chrome.none,
  int tab = 0,
  Future<void> Function(WidgetTester tester)? beforeShot,
}) async {
  // The test engine draws shadows as solid black outlines; switch real shadows on while shooting and restore the
  // flag before the test ends (the test binding verifies it).
  debugDisableShadows = false;
  FocusManager.instance.highlightStrategy = FocusHighlightStrategy.alwaysTouch; // no keyboard focus rings in a phone image
  tester.view.physicalSize = _phone * _ratio;
  tester.view.devicePixelRatio = _ratio;
  addTearDown(tester.view.reset);

  final key = GlobalKey();
  Widget framed(Widget body) {
    if (chrome == _Chrome.none) return body;
    final tabs = tabsFor(
      chrome == _Chrome.teacherTab ? Experience.teacher : Experience.management,
    );
    return Scaffold(
      body: body,
      bottomNavigationBar: AppBottomNav(
        index: tab,
        destinations: [
          for (final t in tabs)
            NavDestination(
              label: t.label,
              icon: t.icon,
              selectedIcon: t.selectedIcon,
            ),
        ],
        onSelected: (_) {},
      ),
    );
  }

  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (c, _) => chrome == _Chrome.none
            ? const Scaffold(body: SizedBox.shrink())
            : framed(screen),
      ),
      GoRoute(path: '/screen', builder: (c, _) => screen),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: [
        sessionProvider.overrideWith(() => _Session(me)),
        apiClientProvider.overrideWithValue(apiFor(server)),
        secureStoreProvider.overrideWithValue(SecureStore(MemorySecureKv())),
      ],
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        routerConfig: router,
        theme: buildTheme(_brand, Brightness.light),
        builder: (context, child) {
          final base = MediaQuery.of(context);
          return RepaintBoundary(
            key: key,
            child: MediaQuery(
              data: base.copyWith(
                padding: const EdgeInsets.only(top: _statusBar),
                viewPadding: const EdgeInsets.only(top: _statusBar),
              ),
              child: Stack(
                children: [
                  Positioned.fill(child: child!),
                  const Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: IgnorePointer(child: _StatusBar()),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    ),
  );
  await tester.pumpAndSettle();
  if (chrome == _Chrome.none) {
    unawaited(router.push('/screen'));
    await tester.pumpAndSettle();
  }
  await beforeShot?.call(tester);
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle(const Duration(milliseconds: 100));
  expect(
    tester.takeException(),
    isNull,
    reason: '$file must render without a framework error',
  );

  // A brochure image never shows a loading, empty or error state.
  expect(
    find.byType(CircularProgressIndicator),
    findsNothing,
    reason: '$file is still loading',
  );
  expect(
    find.text('Try again'),
    findsNothing,
    reason: '$file shows an error state',
  );

  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: _ratio);
    expect((image.width, image.height), (975, 2110));
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    final dir = Directory(_outDir)..createSync(recursive: true);
    File('${dir.path}/$file').writeAsBytesSync(data!.buffer.asUint8List());
  });
  debugDisableShadows = true;
}

// ───────────────────────────── scenario data ─────────────────────────────

/// Mid-morning on a school day: the first lessons are over, Period 4 is running, and Grade 6 A is not marked yet.
Json _teacherDashboard() {
  final d = _fx('teacher_dashboard');
  final att = d['attendance'] as Map<String, dynamic>;
  (att['items'] as List).first['marked'] = false;
  (att['items'] as List).first['counts'] = null;
  att['pendingCount'] = 1;
  final tt = d['timetable'] as Map<String, dynamic>;
  final all = (tt['entries'] as List).cast<Map<String, dynamic>>();
  tt['entries'] = all.sublist(1); // the 9:15 lesson is scrolled out of a morning view; keeps the to-do list on screen
  final entries = (tt['entries'] as List).cast<Map<String, dynamic>>();
  for (final (i, e) in entries.indexed) {
    e['state'] = i < 1 ? 'past' : (i == 1 ? 'current' : 'upcoming');
  }
  tt['now'] = entries[1]['startTime'];
  tt['current'] = entries[1];
  tt['next'] = entries[2];
  return d;
}

/// The recorded Grade 6 A roster with a realistic half-finished roll call: mixed statuses, six students still to mark.
Json _rollCall() {
  final r = _fx('roster');
  const unmarked = {4, 11, 17, 19, 21, 23};
  const marks = {
    1: 'late',
    3: 'absent',
    5: 'half_day',
    8: 'leave',
    14: 'absent',
  };
  final students = (r['students'] as List).cast<Map<String, dynamic>>();
  for (final (i, s) in students.indexed) {
    if (unmarked.contains(i)) {
      s
        ..['status'] = null
        ..['recordId'] = null
        ..['source'] = null
        ..['markedAt'] = null
        ..['remarks'] = null;
    } else {
      s['status'] = marks[i] ?? 'present';
      s['remarks'] = marks[i] == 'absent' && i == 3
          ? 'Fever, informed by parent'
          : null;
    }
    s['onApprovedLeave'] = i == 8;
    if (i == 8) s['source'] = 'leave';
  }
  r
    ..['session'] = null
    ..['canSubmit'] = true
    ..['blockedReason'] = null
    ..['canRequestCorrection'] = false
    ..['warnings'] = <Object?>[];
  return r;
}

/// The principal's dashboard as recorded today, with the attendance block taken from a mid-afternoon recording of the same
/// school (8 of 10 classes marked; the morning recording only has 2) and the alerts switched to match. Names, counts,
/// finance and queues are the recorded demo data.
Json _managementDashboard({bool alerts = false}) {
  final d = _fx('management_dashboard');
  final snap = _fx('attendance_snapshot')['attendance'] as Map<String, dynamic>;
  final totals = snap['totals'] as Map<String, dynamic>;
  totals['activeStudents'] = (d['kpis'] as Map)['students'];
  totals['unmarkedStudents'] = (totals['activeStudents'] as int) - (totals['markedStudents'] as int);
  d['attendance'] = snap;
  final list = (d['alerts'] as List).cast<Map<String, dynamic>>();
  if (alerts && list.isNotEmpty) {
    list.first
      ..['message'] = '2 classes have not marked attendance today'
      ..['count'] = 2;
  } else {
    d['alerts'] = <Object?>[];
  }
  return d;
}

/// Published homework with due dates spread over the coming week (the recording is a few days old, so most of its
/// deadlines have passed). Titles, classes, subjects and hand-in counts are the demo data as recorded.
Json _homework() {
  final l = _fx('homework_list');
  const inDays = {
    'Exercise problems 1 to 10': 1,
    'Vocabulary: word meanings and sentences': 2,
    'Colour wheel in poster colours': 3,
    'Scratch mini project': 4,
    'Patra lekhan': 5,
    'Fractions and decimals worksheet': 7,
  };
  final now = DateTime.now();
  final rows = <Map<String, dynamic>>[];
  for (final h in (l['data'] as List).cast<Map<String, dynamic>>()) {
    final days = inDays[h['title']];
    if (h['status'] != 'published' || days == null) continue;
    final due = DateTime(
      now.year,
      now.month,
      now.day,
      17,
    ).add(Duration(days: days));
    h['dueAt'] = due.toUtc().toIso8601String();
    h['assignedAt'] = due
        .subtract(const Duration(days: 4))
        .toUtc()
        .toIso8601String();
    rows.add(h);
  }
  rows.sort((a, b) => (a['dueAt'] as String).compareTo(b['dueAt'] as String));
  l['data'] = rows;
  return l;
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await loadAppFonts();
    await _loadMaterialIcons();
  });

  group('brochure images (teacher)', () {
    testWidgets('10-teacher-home.png', skip: !_enabled, (tester) async {
      final server = FakeServer()
        ..on('GET /dashboard/teacher', _teacherDashboard());
      await _shoot(
        tester,
        file: '10-teacher-home.png',
        screen: const TeacherHomeScreen(),
        me: _me('teacher'),
        server: server,
        chrome: _Chrome.teacherTab,
        tab: 0,
      );
    });

    testWidgets('11-teacher-rollcall.png', skip: !_enabled, (tester) async {
      final roster = _rollCall();
      final server = FakeServer()
        ..on('GET /attendance/sections/${roster['sectionId']}', roster);
      await _shoot(
        tester,
        file: '11-teacher-rollcall.png',
        screen: RollCallScreen(sectionId: roster['sectionId'] as String),
        me: _me('teacher'),
        server: server,
      );
    });

    testWidgets('12-teacher-homework.png', skip: !_enabled, (tester) async {
      final server = FakeServer()..on('GET /homework', _homework());
      await _shoot(
        tester,
        file: '12-teacher-homework.png',
        screen: const TeacherHomeworkTab(),
        me: _me('teacher'),
        server: server,
        chrome: _Chrome.teacherTab,
        tab: 3,
      );
    });

    testWidgets('13-teacher-marks.png', skip: !_enabled, (tester) async {
      final sheet = _fx('sheet_detail');
      final server = FakeServer()
        ..on('GET /marks/sheets/${sheet['id']}', sheet);
      await _shoot(
        tester,
        file: '13-teacher-marks.png',
        screen: MarksEntryScreen(sheetId: sheet['id'] as String),
        me: _me('teacher'),
        server: server,
      );
    });
  });

  group('brochure images (management)', () {
    testWidgets('14-management-home.png', skip: !_enabled, (tester) async {
      final server = FakeServer()
        ..on('GET /dashboard/management', _managementDashboard());
      await _shoot(
        tester,
        file: '14-management-home.png',
        screen: const ManagementHomeScreen(),
        me: _me('principal'),
        server: server,
        chrome: _Chrome.managementTab,
        tab: 0,
      );
    });

    testWidgets('14b-management-attendance-trend.png', skip: !_enabled, (
      tester,
    ) async {
      final server = FakeServer()
        ..on('GET /dashboard/management', _managementDashboard());
      await _shoot(
        tester,
        file: '14b-management-attendance-trend.png',
        screen: const ManagementHomeScreen(),
        me: _me('principal'),
        server: server,
        chrome: _Chrome.managementTab,
        tab: 0,
        beforeShot: (t) async {
          await t.drag(find.byType(ListView).first, const Offset(0, -758));
          await t.pumpAndSettle();
        },
      );
    });

    testWidgets('15-management-approvals.png', skip: !_enabled, (tester) async {
      final leave = _fx('student_leave');
      final server = FakeServer()..on('GET /leave', leave);
      final first =
          ((leave['data'] as List).first as Map)['studentName'] as String;
      await _shoot(
        tester,
        file: '15-management-approvals.png',
        screen: const ApprovalListScreen(kind: 'student-leave'),
        me: _me('principal'),
        server: server,
        beforeShot: (t) async {
          await t.tap(find.text(first));
          await t.pumpAndSettle();
        },
      );
    });

    testWidgets('16-management-finance.png', skip: !_enabled, (tester) async {
      final server = FakeServer()
        ..on('GET /finance/summary', _fx('finance_summary'))
        ..on('GET /fees/reports/outstanding', _fx('outstanding'));
      await _shoot(
        tester,
        file: '16-management-finance.png',
        screen: const ManagementFinanceScreen(),
        me: _me('accounts'),
        server: server,
        chrome: _Chrome.managementTab,
        tab: 3,
      );
    });

    testWidgets('16b-management-finance-chart.png', skip: !_enabled, (tester) async {
      final server = FakeServer()
        ..on('GET /finance/summary', _fx('finance_summary'))
        ..on('GET /fees/reports/outstanding', _fx('outstanding'));
      await _shoot(
        tester,
        file: '16b-management-finance-chart.png',
        screen: const ManagementFinanceScreen(),
        me: _me('accounts'),
        server: server,
        chrome: _Chrome.managementTab,
        tab: 3,
        beforeShot: (t) async {
          await t.drag(find.byType(ListView).first, const Offset(0, -473));
          await t.pumpAndSettle();
        },
      );
    });
  });
}
