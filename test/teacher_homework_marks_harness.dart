import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:schoolsync/core/design/design.dart';
import 'package:schoolsync/data/json.dart';
import 'package:schoolsync/data/models/me.dart';
import 'package:schoolsync/data/models/site_info.dart';
import 'package:schoolsync/data/repositories/staff/academics_repository.dart';
import 'package:schoolsync/data/repositories/staff/marks_repository.dart';
import 'package:schoolsync/data/repositories/staff/staff_homework_repository.dart';
import 'package:schoolsync/features/auth/session.dart';

import 'staff_test_support.dart';

class _FakeSession extends SessionController {
  _FakeSession(this.me, this.readOnly);
  final Me me;
  final bool readOnly;

  @override
  AppSession build() => AppSession(ready: true, auth: AuthStatus.signedIn, me: me, siteInfo: SiteInfo(code: 'demo', name: 'Demo School', primaryColor: '#1B6B4F', readOnly: readOnly));
}

Me demoTeacher() => Me.fromJson(jsonMap(jsonDecode(File('test/fixtures/me_teacher.json').readAsStringSync())));

/// The app around one screen: theme, a signed-in demo teacher, go_router (so `push` / `pop` work), and the real
/// repositories talking to [server]. The screen is opened from a home page with an "open" button, so `pop` returns there.
Widget teacherHarness(FakeServer server, Widget screen, {bool readOnly = false, double textScale = 1, Me? me}) {
  final api = apiFor(server);
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, _) => Scaffold(body: Center(child: ElevatedButton(onPressed: () => context.push('/screen'), child: const Text('open')))),
      ),
      GoRoute(path: '/screen', builder: (context, _) => screen),
      GoRoute(path: '/teacher/homework/:homeworkId', builder: (context, s) => Scaffold(body: Center(child: Text('DETAIL ${s.pathParameters['homeworkId']}')))),
      GoRoute(path: '/teacher/homework/:homeworkId/review/:submissionId', builder: (context, s) => Scaffold(body: Center(child: Text('REVIEW ${s.pathParameters['submissionId']}')))),
    ],
  );
  return ProviderScope(
    overrides: [
      sessionProvider.overrideWith(() => _FakeSession(me ?? demoTeacher(), readOnly)),
      staffHomeworkRepositoryProvider.overrideWithValue(StaffHomeworkRepository(api)),
      marksRepositoryProvider.overrideWithValue(MarksRepository(api)),
      academicsRepositoryProvider.overrideWithValue(AcademicsRepository(api)),
    ],
    child: MaterialApp.router(
      routerConfig: router,
      theme: buildTheme(kDefaultBrand, Brightness.light),
      builder: (context, child) => MediaQuery(data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)), child: child!),
    ),
  );
}

/// A phone-sized surface so list rows are on screen.
void usePhone(WidgetTester tester, {double width = 400, double height = 900}) {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Future<void> openScreen(WidgetTester tester) async {
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}
