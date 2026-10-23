import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schoolsync/core/config/dev_options.dart';
import 'package:schoolsync/core/design/design.dart';
import 'package:schoolsync/core/providers.dart';
import 'package:schoolsync/core/storage/prefs.dart';
import 'package:schoolsync/core/storage/secure_store.dart';
import 'package:schoolsync/core/util/format.dart';
import 'package:schoolsync/core/util/site_address.dart';
import 'package:schoolsync/data/json.dart';
import 'package:schoolsync/data/models/me.dart';
import 'package:schoolsync/data/models/site_info.dart';
import 'package:schoolsync/features/auth/login_screen.dart';
import 'package:schoolsync/features/auth/session.dart';
import 'package:schoolsync/features/dashboard/parent_home_screen.dart';
import 'package:schoolsync/features/dashboard/student_home_screen.dart';
import 'package:schoolsync/features/exams/report_card_screen.dart';
import 'package:schoolsync/features/fees/fees_screen.dart';
import 'package:schoolsync/features/fees/invoice_screen.dart';
import 'package:schoolsync/features/homework/homework_detail_screen.dart';
import 'package:schoolsync/features/onboarding/connect_school_screen.dart';
import 'package:schoolsync/features/onboarding/intro_screen.dart';
import 'package:schoolsync/router/role_modules.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_api.dart';
import 'support/fonts.dart';

/// Renders the brochure screenshots of the mobile app straight from widget tests: the real theme, the real
/// bundled fonts (Manrope + Inter) and real responses recorded from the demo school
/// (`test/fixtures/brochure_learner/`). No emulator.
///
/// Not part of the normal test run. Render with:
///
///     BROCHURE=1 flutter test test/brochure_learner_screens_test.dart
///     (optional) BROCHURE_OUT=/some/folder     default /home/bala/SCHOOL-SYNC/brochure/assets/mobile
///
/// Every file is a 390x844 logical-pixel screen at pixel ratio 2.5 (975x2110 px), light theme, no device frame.
///
/// The recorded data is used as it came from the API. Only dates and the time of day are moved so the screens
/// look like one ordinary Friday morning (see [_studentDashboard]); no names, subjects or amounts are invented.
final String? _skip = Platform.environment['BROCHURE'] == '1' ? null : 'Set BROCHURE=1 to render the brochure screenshots.';
final String _out = Platform.environment['BROCHURE_OUT'] ?? '/home/bala/SCHOOL-SYNC/brochure/assets/mobile';

/// The moment the screens show: Friday 23 October 2026, 10:35 in the morning (school is in session).
final DateTime _now = DateTime(2026, 10, 23, 10, 35);
const Size _logical = Size(390, 844);
const double _ratio = 2.5;
const Color _schoolGreen = Color(0xFF1B6B4F);

dynamic _fx(String name) => jsonDecode(File('test/fixtures/brochure_learner/$name.json').readAsStringSync());
Json _copy(Object? v) => (jsonDecode(jsonEncode(v)) as Map).cast<String, dynamic>();

String _iso(DateTime d) => d.toUtc().toIso8601String();

class _Session extends SessionController {
  _Session(this.value);
  final AppSession value;
  @override
  AppSession build() => value;
}

SiteInfo _site() => SiteInfo.fromJson(_fx('site_info') as Json);
Me _me(String role) => Me.fromJson(_copy(_fx('me_$role')));
AppSession _signedIn(String role) => AppSession(ready: true, auth: AuthStatus.signedIn, me: _me(role), siteInfo: _site(), tourSeen: true);

// ---------------------------------------------------------------------------------------------------------------
// The recorded data, with the day moved to a representative morning.

/// 10:35: the first two classes and the break are over, Art & Craft is on, English is next.
void _atTenThirtyFive(Json timetable) {
  timetable['now'] = '10:35';
  for (final e in (timetable['entries'] as List).cast<Map<String, dynamic>>()) {
    final start = e['startTime'] as String, end = e['endTime'] as String;
    e['state'] = end.compareTo('10:35') <= 0 ? 'past' : (start.compareTo('10:35') <= 0 ? 'current' : 'upcoming');
  }
}

