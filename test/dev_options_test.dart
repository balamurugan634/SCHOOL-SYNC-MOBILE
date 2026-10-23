import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schoolsync/core/config/dev_options.dart';
import 'package:schoolsync/core/design/design.dart';
import 'package:schoolsync/core/providers.dart';
import 'package:schoolsync/core/storage/prefs.dart';
import 'package:schoolsync/features/onboarding/connect_school_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<(Widget, AppPrefs)> _app({required bool devEnabled}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = AppPrefs(await SharedPreferences.getInstance());
  final widget = ProviderScope(
    retry: (_, _) => null,
    overrides: [
      prefsProvider.overrideWithValue(prefs),
      developerOptionsEnabledProvider.overrideWithValue(devEnabled),
    ],
    child: MaterialApp(theme: buildTheme(kDefaultBrand, Brightness.light), home: const ConnectSchoolScreen()),
  );
  return (widget, prefs);
}

void main() {
  testWidgets('Developer options are shown in debug builds, collapsed, and persist the API address', (tester) async {
    final (app, prefs) = await _app(devEnabled: true);
    await tester.pumpWidget(app);
    await tester.pumpAndSettle();

    expect(find.text('Developer options'), findsOneWidget);
    expect(find.text('API address'), findsNothing, reason: 'collapsed by default');

    await tester.ensureVisible(find.text('Developer options'));
    await tester.tap(find.text('Developer options'));
    await tester.pumpAndSettle();
    expect(find.text('API address'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, 'API address'), '192.168.1.20:4000');
    await tester.pump();
    expect(prefs.devApi, 'http://192.168.1.20:4000');
    final container = ProviderScope.containerOf(tester.element(find.byType(ConnectSchoolScreen)));
    expect(container.read(devApiProvider), 'http://192.168.1.20:4000');
  });

  testWidgets('Developer options are absent when disabled (the release behaviour)', (tester) async {
    final (app, _) = await _app(devEnabled: false);
    await tester.pumpWidget(app);
    await tester.pumpAndSettle();
    expect(find.text('Developer options'), findsNothing);
    expect(find.text('API address'), findsNothing);
    expect(find.text('Find your school'), findsOneWidget);
  });
}
