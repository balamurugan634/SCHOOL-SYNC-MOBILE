import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/app_exception.dart';
import '../../core/network/token_manager.dart';
import '../../core/providers.dart';
import '../../core/push/push_service.dart';
import '../../core/util/app_version.dart';
import '../../core/util/site_address.dart';
import '../../data/models/me.dart';
import '../../data/models/site_info.dart';

enum AuthStatus { signedOut, signedIn }

/// Why the person landed on the login screen without asking to.
enum SessionNotice { expired, disabled }

/// 0 = notifications primer, 1 = biometric primer, 2 = finished.
const primerStageNotifications = 0;
const primerStageBiometric = 1;
const primerStageDone = 2;

/// Everything the router needs to decide where the person belongs.
@immutable
class AppSession {
  const AppSession({
    this.ready = false,
    this.introSeen = false,
    this.site,
    this.siteInfo,
    this.auth = AuthStatus.signedOut,
    this.me,
    this.primerStage = primerStageNotifications,
    this.tourSeen = false,
    this.locked = false,
    this.forceUpdate = false,
    this.notice,
    this.offlineProfile = false,
  });

  /// Bootstrap (storage read, optional profile fetch) and the minimum splash time are done.
  final bool ready;
  final bool introSeen;
  final SiteAddress? site;
  final SiteInfo? siteInfo;
  final AuthStatus auth;
  final Me? me;
  final int primerStage;
  final bool tourSeen;
  final bool locked;
  final bool forceUpdate;
  final SessionNotice? notice;

  /// The profile shown is the cached one (could not reach the server on start).
  final bool offlineProfile;

  bool get hasSite => site != null;
  bool get signedIn => auth == AuthStatus.signedIn && me != null;

  AppSession copyWith({
    bool? ready,
    bool? introSeen,
    Object? site = _keep,
    Object? siteInfo = _keep,
    AuthStatus? auth,
    Object? me = _keep,
    int? primerStage,
    bool? tourSeen,
    bool? locked,
    bool? forceUpdate,
    Object? notice = _keep,
    bool? offlineProfile,
  }) => AppSession(
    ready: ready ?? this.ready,
    introSeen: introSeen ?? this.introSeen,
    site: identical(site, _keep) ? this.site : site as SiteAddress?,
    siteInfo: identical(siteInfo, _keep) ? this.siteInfo : siteInfo as SiteInfo?,
    auth: auth ?? this.auth,
    me: identical(me, _keep) ? this.me : me as Me?,
    primerStage: primerStage ?? this.primerStage,
    tourSeen: tourSeen ?? this.tourSeen,
    locked: locked ?? this.locked,
    forceUpdate: forceUpdate ?? this.forceUpdate,
    notice: identical(notice, _keep) ? this.notice : notice as SessionNotice?,
    offlineProfile: offlineProfile ?? this.offlineProfile,
  );
}

const Object _keep = Object();

/// Minimum time the animated splash stays up (overridable in tests).
final splashMinDurationProvider = Provider<Duration>((ref) => const Duration(milliseconds: 1900));

class SessionController extends Notifier<AppSession> {
  @override
  AppSession build() {
    final tokens = ref.read(tokenManagerProvider);
    tokens.onSessionEnded = _onSessionEnded;
    tokens.onMe = _onMeFromRefresh;
    tokens.pushTokenGetter = () => ref.read(pushServiceProvider).token;
    final prefs = ref.read(prefsProvider);
    scheduleMicrotask(_bootstrap);
    return AppSession(introSeen: prefs.introSeen);
  }

  String get _appVersion => ref.read(deviceMetaProvider).appVersion;

