import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:go_router/go_router.dart';
import 'package:schoolsync/core/design/design.dart';
import 'package:schoolsync/core/providers.dart';
import 'package:schoolsync/core/storage/prefs.dart';
import 'package:schoolsync/core/storage/secure_store.dart';
import 'package:schoolsync/data/json.dart';
import 'package:schoolsync/data/models/me.dart';
import 'package:schoolsync/data/models/site_info.dart';
import 'package:schoolsync/features/auth/session.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_api.dart';

/// Shared by the Student/Parent screen tests.
class FixedSession extends SessionController {
  FixedSession(this.me);
  final Me me;
  @override
  AppSession build() => AppSession(ready: true, auth: AuthStatus.signedIn, me: me, siteInfo: const SiteInfo(code: 'demo', name: 'Green Valley Public School', primaryColor: '#0E5A63'), tourSeen: true);
}

Me loadMe(String role) => Me.fromJson((jsonDecode(File('test/fixtures/me_$role.json').readAsStringSync()) as Map).cast<String, dynamic>());

/// Writes answer with the shape the real API returns (so the app can parse what it gets back).
(int, Object?) _serveWrites(Recorded r) {
  final p = r.path;
  Object? f(String n) => fixture(n);
  if (p.endsWith('/submit')) return (201, f('submission'));
  if (p == '/tasks') return (201, (f('tasks') as Json)['data'][0]);
  if (p.startsWith('/tasks/')) return (200, (f('tasks') as Json)['data'][0]);
  if (p == '/leave') {
    final b = r.body as Map;
    return (201, {'id': 'l-new', 'studentName': 'Ishaan Bose', 'leaveType': b['leaveType'], 'fromDate': b['fromDate'], 'toDate': b['toDate'], 'days': 1, 'reason': b['reason'], 'status': 'pending', 'canCancel': true});
  }
  if (p == '/meetings') return (201, ((f('meetings') as Json)['data'] as List)[1]);
  if (p.endsWith('/respond')) {
    final b = r.body as Map;
    return (200, {'studentId': b['studentId'], 'studentName': 'Ishaan Bose', 'response': b['response'], 'note': b['note'], 'respondedAt': '2026-10-21T10:00:00.000Z'});
  }
  if (p.endsWith('/pay')) return (200, {'paymentId': 'p-new', 'provider': 'mock', 'orderId': 'order_1', 'amountMinor': 500000, 'currency': 'INR', 'keyId': null, 'mock': true});
  if (p.endsWith('/sync')) return (200, (f('payments') as Json)['data'][0]);
  return (200, {'ok': true});
}