/// Real homework items that are still to do, due over the next days (the recorded ones are all already marked).
Json _homeworkSnapshot() {
  final all = ((_fx('homework_list') as Json)['data'] as List).cast<Map<String, dynamic>>();
  final due = <String, DateTime>{
    'Computer Science': DateTime(2026, 10, 23, 17, 0),
    'Physical Education': DateTime(2026, 10, 24, 17, 0),
    'English': DateTime(2026, 10, 27, 17, 0),
  };
  final items = <Json>[];
  for (final entry in due.entries) {
    final h = _copy(all.firstWhere((x) => x['subjectName'] == entry.key));
    h['dueAt'] = _iso(entry.value);
    h['learner'] = {'status': 'pending', 'submission': null};
    items.add(h);
  }
  return {'pendingCount': items.length, 'overdueCount': 0, 'items': items};
}

/// Real announcements, skipping the one that says "tomorrow" about the day before yesterday.
List<Map<String, dynamic>> _announcements() {
  final all = ((_fx('announcements') as Json)['data'] as List).cast<Map<String, dynamic>>();
  return [for (final a in all.where((a) => a['title'] != 'School closed tomorrow due to heavy rain').take(3)) _copy(a)];
}

List<Map<String, dynamic>> _calendar({bool withPtm = false}) {
  final all = ((_fx('calendar') as Json)['data'] as List).cast<Map<String, dynamic>>().where((c) => c['status'] != 'cancelled');
  final items = [for (final c in all.take(3)) _copy(c)];
  if (withPtm) {
    final ptm = (((_fx('dashboard_parent') as Json)['calendar']) as List).cast<Map<String, dynamic>>();
    items.insertAll(0, [for (final c in ptm) _copy(c)]);
  }
  return items.take(3).toList();
}

Json _studentDashboard() {
  final d = _copy(_fx('dashboard_student'));
  _atTenThirtyFive(d['timetable'] as Json);
  d['homework'] = _homeworkSnapshot();
  final latest = _announcements();
  d['announcements'] = {'unreadCount': latest.where((a) => a['read'] != true).length, 'pendingAckCount': 0, 'latest': latest};
  d['calendar'] = _calendar();
  final tasks = (d['tasks'] as List).cast<Map<String, dynamic>>();
  tasks.first
    ..['dueAt'] = _iso(DateTime(2026, 10, 24, 18, 0))
    ..['overdue'] = false;
  return d;
}

Json _parentDashboard() {
  final d = _copy(_fx('dashboard_parent'));
  final child = d['child'] as Json;
  _atTenThirtyFive(child['timetable'] as Json);
  child['homework'] = _homeworkSnapshot();
  final latest = _announcements();
  d['announcements'] = {'unreadCount': latest.where((a) => a['read'] != true).length, 'pendingAckCount': 0, 'latest': latest};
  d['calendar'] = _calendar(withPtm: true);
  return d;
}

/// The homework with the teacher's marks and feedback.
String get _homeworkId => (_fx('homework_detail') as Json)['id'] as String;
String get _examId => (((_fx('results') as Json)['data'] as List).first as Map)['examId'] as String;
String get _unpaidInvoiceId => (((_fx('invoices') as Json)['data'] as List).cast<Map<String, dynamic>>().firstWhere((i) => i['status'] == 'unpaid'))['id'] as String;

/// Everything the screens ask for, from the recorded data. Anything else is a 404, which would show an error
/// state, which fails the render: the screens must be fully backed by real content.
(int, Object?) _serve(Recorded r) {
  if (r.method != 'GET') return (200, {'ok': true});
  final p = r.path;
  final exact = <String, Object? Function()>{
    '/site/info': () => _fx('site_info'),
    '/dashboard/student': _studentDashboard,
    '/dashboard/parent': _parentDashboard,
    '/notifications/unread-count': () => {'unread': 3},
    '/fees/invoices': () => _fx('invoices'),
    '/payments': () => _fx('payments'),
    '/results': () => _fx('results'),
    '/results/progress': () => _fx('progress'),
  };
  final hit = exact[p];
  if (hit != null) return (200, hit());
  final patterns = <RegExp, Object? Function()>{
    RegExp(r'^/homework/[^/]+$'): () => _fx('homework_detail'),
    RegExp(r'^/homework/[^/]+/submission$'): () => _fx('submission'),
    RegExp(r'^/fees/invoices/[^/]+$'): () => _fx('invoice_detail'),
    RegExp(r'^/report-cards/[^/]+/students/[^/]+$'): () => _fx('report_card'),
  };
  for (final e in patterns.entries) {
    if (e.key.hasMatch(p)) return (200, e.value());
  }
  return (404, {'title': 'No recorded data for $p', 'code': 'NOT_FOUND', 'status': 404});
}

// ---------------------------------------------------------------------------------------------------------------
// The rendering harness.