  Future<void> _bootstrap() async {
    final store = ref.read(secureStoreProvider);
    final prefs = ref.read(prefsProvider);
    final ctx = ref.read(clientContextProvider);
    final tokens = ref.read(tokenManagerProvider);
    final minSplash = Future<void>.delayed(ref.read(splashMinDurationProvider));

    final site = await store.readSite();
    final info = site == null ? null : await store.readSiteInfo();
    ctx.site = site;
    await tokens.load();

    var next = state.copyWith(
      site: site,
      siteInfo: info,
      forceUpdate: info != null && isBelowMinimum(_appVersion, info.minAppVersion),
      introSeen: prefs.introSeen,
    );

    if (site != null && tokens.hasSession) {
      var me = await store.readMe();
      var offline = false;
      try {
        // Fresh profile (also proves the refresh token still works).
        me = await ref.read(authRepositoryProvider).me().timeout(const Duration(seconds: 8));
        unawaited(store.writeMeJson(me.raw ?? const {}));
      } on AppException catch (e) {
        if (e.isNetwork || e.kind == ErrorKind.server) {
          offline = true;
        } else {
          me = null; // session ended; _onSessionEnded already ran or token invalid
        }
      } on TimeoutException {
        offline = true;
      }
      if (me != null && tokens.hasSession) {
        next = _withUser(next, me).copyWith(offlineProfile: offline, locked: prefs.lockEnabled);
      } else {
        if (tokens.hasSession) await tokens.clear();
        await store.clearMe();
        next = next.copyWith(auth: AuthStatus.signedOut, me: null);
      }
    }

    await minSplash;
    state = next.copyWith(ready: true, notice: state.notice);
    if (state.signedIn) unawaited(_afterSignedIn());
    if (site != null) unawaited(refreshSiteInfo());
  }

  AppSession _withUser(AppSession s, Me me) {
    final prefs = ref.read(prefsProvider);
    return s.copyWith(
      auth: AuthStatus.signedIn,
      me: me,
      primerStage: prefs.primersDone(me.id) ? primerStageDone : primerStageNotifications,
      tourSeen: prefs.tourSeen(me.id),
      notice: null,
    );
  }

  // ---------------------------------------------------------------- site

  Future<void> completeIntro() async {
    await ref.read(prefsProvider).setIntroSeen(true);
    state = state.copyWith(introSeen: true);
  }

  /// Persist a confirmed school and apply its branding.
  Future<void> saveSite(SiteAddress address, SiteInfo info) async {
    final withTenant = address.withTenant(info.code);
    final store = ref.read(secureStoreProvider);
    await store.writeSite(withTenant);
    await store.writeSiteInfo(info);
    ref.read(clientContextProvider).site = withTenant;
    state = state.copyWith(
      site: withTenant,
      siteInfo: info,
      forceUpdate: isBelowMinimum(_appVersion, info.minAppVersion),
      notice: null,
    );
  }

  /// Refresh branding, `readOnly` and minimum version from the saved school.
  Future<void> refreshSiteInfo() async {
    final site = state.site;
    if (site == null) return;
    try {
      final info = await ref.read(siteRepositoryProvider).fetchInfo(site);
      if (state.site != site) return; // school changed meanwhile
      await ref.read(secureStoreProvider).writeSiteInfo(info);
      state = state.copyWith(siteInfo: info, forceUpdate: isBelowMinimum(_appVersion, info.minAppVersion));
    } on AppException catch (e) {
      if (e.kind == ErrorKind.upgradeRequired) state = state.copyWith(forceUpdate: true);
      // Offline / transient: keep the cached branding.
    }
  }

  /// "Change school": sign out, wipe tokens and the saved site.
  Future<void> changeSchool() async {
    await _remoteSignOut();
    await ref.read(secureStoreProvider).clearAll();
    await ref.read(prefsProvider).resetForNewSchool();
    ref.read(clientContextProvider).site = null;
    await ref.read(tokenManagerProvider).clear();
    state = const AppSession(ready: true, introSeen: true, primerStage: primerStageNotifications);
  }

  // ---------------------------------------------------------------- auth

