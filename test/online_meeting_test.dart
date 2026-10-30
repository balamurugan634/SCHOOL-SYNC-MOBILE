import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schoolsync/core/design/design.dart';
import 'package:schoolsync/core/util/external_launcher.dart';
import 'package:schoolsync/data/json.dart';
import 'package:schoolsync/data/models/events.dart';
import 'package:schoolsync/data/models/meetings.dart';
import 'package:schoolsync/data/models/online_meeting.dart';
import 'package:schoolsync/data/models/staff/comms.dart';
import 'package:schoolsync/features/events/event_detail_screen.dart';
import 'package:schoolsync/features/events/events_screen.dart';
import 'package:schoolsync/features/meetings/meetings_screen.dart' as parent;
import 'package:schoolsync/features/workspace/meetings/meetings_screen.dart' as staff;

import 'staff_test_support.dart' as staff_support;
import 'support/fake_api.dart';
import 'support/fonts.dart';
import 'support/learner_harness.dart';
import 'workspace_test_support.dart';

/// Records what would have been opened; nothing leaves the test.
class FakeLauncher implements ExternalLauncher {
  final List<Uri> opened = [];
  bool result = true;

  @override
  Future<bool> open(Uri uri) async {
    opened.add(uri);
    return result;
  }
}

const _join = 'https://zoom.us/j/123456789?pwd=abc';
const _start = 'https://zoom.us/s/123456789?zak=host';

/// The API's `onlineMeeting` object as the contract describes it.
Map<String, dynamic> _meeting({String provider = 'zoom', String status = 'scheduled', Object? joinUrl = _join, Object? passcode = '482913', Object? startUrl}) => {'provider': provider, 'status': status, 'joinUrl': joinUrl, 'passcode': passcode, 'startUrl': ?startUrl};

OnlineMeeting _om({OnlineProvider provider = OnlineProvider.zoom, OnlineMeetingStatus status = OnlineMeetingStatus.scheduled, String? joinUrl = _join, String? passcode = '482913', String? startUrl}) =>
    OnlineMeeting(provider: provider, status: status, joinUrl: joinUrl, passcode: passcode, startUrl: startUrl);