/// Serves the whole read API from the recorded fixtures.
(int, Object?) serveFixtures(Recorded r) {
  final p = r.path;
  if (r.method != 'GET') return _serveWrites(r);
  Object? f(String n) => fixture(n);
  final exact = <String, Object?>{
    '/dashboard/student': f('dashboard_student'),
    '/dashboard/parent': f('dashboard_parent'),
    '/homework': f('homework_list'),
    '/tasks/feed': f('tasks_feed'),
    '/tasks': f('tasks'),
    '/timetable/me': f('timetable'),
    '/calendar': f('calendar'),
    '/exams': f('exams'),
    '/results': f('results'),
    '/results/progress': f('progress'),
    '/fees/invoices': f('invoices'),
    '/payments': f('payments'),
    '/announcements': f('announcements'),
    '/announcements/unread-count': f('announcement_counts'),
    '/events': f('events_parent'),
    '/meetings': f('meetings'),
    '/meetings/teachers': f('meeting_teachers'),
    '/leave': {'data': <Object>[], 'meta': {'page': 1, 'pageSize': 30, 'total': 0, 'totalPages': 1}},
    '/notifications': f('notifications'),
    '/notifications/unread-count': {'unread': 3},
    '/notifications/preferences': f('notification_prefs'),
    '/materials': f('materials'),
    '/syllabus/topics': f('syllabus'),
    '/library/my-books': f('library'),
    '/transport/my-bus': f('bus'),
    '/me/profile': f('profile_student'),
  };
  if (exact.containsKey(p)) return (200, exact[p]);
  final patterns = <RegExp, Object? Function()>{
    RegExp(r'^/homework/[^/]+$'): () => f('homework_detail'),
    RegExp(r'^/homework/[^/]+/submission$'): () => f('submission'),
    RegExp(r'^/attendance/students/[^/]+/summary$'): () => f('attendance_summary'),
    RegExp(r'^/attendance/students/[^/]+/records$'): () => f('attendance_records'),
    RegExp(r'^/exams/[^/]+/papers$'): () => f('exam_papers'),
    RegExp(r'^/report-cards/[^/]+/students/[^/]+$'): () => f('report_card'),
    RegExp(r'^/fees/invoices/[^/]+$'): () => f('invoice_detail'),
    RegExp(r'^/payments/[^/]+$'): () => (f('payments') as Json)['data'][0],
    RegExp(r'^/payments/[^/]+/receipt$'): () => f('receipt'),
    RegExp(r'^/announcements/[^/]+$'): () => (f('announcements') as Json)['data'][0],
    RegExp(r'^/events/[^/]+$'): () => f('event_consent'),
  };
  for (final e in patterns.entries) {
    if (e.key.hasMatch(p)) return (200, e.value());
  }
  return (404, {'title': 'No fixture for $p', 'code': 'NOT_FOUND', 'status': 404});
}

/// With [onRouter] the app uses go_router (so `context.push/pop` work); open the screen with `router.push('/screen')`.
Future<Widget> appAround(FakeApi api, Me me, Widget screen, {double textScale = 1, Brightness brightness = Brightness.light, void Function(GoRouter router)? onRouter, List<Override> overrides = const []}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = AppPrefs(await SharedPreferences.getInstance());
  return ProviderScope(
    retry: (_, _) => null,
    overrides: [
      apiClientProvider.overrideWithValue(clientFor(api)),
      secureStoreProvider.overrideWithValue(SecureStore(MemorySecureKv())),
      prefsProvider.overrideWithValue(prefs),
      sessionProvider.overrideWith(() => FixedSession(me)),
      ...overrides,
    ],
    child: _MaterialHost(screen: screen, textScale: textScale, brightness: brightness, onRouter: onRouter),
  );
}

class _MaterialHost extends StatefulWidget {
  const _MaterialHost({required this.screen, required this.textScale, required this.brightness, this.onRouter});
  final Widget screen;
  final double textScale;
  final Brightness brightness;
  final void Function(GoRouter router)? onRouter;

  @override
  State<_MaterialHost> createState() => _MaterialHostState();
}

class _MaterialHostState extends State<_MaterialHost> {
  GoRouter? _router;

  @override
  void initState() {
    super.initState();
    if (widget.onRouter != null) {
      _router = GoRouter(routes: [
        GoRoute(path: '/', builder: (_, _) => const Scaffold(body: Center(child: Text('launcher')))),
        GoRoute(path: '/screen', builder: (_, _) => widget.screen),
        // Targets the screens navigate to; the tests only need to know they were reached.
        GoRoute(path: '/fees/receipt/:id', builder: (_, s) => Scaffold(body: Center(child: Text('receipt ${s.pathParameters['id']}')))),
      ]);
      widget.onRouter!(_router!);
    }
  }

  @override
  void dispose() {
    _router?.dispose();
    super.dispose();
  }

  Widget _scale(BuildContext context, Widget? child) => MediaQuery(data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(widget.textScale)), child: child!);

  @override
  Widget build(BuildContext context) {
    final theme = buildTheme(kDefaultBrand, widget.brightness);
    if (_router != null) return MaterialApp.router(theme: theme, builder: _scale, routerConfig: _router!);
    return MaterialApp(theme: theme, builder: _scale, home: Scaffold(body: widget.screen));
  }
}