/// A plain status bar (time and system icons) so the top of the screen looks like a phone.
class _StatusBar extends StatelessWidget {
  const _StatusBar({this.color});

  /// Opaque when content scrolls under the bar; transparent otherwise (the screen's own header shows through).
  final Color? color;
  @override
  Widget build(BuildContext context) {
    final ink = Theme.of(context).colorScheme.onSurface;
    return Material(
      color: color ?? Colors.transparent,
      child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22),
      child: Row(
        children: [
          Text('10:35', style: TextStyle(fontFamily: kFontSans, fontSize: 13, fontWeight: FontWeight.w600, color: ink)),
          const Spacer(),
          Icon(Icons.signal_cellular_alt_rounded, size: 15, color: ink),
          const SizedBox(width: 5),
          Icon(Icons.wifi_rounded, size: 15, color: ink),
          const SizedBox(width: 5),
          Icon(Icons.battery_full_rounded, size: 16, color: ink),
        ],
      ),
    ),
    );
  }
}

/// The bottom navigation of a role around one of its tab screens (the real [AppBottomNav] and tab list).
Widget _tabFrame(Experience experience, int index, Widget body) {
  final tabs = tabsFor(experience);
  return Scaffold(
    body: body,
    bottomNavigationBar: AppBottomNav(
      index: index,
      destinations: [for (final t in tabs) NavDestination(label: t.label, icon: t.icon, selectedIcon: t.selectedIcon)],
      onSelected: (_) {},
    ),
  );
}

Future<void> _settle(WidgetTester tester, {int rounds = 14}) async {
  for (var i = 0; i < rounds; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 40)));
    await tester.pump(const Duration(milliseconds: 150));
  }
}