  Future<void> login(String identifier, String password) async {
    final res = await ref.read(authRepositoryProvider).login(
      identifier: identifier,
      password: password,
      device: ref.read(deviceMetaProvider),
      pushToken: ref.read(pushServiceProvider).token,
    );
    await ref.read(tokenManagerProvider).save(res.tokens);
    await ref.read(secureStoreProvider).writeMeJson(res.user.raw ?? const {});
    state = _withUser(state, res.user).copyWith(locked: false, offlineProfile: false);
    unawaited(_afterSignedIn());
  }

  Future<void> _afterSignedIn() async {
    final push = ref.read(pushServiceProvider);
    await push.start();
    if (ref.read(prefsProvider).pushEnabled && await push.isPermissionGranted()) {
      await push.syncRegistration();
    }
  }

  Future<void> refreshMe() async {
    try {
      final me = await ref.read(authRepositoryProvider).me();
      await ref.read(secureStoreProvider).writeMeJson(me.raw ?? const {});
      if (state.signedIn) state = state.copyWith(me: me, offlineProfile: false);
    } on AppException {
      // keep what we have
    }
  }

  void _onMeFromRefresh(Me me) {
    if (!state.signedIn) return;
    unawaited(ref.read(secureStoreProvider).writeMeJson(me.raw ?? const {}));
    state = state.copyWith(me: me);
  }

  /// Voluntary sign-out.
  Future<void> logout() async {
    await _remoteSignOut();
    await _clearLocalSession();
    state = state.copyWith(auth: AuthStatus.signedOut, me: null, locked: false, notice: null);
  }

  Future<void> _remoteSignOut() async {
    final tokens = ref.read(tokenManagerProvider);
    if (!tokens.hasSession) return;
    final push = ref.read(pushServiceProvider);
    try {
      final pushToken = push.token;
      await push.unregister(deleteToken: false).timeout(const Duration(seconds: 4));
      await ref.read(authRepositoryProvider).logout(pushToken: pushToken).timeout(const Duration(seconds: 5));
    } catch (_) {
      // Offline or already revoked: local sign-out still proceeds.
    }
    unawaited(push.unregister(deleteToken: true));
  }

  Future<void> _clearLocalSession() async {
    await ref.read(tokenManagerProvider).clear();
    await ref.read(secureStoreProvider).clearMe();
  }

  /// Token manager says the session cannot continue.
  void _onSessionEnded(SessionEndReason reason) {
    if (reason == SessionEndReason.userInitiated || reason == SessionEndReason.changedSchool) return;
    unawaited(ref.read(secureStoreProvider).clearMe());
    if (!state.signedIn && state.auth == AuthStatus.signedOut) return;
    state = state.copyWith(
      auth: AuthStatus.signedOut,
      me: null,
      locked: false,
      notice: reason == SessionEndReason.disabled ? SessionNotice.disabled : SessionNotice.expired,
    );
  }

  void clearNotice() {
    if (state.notice != null) state = state.copyWith(notice: null);
  }

  // ---------------------------------------------------------------- onboarding steps

  Future<void> advancePrimer() async {
    final me = state.me;
    if (me == null) return;
    final next = state.primerStage + 1;
    if (next >= primerStageDone) await ref.read(prefsProvider).setPrimersDone(me.id, true);
    state = state.copyWith(primerStage: next.clamp(0, primerStageDone));
  }

  Future<void> completeTour() async {
    final me = state.me;
    if (me == null) return;
    await ref.read(prefsProvider).setTourSeen(me.id, true);
    state = state.copyWith(tourSeen: true);
  }

  /// Settings -> "Replay welcome tour".
  Future<void> replayTour() async {
    final me = state.me;
    if (me == null) return;
    await ref.read(prefsProvider).setTourSeen(me.id, false);
    state = state.copyWith(tourSeen: false);
  }

  // ---------------------------------------------------------------- lock

  void lock() {
    if (state.signedIn && !state.locked) state = state.copyWith(locked: true);
  }

  void unlock() {
    if (state.locked) state = state.copyWith(locked: false);
  }

  /// Called after a password change cleared `mustChangePassword`.
  Future<void> passwordChanged() => refreshMe();
}

final sessionProvider = NotifierProvider<SessionController, AppSession>(SessionController.new);