Map<String, dynamic> _failed() => _meeting(status: 'failed', joinUrl: null, passcode: null);
Map<String, dynamic> _cancelled() => _meeting(status: 'cancelled', joinUrl: null, passcode: null);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadAppFonts);

  group('OnlineMeeting parsing', () {
    test('absent, null and non-object values mean no online meeting', () {
      expect(OnlineMeeting.tryParse(null), isNull);
      expect(OnlineMeeting.tryParse('zoom'), isNull);
      expect(OnlineMeeting.tryParse(<Object>[]), isNull);
      expect(OnlineMeeting.tryParse(<String, dynamic>{}), isNull);
    });

    test('an unknown provider or status is treated as no meeting, not a crash', () {
      expect(OnlineMeeting.tryParse(_meeting(provider: 'teams')), isNull);
      expect(OnlineMeeting.tryParse(_meeting(provider: 'webex')), isNull);
      expect(OnlineMeeting.tryParse(_meeting(status: 'rescheduled')), isNull);
      expect(OnlineMeeting.tryParse(_meeting(status: 'started')), isNull);
      expect(OnlineMeeting.tryParse({'provider': 7, 'status': true}), isNull);
      expect(OnlineMeeting.tryParse({'status': 'scheduled', 'joinUrl': _join}), isNull, reason: 'no provider');
      expect(OnlineMeeting.tryParse({'provider': 'zoom', 'joinUrl': _join}), isNull, reason: 'no status');
    });

    test('both providers', () {
      expect(OnlineMeeting.tryParse(_meeting(provider: 'zoom'))!.provider, OnlineProvider.zoom);
      expect(OnlineMeeting.tryParse(_meeting(provider: 'google'))!.provider, OnlineProvider.google);
      expect(OnlineProvider.zoom.label, 'Zoom');
      expect(OnlineProvider.google.label, 'Google Meet');
    });

    test('scheduled keeps the join link and passcode; no host link without startUrl', () {
      final m = OnlineMeeting.tryParse(_meeting())!;
      expect(m.status, OnlineMeetingStatus.scheduled);
      expect(m.isScheduled, isTrue);
      expect(m.joinUrl, _join);
      expect(m.passcode, '482913');
      expect(m.startUrl, isNull);
    });

    test('startUrl is read when the server sends it (staff who may edit)', () {
      expect(OnlineMeeting.tryParse(_meeting(startUrl: _start))!.startUrl, _start);
    });

    test('failed and cancelled have no links', () {
      final failed = OnlineMeeting.tryParse(_failed())!;
      expect(failed.status, OnlineMeetingStatus.failed);
      expect(failed.isScheduled, isFalse);
      expect(failed.joinUrl, isNull);
      expect(failed.passcode, isNull);
      final cancelled = OnlineMeeting.tryParse({..._cancelled(), 'provider': 'google'})!;
      expect(cancelled.status, OnlineMeetingStatus.cancelled);
      expect(cancelled.isScheduled, isFalse);
      expect(cancelled.provider, OnlineProvider.google);
    });

    test('blank strings count as missing, and odd types do not crash', () {
      final m = OnlineMeeting.tryParse({'provider': 'google', 'status': 'scheduled', 'joinUrl': '  ', 'passcode': '', 'startUrl': null})!;
      expect(m.joinUrl, isNull);
      expect(m.passcode, isNull);
      expect(m.startUrl, isNull);
      expect(OnlineMeeting.tryParse({'provider': 'zoom', 'status': 'scheduled', 'joinUrl': _join, 'passcode': 123456})!.passcode, '123456');
    });

    test('equality, and links stay out of toString', () {
      expect(OnlineMeeting.tryParse(_meeting(startUrl: _start)), OnlineMeeting.tryParse(_meeting(startUrl: _start)));
      expect(OnlineMeeting.tryParse(_meeting()), isNot(OnlineMeeting.tryParse(_meeting(passcode: '000000'))));
      expect(OnlineMeeting.tryParse(_meeting(startUrl: _start)).toString(), isNot(contains('zoom.us')));
      expect(OnlineMeeting.tryParse(_meeting()).toString(), isNot(contains('482913')));
    });

    test('SchoolEvent: present, null and absent', () {
      final base = fixture('event_consent') as Json;
      expect(SchoolEvent.fromJson(base).onlineMeeting, isNull, reason: 'older server: field absent');
      expect(SchoolEvent.fromJson({...base, 'onlineMeeting': null}).onlineMeeting, isNull);
      expect(SchoolEvent.fromJson({...base, 'onlineMeeting': _meeting(provider: 'skype')}).onlineMeeting, isNull);
      final e = SchoolEvent.fromJson({...base, 'onlineMeeting': _meeting(provider: 'google', joinUrl: 'https://meet.google.com/abc-defg-hij', passcode: null)});
      expect(e.onlineMeeting!.provider, OnlineProvider.google);
      expect(e.onlineMeeting!.joinUrl, 'https://meet.google.com/abc-defg-hij');
      expect(e.title, base['title'], reason: 'the rest of the event still parses');
    });

    test('Meeting (parent): present, null and absent', () {
      final base = ((fixture('meetings') as Json)['data'] as List).first as Json;
      expect(Meeting.fromJson(base).onlineMeeting, isNull);
      expect(Meeting.fromJson({...base, 'onlineMeeting': null}).onlineMeeting, isNull);
      expect(Meeting.fromJson({...base, 'onlineMeeting': _meeting(status: 'zzz')}).onlineMeeting, isNull);
      final m = Meeting.fromJson({...base, 'onlineMeeting': _meeting(startUrl: _start)});
      expect(m.onlineMeeting!.startUrl, _start);
      expect(m.topic, base['topic']);
    });

    test('StaffMeeting: present, null and absent', () {
      final base = (staff_support.fixture('meetings')['data'] as List).first as Json;
      expect(StaffMeeting.fromJson(base).onlineMeeting, isNull);
      expect(StaffMeeting.fromJson({...base, 'onlineMeeting': null}).onlineMeeting, isNull);
      expect(StaffMeeting.fromJson({...base, 'onlineMeeting': _failed()}).onlineMeeting!.status, OnlineMeetingStatus.failed);
      expect(StaffMeeting.fromJson({...base, 'onlineMeeting': _meeting(startUrl: _start)}).onlineMeeting!.startUrl, _start);
    });
  });

  group('httpsUri', () {
    test('accepts https links only', () {
      expect(httpsUri(_join)?.toString(), _join);
      expect(httpsUri('  https://meet.google.com/abc-defg-hij  ')?.host, 'meet.google.com');
      expect(httpsUri('HTTPS://meet.google.com/x')?.scheme, 'https');
      for (final bad in ['http://zoom.us/j/1', 'javascript:alert(1)', 'intent://x#Intent;scheme=zoomus;end', 'file:///etc/passwd', 'tel:+911234567890', 'zoommtg://zoom.us/join?confno=1', '//zoom.us/j/1', 'zoom.us/j/1', 'https://', 'https:///j/1', 'https://zoom.us@evil.example/j/1', '', '   ', 'not a url']) {
        expect(httpsUri(bad), isNull, reason: bad);
      }
      expect(httpsUri(null), isNull);
    });
  });

  group('OnlineMeetingCard', () {
    late FakeLauncher launcher;
    late List<String> copied;

    setUp(() {
      launcher = FakeLauncher();
      copied = [];
    });

    Future<void> pump(WidgetTester tester, OnlineMeeting meeting, {double scale = 1}) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') copied.add((call.arguments as Map)['text'] as String);
        return null;
      });
      addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
      await tester.pumpWidget(
        ProviderScope(
          overrides: [externalLauncherProvider.overrideWithValue(launcher)],
          child: MaterialApp(
            theme: buildTheme(kDefaultBrand, Brightness.light),
            builder: (context, child) => MediaQuery(data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)), child: child!),
            home: Scaffold(
              body: SingleChildScrollView(padding: const EdgeInsets.all(Gaps.page), child: OnlineMeetingCard(meeting: meeting)),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    for (final scale in [1.0, 2.0]) {
      final pct = (scale * 100).round();

      testWidgets('scheduled, everything present, at $pct% text: no overflow, all actions there', (tester) async {
        await pump(tester, _om(startUrl: _start), scale: scale);
        expect(tester.takeException(), isNull);
        expect(find.text('Zoom'), findsOneWidget);
        expect(find.text('Join meeting'), findsOneWidget);
        expect(find.text('Copy link'), findsOneWidget);
        expect(find.text('Passcode'), findsOneWidget);
        expect(find.text('482913'), findsOneWidget);
        expect(find.byTooltip('Copy passcode'), findsOneWidget);
        expect(find.text('Start meeting'), findsOneWidget);
        // 48 dp touch targets
        for (final target in [find.widgetWithText(FilledButton, 'Join meeting'), find.widgetWithText(OutlinedButton, 'Copy link'), find.widgetWithText(OutlinedButton, 'Start meeting'), find.byTooltip('Copy passcode')]) {
          final size = tester.getSize(target);
          expect(size.height, greaterThanOrEqualTo(48), reason: '$target');
          expect(size.width, greaterThanOrEqualTo(48), reason: '$target');
        }
      });

      testWidgets('failed at $pct% text: calm notice, no buttons, no overflow', (tester) async {
        await pump(tester, _om(status: OnlineMeetingStatus.failed, joinUrl: null, passcode: null), scale: scale);
        expect(tester.takeException(), isNull);
        expect(find.text('The online meeting could not be created. Ask the school to retry.'), findsOneWidget);
        expect(find.byType(InfoBanner), findsOneWidget);
        expect(find.byType(FilledButton), findsNothing);
        expect(find.byType(OutlinedButton), findsNothing);
        expect(find.text('Join meeting'), findsNothing);
      });

      testWidgets('cancelled at $pct% text: muted line, no buttons, no overflow', (tester) async {
        await pump(tester, _om(provider: OnlineProvider.google, status: OnlineMeetingStatus.cancelled, joinUrl: null, passcode: null), scale: scale);
        expect(tester.takeException(), isNull);
        expect(find.text('This online meeting was cancelled'), findsOneWidget);
        expect(find.byType(FilledButton), findsNothing);
        expect(find.byType(OutlinedButton), findsNothing);
        expect(find.byType(IconButton), findsNothing);
      });
    }

    testWidgets('Google Meet without a passcode or host link shows only Join and Copy link', (tester) async {
      await pump(tester, _om(provider: OnlineProvider.google, joinUrl: 'https://meet.google.com/abc-defg-hij', passcode: null));
      expect(find.text('Google Meet'), findsOneWidget);
      expect(find.text('Join meeting'), findsOneWidget);
      expect(find.text('Copy link'), findsOneWidget);
      expect(find.text('Passcode'), findsNothing);
      expect(find.byTooltip('Copy passcode'), findsNothing);
      expect(find.text('Start meeting'), findsNothing, reason: 'the host link is only for staff who may edit');
    });

    testWidgets('Join meeting opens the join link outside the app', (tester) async {
      await pump(tester, _om());
      await tester.tap(find.text('Join meeting'));
      await tester.pump();
      expect(launcher.opened, [Uri.parse(_join)]);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('Start meeting opens the host link, never the join link', (tester) async {
      await pump(tester, _om(startUrl: _start));
      await tester.tap(find.text('Start meeting'));
      await tester.pump();
      expect(launcher.opened, [Uri.parse(_start)]);
    });

    testWidgets('a system that cannot open the link gets a snackbar', (tester) async {
      launcher.result = false;
      await pump(tester, _om());
      await tester.tap(find.text('Join meeting'));
      await tester.pump();
      expect(launcher.opened, hasLength(1));
      expect(find.textContaining('could not be opened'), findsOneWidget);
    });

    testWidgets('Copy link puts the join link on the clipboard and never opens it', (tester) async {
      await pump(tester, _om());
      await tester.tap(find.text('Copy link'));
      await tester.pump();
      expect(copied, [_join]);
      expect(find.text('Meeting link copied'), findsOneWidget);
      expect(launcher.opened, isEmpty);
    });

    testWidgets('the passcode copy button puts the passcode on the clipboard', (tester) async {
      await pump(tester, _om());
      await tester.tap(find.byTooltip('Copy passcode'));
      await tester.pump();
      expect(copied, ['482913']);
      expect(find.text('Passcode copied'), findsOneWidget);
    });

    for (final bad in ['http://zoom.us/j/123', 'javascript:alert(1)', 'intent://zoom.us/j/1#Intent;scheme=https;end', 'zoommtg://zoom.us/join?confno=1', 'https://zoom.us@evil.example/j/1', 'zoom.us/j/1']) {
      testWidgets('only https is ever launched: "$bad" is not', (tester) async {
        await pump(tester, _om(joinUrl: bad, startUrl: bad));
        expect(tester.takeException(), isNull);
        expect(find.text('Join meeting'), findsNothing);
        expect(find.text('Start meeting'), findsNothing);
        expect(find.text('Copy link'), findsNothing);
        expect(find.text('The meeting link is not available yet.'), findsOneWidget);
        expect(launcher.opened, isEmpty);
      });
    }

    testWidgets('a join link that is https but a host link that is not: only the safe one is offered', (tester) async {
      await pump(tester, _om(startUrl: 'http://zoom.us/s/1'));
      expect(find.text('Join meeting'), findsOneWidget);
      expect(find.text('Start meeting'), findsNothing);
    });

    testWidgets('screen readers get names for the heading, the buttons and the icon-only copy button', (tester) async {
      final handle = tester.ensureSemantics();
      await pump(tester, _om(startUrl: _start));
      expect(find.bySemanticsLabel(RegExp('Online meeting')), findsWidgets);
      expect(find.bySemanticsLabel('Join meeting'), findsOneWidget);
      expect(find.bySemanticsLabel('Copy link'), findsOneWidget);
      // The icon-only button is named by its tooltip.
      final copy = tester.getSemantics(find.byTooltip('Copy passcode'));
      expect('${copy.label} ${copy.tooltip}', contains('Copy passcode'));
      expect(find.bySemanticsLabel('Start meeting'), findsOneWidget);
      handle.dispose();
    });
  });

  group('screens', () {
    late FakeApi api;
    late FakeLauncher launcher;

    Future<void> settle(WidgetTester tester) async {
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 120));
      }
    }

    /// A 360 dp wide phone; [tall] makes it tall enough to build every card of a list without scrolling.
    void phone(WidgetTester tester, {bool tall = false}) {
      tester.view.physicalSize = Size(1080, tall ? 9000 : 2400);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
    }

    Future<void> show(WidgetTester tester, String role, Widget screen, {double scale = 1, bool tall = false}) async {
      phone(tester, tall: tall);
      await tester.pumpWidget(await appAround(api, loadMe(role), screen, textScale: scale, overrides: [externalLauncherProvider.overrideWithValue(launcher)]));
      await settle(tester);
    }

    /// Scrolls the text into view (the screen may be longer than the phone) and taps it.
    Future<void> tapText(WidgetTester tester, String text) async {
      await tester.ensureVisible(find.text(text));
      await tester.pump();
      await tester.tap(find.text(text));
      await tester.pump();
    }

    Future<void> leave(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 1));
    }

    Map<String, dynamic> event(Object? online) => {...(fixture('event_consent') as Json), 'id': 'e1', 'onlineMeeting': online};

    setUp(() {
      api = FakeApi()..fallback = serveFixtures;
      launcher = FakeLauncher();
    });

    for (final role in ['student', 'parent', 'teacher', 'management', 'principal']) {
      testWidgets('event detail as $role shows the online meeting card and joins from it', (tester) async {
        api.on('GET /events/e1', event(_meeting(provider: 'google', joinUrl: 'https://meet.google.com/abc-defg-hij', passcode: null)));
        await show(tester, role, const EventDetailScreen(id: 'e1'));
        expect(find.byType(OnlineMeetingCard), findsOneWidget);
        expect(find.text('Google Meet'), findsOneWidget);
        await tapText(tester, 'Join meeting');
        expect(launcher.opened, [Uri.parse('https://meet.google.com/abc-defg-hij')]);
        expect(find.text('Start meeting'), findsNothing);
        await leave(tester);
      });
    }

    testWidgets('event detail for the staff who may edit offers Start meeting; at 200% text it still fits', (tester) async {
      api.on('GET /events/e1', event(_meeting(startUrl: _start)));
      await show(tester, 'teacher', const EventDetailScreen(id: 'e1'), scale: 2);
      expect(tester.takeException(), isNull);
      await tapText(tester, 'Start meeting');
      expect(launcher.opened, [Uri.parse(_start)]);
      await leave(tester);
    });

    testWidgets('event detail without an online meeting is unchanged (null, then absent)', (tester) async {
      api.on('GET /events/e1', event(null));
      await show(tester, 'parent', const EventDetailScreen(id: 'e1'));
      expect(find.byType(OnlineMeetingCard), findsNothing);
      expect(find.textContaining('field trip'), findsWidgets, reason: 'the event itself still renders');
      await leave(tester);

      api.on('GET /events/e1', {...(fixture('event_consent') as Json), 'id': 'e1'});
      await show(tester, 'parent', const EventDetailScreen(id: 'e1'));
      expect(find.byType(OnlineMeetingCard), findsNothing);
      expect(find.textContaining('field trip'), findsWidgets);
      await leave(tester);
    });

    testWidgets('event detail with a failed and a cancelled meeting', (tester) async {
      api.on('GET /events/e1', event(_failed()));
      await show(tester, 'parent', const EventDetailScreen(id: 'e1'));
      expect(find.text('The online meeting could not be created. Ask the school to retry.'), findsOneWidget);
      await leave(tester);

      api.on('GET /events/e1', event(_cancelled()));
      await show(tester, 'parent', const EventDetailScreen(id: 'e1'));
      expect(find.text('This online meeting was cancelled'), findsOneWidget);
      expect(find.text('Join meeting'), findsNothing);
      await leave(tester);
    });

    for (final scale in [1.0, 2.0]) {
      testWidgets('event list: the Online chip only on scheduled online events (${(scale * 100).round()}% text)', (tester) async {
        final list = fixture('events_parent') as Json;
        final data = jsonList(list['data']).map(Map<String, dynamic>.of).toList();
        expect(data.length, greaterThanOrEqualTo(4));
        data[0]['onlineMeeting'] = _meeting();
        data[1]['onlineMeeting'] = _failed();
        data[2]['onlineMeeting'] = _cancelled();
        data[3]['onlineMeeting'] = {'provider': 'teams', 'status': 'scheduled', 'joinUrl': _join};
        api.on('GET /events', {...list, 'data': data});
        await show(tester, 'parent', const EventsScreen(), scale: scale, tall: true);
        expect(tester.takeException(), isNull);
        expect(find.byType(OnlineChip), findsOneWidget);
        expect(find.text('Online'), findsOneWidget);
        await leave(tester);
      });
    }

    testWidgets('parent meetings: card with Join on the meeting, chip in its header', (tester) async {
      final list = fixture('meetings') as Json;
      final data = jsonList(list['data']).map(Map<String, dynamic>.of).toList();
      final i = data.indexWhere((m) => m['status'] == 'confirmed');
      expect(i, isNonNegative, reason: 'the demo data has a confirmed meeting');
      data[i]['mode'] = 'online';
      data[i]['onlineMeeting'] = _meeting();
      api.on('GET /meetings', {...list, 'data': data});
      await show(tester, 'parent', const parent.MeetingsScreen(), tall: true);
      expect(find.byType(OnlineMeetingCard), findsOneWidget);
      expect(find.byType(OnlineChip), findsOneWidget);
      await tapText(tester, 'Join meeting');
      expect(launcher.opened, [Uri.parse(_join)]);
      await leave(tester);
    });

    testWidgets('parent meetings at 200% text: failed, cancelled and scheduled cards do not overflow', (tester) async {
      final list = fixture('meetings') as Json;
      final data = jsonList(list['data']).map(Map<String, dynamic>.of).toList();
      data[0]['onlineMeeting'] = _failed();
      data[1]['onlineMeeting'] = _cancelled();
      data[2]['onlineMeeting'] = _meeting(startUrl: _start);
      api.on('GET /meetings', {...list, 'data': data});
      await show(tester, 'parent', const parent.MeetingsScreen(), scale: 2, tall: true);
      expect(tester.takeException(), isNull);
      expect(find.byType(OnlineMeetingCard), findsNWidgets(3));
      expect(find.byType(OnlineChip), findsOneWidget);
      await leave(tester);
    });

    group('teacher / office meetings', () {
      Widget staffScreen() => ProviderScope(overrides: [externalLauncherProvider.overrideWithValue(launcher)], child: const staff.MeetingsScreen());

      Map<String, dynamic> meetingsWith(List<Object?> online, {bool typedLink = false}) {
        final list = staff_support.fixture('meetings');
        final data = jsonList(list['data']).map(Map<String, dynamic>.of).toList();
        for (final (i, o) in online.indexed) {
          data[i]['onlineMeeting'] = o;
          if (typedLink) {
            data[i]['mode'] = 'online';
            data[i]['locationOrLink'] = 'https://typed.example/room';
          }
        }
        return {...list, 'data': data};
      }

      testWidgets('shows the card and the chip; Start meeting for staff who may edit; the typed link yields to the generated one', (tester) async {
        phone(tester, tall: true);
        // Both meetings are online with a hand-typed link: only the one without a working generated link keeps "Open meeting link".
        final server = staff_support.FakeServer()..on('GET /meetings', meetingsWith([_meeting(startUrl: _start), _failed()], typedLink: true));
        await tester.pumpWidget(workspaceHarness(server, staffScreen()));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.byType(OnlineMeetingCard), findsNWidgets(2));
        expect(find.byType(OnlineChip), findsOneWidget, reason: 'only the scheduled one is chipped');
        expect(find.text('Start meeting'), findsOneWidget);
        expect(find.text('The online meeting could not be created. Ask the school to retry.'), findsOneWidget);
        expect(find.text('Open meeting link'), findsOneWidget);

        await tapText(tester, 'Join meeting');
        expect(launcher.opened, [Uri.parse(_join)]);
      });

      testWidgets('a meeting without onlineMeeting keeps its own link button and gets no card', (tester) async {
        phone(tester, tall: true);
        final server = staff_support.FakeServer()..on('GET /meetings', meetingsWith([null], typedLink: true));
        await tester.pumpWidget(workspaceHarness(server, staffScreen()));
        await tester.pumpAndSettle();
        expect(find.byType(OnlineMeetingCard), findsNothing);
        expect(find.byType(OnlineChip), findsNothing);
        expect(find.text('Open meeting link'), findsOneWidget);
      });

      testWidgets('at 200% text nothing overflows', (tester) async {
        phone(tester, tall: true);
        final server = staff_support.FakeServer()..on('GET /meetings', meetingsWith([_meeting(startUrl: _start), _failed(), _cancelled()]));
        await tester.pumpWidget(workspaceHarness(server, staffScreen(), textScale: 2));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.byType(OnlineMeetingCard), findsNWidgets(3));
      });
    });
  });
}
