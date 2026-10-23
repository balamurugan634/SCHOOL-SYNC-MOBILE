import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design/design.dart';
import '../../core/network/app_exception.dart';
import '../../core/providers.dart';
import '../security/secure_scope.dart';
import 'auth_messages.dart';
import 'session.dart';

/// Change password. With [forced] (first sign-in / admin reset) it is a full-screen gate
/// the person cannot leave except by signing out.
class ChangePasswordScreen extends ConsumerStatefulWidget {
  const ChangePasswordScreen({super.key, this.forced = false});
  final bool forced;

  @override
  ConsumerState<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends ConsumerState<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  bool _show = false;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _next.addListener(() => setState(() {}));
    _confirm.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref.read(authRepositoryProvider).changePassword(current: _current.text, next: _next.text);
      await ref.read(sessionProvider.notifier).passwordChanged();
      unawaited(HapticFeedback.mediumImpact());
      if (!mounted) return;
      if (!widget.forced) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password changed.')));
      }
    } catch (e) {
      final ex = AppException.from(e);
      if (mounted) {
        setState(() {
          _error = ex.code == 'INVALID_CREDENTIALS' || ex.code == 'UNAUTHORIZED' || ex.status == 401
              ? 'Your current password is not right.'
              : describeLoginFailure(ex).message;
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final policy = PasswordPolicy(_next.text);
    final c = context.colors;
    final form = Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.forced) ...[
            Text('Choose a new password', style: context.text.headlineMedium),
            const SizedBox(height: 6),
            Text('For your security, replace the temporary password you were given before you continue.', style: context.text.bodyMedium?.copyWith(color: c.onSurfaceVariant)),
            const SizedBox(height: Gaps.xl),
          ],
          TextFormField(
            controller: _current,
            obscureText: !_show,
            enabled: !_loading,
            autofillHints: const [AutofillHints.password],
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(labelText: widget.forced ? 'Temporary or current password' : 'Current password'),
            validator: (v) => (v == null || v.isEmpty) ? 'Enter your current password' : null,
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _next,
            obscureText: !_show,
            enabled: !_loading,
            autofillHints: const [AutofillHints.newPassword],
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: 'New password',
              suffixIcon: IconButton(
                tooltip: _show ? 'Hide passwords' : 'Show passwords',
                icon: Icon(_show ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                onPressed: () => setState(() => _show = !_show),
              ),
            ),
            validator: (v) => PasswordPolicy(v ?? '').valid ? null : 'Does not meet the rules below',
          ),
          const SizedBox(height: 12),
          _Rule('At least 10 characters', policy.longEnough),
          _Rule('An uppercase letter (A-Z)', policy.hasUpper),
          _Rule('A lowercase letter (a-z)', policy.hasLower),
          _Rule('A number (0-9)', policy.hasDigit),
          const SizedBox(height: 14),
          TextFormField(
            controller: _confirm,
            obscureText: !_show,
            enabled: !_loading,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _submit(),
            decoration: const InputDecoration(labelText: 'Confirm new password'),
            validator: (v) => v == _next.text ? null : 'The two passwords do not match',
          ),
          if (_error != null) ...[const SizedBox(height: 14), InfoBanner(tone: BannerTone.danger, message: _error!)],
          const SizedBox(height: 22),
          PrimaryButton(label: widget.forced ? 'Save and continue' : 'Change password', loading: _loading, onPressed: _submit),
        ],
      ),
    );

    return SecureScope(
      child: PopScope(
        canPop: !widget.forced,
        child: Scaffold(
          appBar: widget.forced
              ? AppBar(
                  automaticallyImplyLeading: false,
                  actions: [TextButton(onPressed: _loading ? null : () => ref.read(sessionProvider.notifier).logout(), child: const Text('Sign out'))],
                )
              : AppBar(title: const Text('Change password')),
          body: SafeArea(child: SingleChildScrollView(padding: const EdgeInsets.fromLTRB(Gaps.page, 8, Gaps.page, 28), keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag, child: form)),
        ),
      ),
    );
  }
}

class _Rule extends StatelessWidget {
  const _Rule(this.text, this.ok);
  final String text;
  final bool ok;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final color = ok ? t.success : t.textSecondary;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5, horizontal: 4),
      child: Row(
        children: [
          AnimatedSwitcher(
            duration: Motion.fast,
            transitionBuilder: (child, a) => ScaleTransition(scale: a, child: child),
            child: Icon(ok ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded, key: ValueKey(ok), size: 18, color: color),
          ),
          const SizedBox(width: 10),
          Text(text, style: context.text.bodySmall?.copyWith(color: color, fontWeight: ok ? FontWeight.w600 : FontWeight.w400)),
        ],
      ),
    );
  }
}
