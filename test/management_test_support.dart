import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:schoolsync/core/design/design.dart';
import 'package:schoolsync/core/providers.dart';
import 'package:schoolsync/data/json.dart';
import 'package:schoolsync/data/models/me.dart';
import 'package:schoolsync/data/models/site_info.dart';
import 'package:schoolsync/features/auth/session.dart';
import 'package:schoolsync/features/notifications/notifications_providers.dart';

import 'staff_test_support.dart';

Me meFixture(String name) {
  final path = name.startsWith('mgmt_') ? 'test/fixtures/staff/$name.json' : 'test/fixtures/me_$name.json';
  return Me.fromJson(jsonMap(jsonDecode(File(path).readAsStringSync())));
}

/// A signed-in session without touching storage or the network.
class FakeSession extends SessionController {
  FakeSession(this.me, {this.readOnly = false, this.fees = true});
  final Me me;
  final bool readOnly;
  final bool fees;

  @override
  AppSession build() => AppSession(
    ready: true,
    introSeen: true,
    auth: AuthStatus.signedIn,
    me: me,
    tourSeen: true,
    primerStage: primerStageDone,
    siteInfo: SiteInfo(code: 'demo', name: 'Green Valley School', primaryColor: '#1B6B4F', readOnly: readOnly, features: SiteFeatures(fees: fees)),
  );
}

/// Pumps [child] inside a themed app with a signed-in [me] and an API served by [server].
Future<void> pumpScreen(
  WidgetTester tester,
  Widget child, {
  required String me,
  Me? meValue,
  FakeServer? server,
  bool readOnly = false,
  bool fees = true,
  List<Override> overrides = const [],
  Size size = const Size(390, 844),
  double textScale = 1,
}) async {
  tester.view.physicalSize = size * 2;
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  final srv = server ?? FakeServer();
  await tester.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: [
        sessionProvider.overrideWith(() => FakeSession(meValue ?? meFixture(me), readOnly: readOnly, fees: fees)),
        apiClientProvider.overrideWithValue(apiFor(srv)),
        notificationsUnreadProvider.overrideWith((ref) async => 0),
        ...overrides,
      ],
      child: MaterialApp(
        theme: buildTheme(kDefaultBrand, Brightness.light),
        builder: (context, c) => MediaQuery(data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)), child: c!),
        home: Scaffold(body: child),
      ),
    ),
  );
}
