import 'package:flutter_test/flutter_test.dart';
import 'package:schoolsync/core/util/site_address.dart';
import 'package:schoolsync/data/models/me.dart';
import 'package:schoolsync/data/models/site_info.dart';
import 'package:schoolsync/features/auth/session.dart';
import 'package:schoolsync/router/guard.dart';
import 'package:schoolsync/router/routes.dart';

const _info = SiteInfo(code: 'demo', name: 'Demo School', primaryColor: '#4f46e5');
const _site = SiteAddress(baseUrl: 'http://10.0.2.2:4000', input: 'demo', tenantCode: 'demo');

Me _me({bool mustChange = false, Experience e = Experience.management}) =>
    Me(id: 'u1', userType: 'staff', displayName: 'Ada Lovelace', username: 'ada', experience: e, mustChangePassword: mustChange);

AppSession _ready({
  bool intro = true,
  SiteAddress? site = _site,
  bool signedIn = false,
  Me? me,
  int primer = primerStageDone,
  bool tour = true,
  bool locked = false,
  bool forceUpdate = false,
}) => AppSession(
  ready: true,
  introSeen: intro,
  site: site,
  siteInfo: site == null ? null : _info,
  auth: signedIn ? AuthStatus.signedIn : AuthStatus.signedOut,
  me: signedIn ? (me ?? _me()) : null,
  primerStage: primer,
  tourSeen: tour,
  locked: locked,
  forceUpdate: forceUpdate,
);

void main() {
  group('targetRouteFor (the onboarding order)', () {
    test('not bootstrapped -> splash', () {
      expect(targetRouteFor(const AppSession()), Routes.splash);
    });

    test('first run -> intro, even if everything else is unknown', () {
      expect(targetRouteFor(_ready(intro: false, site: null)), Routes.intro);
    });

    test('intro seen but no site saved -> connect school', () {
      expect(targetRouteFor(_ready(site: null)), Routes.connect);
    });

    test('site saved, signed out -> login', () {
      expect(targetRouteFor(_ready()), Routes.login);
    });

    test('app version below the API minimum -> forced update', () {
      expect(targetRouteFor(_ready(forceUpdate: true)), Routes.update);
      expect(targetRouteFor(_ready(forceUpdate: true, signedIn: true)), Routes.update);
    });

    test('mustChangePassword -> forced password screen before anything else', () {
      expect(targetRouteFor(_ready(signedIn: true, me: _me(mustChange: true), primer: 0, tour: false)), Routes.forcePassword);
    });

    test('permission primers come in order: notifications, then biometric', () {
      expect(targetRouteFor(_ready(signedIn: true, primer: primerStageNotifications, tour: false)), Routes.primerNotifications);
      expect(targetRouteFor(_ready(signedIn: true, primer: primerStageBiometric, tour: false)), Routes.primerBiometric);
    });

    test('the welcome tour is a dialog over home, so an unseen tour still routes to home', () {
      expect(targetRouteFor(_ready(signedIn: true, tour: false)), Routes.home);
    });

    test('everything done -> home', () {
      expect(targetRouteFor(_ready(signedIn: true)), Routes.home);
    });

    test('app lock wins over the rest of the onboarding for a signed-in user', () {
      expect(targetRouteFor(_ready(signedIn: true, locked: true, primer: 0, tour: false)), Routes.locked);
    });

    test('"Change school" (site cleared while signed out) sends people back to connect', () {
      expect(targetRouteFor(_ready(site: null)), Routes.connect);
    });
  });

  group('redirectFor', () {
    test('leaves the splash once ready', () {
      expect(redirectFor(const AppSession(), Routes.splash), isNull);
      expect(redirectFor(_ready(signedIn: true), Routes.splash), Routes.home);
    });

    test('keeps people on the screen they are meant to be on', () {
      expect(redirectFor(_ready(), Routes.login), isNull);
      expect(redirectFor(_ready(site: null), Routes.connect), isNull);
      expect(redirectFor(_ready(signedIn: true, tour: false), Routes.home), isNull);
    });

    test('the forgot-password screen is part of the login step', () {
      expect(redirectFor(_ready(), Routes.forgot), isNull);
      expect(redirectFor(_ready(signedIn: true), Routes.forgot), Routes.home);
    });

    test('signed-out visitors are bounced from app routes to login', () {
      expect(redirectFor(_ready(), Routes.home), Routes.login);
      expect(redirectFor(_ready(), Routes.settings), Routes.login);
      expect(redirectFor(_ready(site: null), Routes.settings), Routes.connect);
    });

    test('signed-in people cannot sit on a gate screen', () {
      expect(redirectFor(_ready(signedIn: true), Routes.login), Routes.home);
      expect(redirectFor(_ready(signedIn: true), Routes.intro), Routes.home);
      expect(redirectFor(_ready(signedIn: true), Routes.connect), Routes.home);
    });

    test('deep links inside the app are allowed once onboarding is complete', () {
      expect(redirectFor(_ready(signedIn: true), '/tab/2'), isNull);
      expect(redirectFor(_ready(signedIn: true), Routes.sessions), isNull);
      expect(redirectFor(_ready(signedIn: true), '/settings/password?x=1'), isNull);
    });

    test('deep links are held back while onboarding is incomplete', () {
      expect(redirectFor(_ready(signedIn: true, primer: 0), '/tab/2'), Routes.primerNotifications);
      expect(redirectFor(_ready(signedIn: true, me: _me(mustChange: true)), Routes.home), Routes.forcePassword);
      expect(redirectFor(_ready(signedIn: true, locked: true), Routes.home), Routes.locked);
    });
  });
}
