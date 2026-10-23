import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/design.dart';
import '../../router/routes.dart';
import 'auth_messages.dart';
import 'session.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _id = TextEditingController();
  final _pw = TextEditingController();
  final _pwFocus = FocusNode();
  bool _obscure = true;
  bool _loading = false;
  LoginFailure? _failure;
  int _shake = 0;
  Timer? _lockTimer;
  int _lockLeft = 0;

  @override
  void dispose() {
    _lockTimer?.cancel();
    _id.dispose();
    _pw.dispose();
    _pwFocus.dispose();
    super.dispose();
  }

  void _startLock(Duration d) {
    _lockTimer?.cancel();
    setState(() => _lockLeft = d.inSeconds);
    _lockTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _lockLeft = (_lockLeft - 1).clamp(0, 1 << 30));
      if (_lockLeft == 0) {
        t.cancel();
        setState(() => _failure = null);
      }
    });
  }

  Future<void> _submit() async {
    if (_loading || _lockLeft > 0) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    ref.read(sessionProvider.notifier).clearNotice();
    setState(() {
      _loading = true;
      _failure = null;
    });
    try {
      await ref.read(sessionProvider.notifier).login(_id.text, _pw.text);
      // The router takes over once the session is signed in.
    } catch (e) {
      if (!mounted) return;
      final f = describeLoginFailure(e);
      unawaited(HapticFeedback.heavyImpact());
      setState(() {
        _failure = f;
        _loading = false;
        _shake++;
      });
      if (f.lockedFor != null) _startLock(f.lockedFor!);
      if (f.lockedFor == null) _pw.clear();
    }
  }

  String _mmss(int s) => '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);
    final info = session.siteInfo;
    final t = context.tokens;
    final locked = _lockLeft > 0;
    final school = info?.name ?? 'your school';

    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(Gaps.page, Gaps.xl, Gaps.page, Gaps.xxl),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        SchoolLogo(info: info, size: 44),
                        const SizedBox(width: Gaps.md),
                        Expanded(child: Text(info?.name ?? 'SchoolSync', style: context.text.titleMedium, maxLines: 2, overflow: TextOverflow.ellipsis)),
                      ],
                    ),
                    const SizedBox(height: Gaps.lg),
                    const Center(child: IllustrationView(Illo.signIn, width: 200, decorative: true)),
                    const SizedBox(height: Gaps.md),
                    Text('Sign in to $school', style: context.text.headlineMedium),
                    const SizedBox(height: 6),
                    Text('Use your username, email, phone number, admission number or employee ID.', style: context.text.bodyMedium?.copyWith(color: t.textSecondary)),
                    const SizedBox(height: Gaps.xl),
                    if (session.notice != null) ...[
                      InfoBanner(
                        tone: BannerTone.warning,
                        title: session.notice == SessionNotice.disabled ? 'Account disabled' : 'Please sign in again',
                        message: session.notice == SessionNotice.disabled
                            ? 'Your account was disabled. Contact the school office.'
                            : 'Your session ended, for example because you signed out on another device or it expired.',
                      ),
                      const SizedBox(height: Gaps.md),
                    ],
                    if (info?.readOnly ?? false) ...[
                      const InfoBanner(
                        tone: BannerTone.warning,
                        icon: Icons.event_busy_rounded,
                        title: 'Subscription ended',
                        message: 'This school\'s subscription has expired. You can sign in and view information, but changes are disabled until it is renewed.',
                      ),
                      const SizedBox(height: Gaps.md),
                    ],
                    TextFormField(
                      controller: _id,
                      enabled: !_loading,
                      autofillHints: const [AutofillHints.username],
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      autocorrect: false,
                      enableSuggestions: false,
                      onFieldSubmitted: (_) => _pwFocus.requestFocus(),
                      decoration: const InputDecoration(labelText: 'Username or email'),
                      validator: (v) => (v == null || v.trim().length < 2) ? 'Enter your username, email or phone' : null,
                    ),
                    const SizedBox(height: Gaps.md),
                    TextFormField(
                      controller: _pw,
                      focusNode: _pwFocus,
                      enabled: !_loading,
                      obscureText: _obscure,
                      autofillHints: const [AutofillHints.password],
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _submit(),
                      decoration: InputDecoration(
                        labelText: 'Password',
                        suffixIcon: IconButton(
                          tooltip: _obscure ? 'Show password' : 'Hide password',
                          icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                          onPressed: () => setState(() => _obscure = !_obscure),
                        ),
                      ),
                      validator: (v) => (v == null || v.isEmpty) ? 'Enter your password' : null,
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: _loading ? null : () => context.push(Routes.forgot),
                        style: TextButton.styleFrom(padding: EdgeInsets.zero, alignment: Alignment.centerLeft),
                        child: const Text('Forgot password?'),
                      ),
                    ),
                    AnimatedSize(
                      duration: Motion.base,
                      alignment: Alignment.topCenter,
                      child: _failure == null
                          ? const SizedBox(width: double.infinity)
                          : Padding(
                              padding: const EdgeInsets.only(bottom: Gaps.md),
                              child: InfoBanner(
                                key: ValueKey(_shake),
                                tone: BannerTone.danger,
                                title: _failure!.title,
                                message: locked ? '${_failure!.message} Try again in ${_mmss(_lockLeft)}.' : _failure!.message,
                              ),
                            ),
                    ),
                    PrimaryButton(label: locked ? 'Try again in ${_mmss(_lockLeft)}' : 'Sign in', loading: _loading, onPressed: locked ? null : _submit),
                    const SizedBox(height: Gaps.lg),
                    Center(
                      child: Text.rich(
                        TextSpan(
                          style: context.text.bodySmall,
                          children: [
                            const TextSpan(text: 'Not your school? '),
                            WidgetSpan(
                              alignment: PlaceholderAlignment.baseline,
                              baseline: TextBaseline.alphabetic,
                              child: GestureDetector(
                                onTap: _loading ? null : () => ref.read(sessionProvider.notifier).changeSchool(),
                                child: Text('Find your school', style: context.text.bodySmall?.copyWith(color: t.brand.solid, fontWeight: FontWeight.w600)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
