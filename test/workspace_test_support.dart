import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schoolsync/core/design/design.dart';
import 'package:schoolsync/data/json.dart';
import 'package:schoolsync/data/models/me.dart';
import 'package:schoolsync/data/models/site_info.dart';
import 'package:schoolsync/data/repositories/staff/academics_repository.dart';
import 'package:schoolsync/data/repositories/staff/comms_repository.dart';
import 'package:schoolsync/data/repositories/staff/staff_leave_repository.dart';
import 'package:schoolsync/features/auth/session.dart';

import 'staff_test_support.dart';

class _FakeSession extends SessionController {
  _FakeSession(this.me, this.readOnly);
  final Me me;
  final bool readOnly;

  @override
  AppSession build() => AppSession(
    ready: true,
    auth: AuthStatus.signedIn,
    me: me,
    siteInfo: SiteInfo(code: 'demo', name: 'Demo School', primaryColor: '#1B6B4F', readOnly: readOnly),
  );
}

/// A real `/auth/me` payload of the demo school (`teacher`, `principal`, `management` = super admin).
Me meOf(String role) => Me.fromJson(jsonMap(jsonDecode(File('test/fixtures/me_$role.json').readAsStringSync())));

/// The same person without some permissions (to prove a screen hides what the role may not do).
Me withoutPermissions(Me base, bool Function(String key) drop) => Me(
  id: base.id,
  userType: base.userType,
  displayName: base.displayName,
  username: base.username,
  experience: base.experience,
  permissions: {for (final e in base.permissions.entries.where((e) => !drop(e.key))) e.key: e.value},
  profile: base.profile,
);

/// A phone-sized app around [screen]: theme, a fake signed-in person, and the fake server behind the repositories.
Widget workspaceHarness(FakeServer server, Widget screen, {Me? me, bool readOnly = false, double textScale = 1}) {
  final api = apiFor(server);
  return ProviderScope(
    key: UniqueKey(),
    overrides: [
      sessionProvider.overrideWith(() => _FakeSession(me ?? meOf('teacher'), readOnly)),
      commsRepositoryProvider.overrideWithValue(CommsRepository(api)),
      staffLeaveRepositoryProvider.overrideWithValue(StaffLeaveRepository(api)),
      academicsRepositoryProvider.overrideWithValue(AcademicsRepository(api)),
    ],
    child: MaterialApp(
      theme: buildTheme(kDefaultBrand, Brightness.light),
      builder: (context, child) => MediaQuery(data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)), child: child!),
      home: Scaffold(body: screen),
    ),
  );
}

/// 360 x 800 logical pixels.
void phoneSize(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}