/// Builds [screen] on a 390x844 phone and writes `<name>.png`. [act] can drive the UI before the picture is taken.
Future<void> _render(
  WidgetTester tester,
  String name,
  Widget screen, {
  required AppSession session,
  Color brand = const Color(0xFF0E5A63),
  FakeApi? api,
  bool pushed = false,
  double scroll = 0,
  Future<void> Function()? act,
}) async {
  tester.view.physicalSize = Size(_logical.width * _ratio, _logical.height * _ratio);
  tester.view.devicePixelRatio = _ratio;
  addTearDown(tester.view.reset);

  SharedPreferences.setMockInitialValues({});
  final prefs = AppPrefs(await SharedPreferences.getInstance());
  final server = api ??
      (FakeApi()
        ..fallback = (r) {
          try {
            return _serve(r);
          } catch (e, st) {
            debugPrint('SERVE ERROR for ${r.path}: $e\n$st');
            rethrow;
          }
        });
  final key = GlobalKey();
  final navigator = GlobalKey<NavigatorState>();

  await tester.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: [
        apiClientProvider.overrideWithValue(clientFor(server)),
        secureStoreProvider.overrideWithValue(SecureStore(MemorySecureKv())),
        prefsProvider.overrideWithValue(prefs),
        sessionProvider.overrideWith(() => _Session(session)),
        developerOptionsEnabledProvider.overrideWithValue(false),
      ],
      child: RepaintBoundary(
        key: key,
        child: MaterialApp(
          navigatorKey: navigator,
          debugShowCheckedModeBanner: false,
          theme: buildTheme(brand, Brightness.light),
          builder: (context, child) {
            const bar = EdgeInsets.only(top: 30, bottom: 14);
            final mq = MediaQuery.of(context);
            return MediaQuery(
              data: mq.copyWith(padding: bar, viewPadding: bar),
              child: Stack(children: [Positioned.fill(child: child!), Positioned(top: 0, left: 0, right: 0, height: 30, child: _StatusBar(color: scroll == 0 ? null : Colors.white))]),
            );
          },
          // A pushed screen is opened on top of another route, like in the app, so its back arrow shows.
          home: pushed ? const Scaffold() : screen,
        ),
      ),
    ),
  );
  if (pushed) unawaited(navigator.currentState!.push(MaterialPageRoute<void>(builder: (_) => screen)));
  await _settle(tester);
  if (scroll != 0) {
    await tester.drag(find.byType(Scrollable).first, Offset(0, -scroll));
    await _settle(tester, rounds: 6);
  }
  if (act != null) {
    await act();
    await _settle(tester);
  }

  // The brochure must show finished screens: no spinner, skeleton, error or empty state.
  final errors = find.byType(ErrorState);
  expect(errors, findsNothing, reason: '$name shows an error: ${errors.evaluate().isEmpty ? '' : tester.widget<ErrorState>(errors).error}. Requests: ${server.requests}');
  expect(find.byType(SkeletonList), findsNothing, reason: '$name is still loading');
  expect(find.byType(EmptyState), findsNothing, reason: '$name shows an empty state');
  expect(find.byType(CircularProgressIndicator), findsNothing, reason: '$name shows a spinner');
  expect(tester.takeException(), isNull);

  final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final bytes = await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: _ratio);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return data!.buffer.asUint8List();
  });
  Directory(_out).createSync(recursive: true);
  File('$_out/$name.png').writeAsBytesSync(bytes!);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('brochure screens (mobile, student and parent)', () {
    final realNow = appNow;
    setUpAll(() async {
      await loadAppFonts();
      await loadIconFont();
      appNow = () => _now;
    });
    tearDownAll(() => appNow = realNow);

    const none = AppSession(ready: true, introSeen: false);
    final withSite = AppSession(ready: true, introSeen: true, site: const SiteAddress(baseUrl: 'https://greenvalley.schoolsync.app', input: 'greenvalley', tenantCode: 'demo'), siteInfo: _site());

    // Before a school is chosen the app uses the SchoolSync brand colour; it switches to the school's colour afterwards.
    testWidgets('01 intro: students', (tester) => _render(tester, '01-intro-students', const IntroScreen(), session: none));

    testWidgets('02 intro: parents', (tester) {
      return _render(tester, '02-intro-parents', const IntroScreen(), session: none, act: () async {
        await tester.tap(find.text('Next'));
        await _settle(tester, rounds: 8);
      });
    });

    testWidgets('03 connect school: "Is this your school?"', (tester) {
      return _render(tester, '03-connect-school', const ConnectSchoolScreen(), session: none, act: () async {
        await tester.enterText(find.byType(TextField), 'greenvalley');
        await tester.pump();
        await tester.tap(find.text('Find my school'));
        await _settle(tester, rounds: 6);
        expect(find.text('Is this your school?'), findsOneWidget);
      });
    });

    testWidgets('04 login', (tester) {
      return _render(tester, '04-login', const LoginScreen(), session: withSite, brand: _schoolGreen, act: () async {
        await tester.enterText(find.byType(TextFormField).at(0), 'gv20260001');
        await tester.enterText(find.byType(TextFormField).at(1), 'Demo@12345');
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pump();
      });
    });

    testWidgets('05 student home', (tester) {
      return _render(tester, '05-student-home', _tabFrame(Experience.student, 0, const StudentHomeScreen()), session: _signedIn('student'), brand: _schoolGreen);
    });

    testWidgets('05b student home: homework, attendance, exams', (tester) {
      return _render(tester, '05b-student-home-scrolled', _tabFrame(Experience.student, 0, const StudentHomeScreen()), session: _signedIn('student'), brand: _schoolGreen, scroll: 740);
    });

    testWidgets('06 student homework: marked, with feedback', (tester) {
      return _render(tester, '06-student-homework', HomeworkDetailScreen(homeworkId: _homeworkId), session: _signedIn('student'), brand: _schoolGreen, pushed: true);
    });

    testWidgets('07a parent home: top (child selector, today)', (tester) {
      return _render(tester, '07a-parent-home-top', _tabFrame(Experience.parent, 0, const ParentHomeScreen()), session: _signedIn('parent'), brand: _schoolGreen);
    });

    testWidgets('07 parent home: attendance, homework, fees due', (tester) {
      return _render(tester, '07-parent-home', _tabFrame(Experience.parent, 0, const ParentHomeScreen()), session: _signedIn('parent'), brand: _schoolGreen, scroll: 810);
    });

    testWidgets('08 parent fees', (tester) {
      return _render(tester, '08-parent-fees', _tabFrame(Experience.parent, 3, const FeesScreen(embedded: true)), session: _signedIn('parent'), brand: _schoolGreen);
    });

    testWidgets('08b parent fee invoice', (tester) {
      return _render(tester, '08b-parent-invoice', InvoiceScreen(invoiceId: _unpaidInvoiceId), session: _signedIn('parent'), brand: _schoolGreen, pushed: true);
    });

    testWidgets('09 student results: report card', (tester) {
      return _render(tester, '09-student-results', ReportCardScreen(examId: _examId), session: _signedIn('student'), brand: _schoolGreen, pushed: true);
    });
  }, skip: _skip);
}
