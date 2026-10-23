import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design/design.dart';
import '../../core/network/app_exception.dart';
import '../../core/providers.dart';
import 'auth_messages.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _id = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;
  bool _sent = false;
  String? _error;

  @override
  void dispose() {
    _id.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref.read(authRepositoryProvider).forgotPassword(_id.text);
      if (mounted) setState(() => _sent = true);
    } catch (e) {
      final ex = AppException.from(e);
      if (mounted) setState(() => _error = describeLoginFailure(ex).message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(Gaps.page, 8, Gaps.page, 24),
          child: AnimatedSwitcher(
            duration: Motion.base,
            child: _sent
                ? Column(
                    key: const ValueKey('sent'),
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 24),
                      const IllustrationView(Illo.success, width: 180, decorative: true),
                      const SizedBox(height: Gaps.lg),
                      Text('Check your email', style: context.text.headlineMedium),
                      const SizedBox(height: 6),
                      Text(
                        'If an account matches that username, email or phone, we have sent a link to reset the password. It can take a few minutes to arrive.',
                        style: context.text.bodyMedium?.copyWith(color: c.onSurfaceVariant),
                      ),
                      const SizedBox(height: Gaps.xl),
                      PrimaryButton(label: 'Back to sign in', onPressed: () => Navigator.of(context).maybePop()),
                    ],
                  )
                : Form(
                    key: _formKey,
                    child: Column(
                      key: const ValueKey('form'),
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Reset your password', style: context.text.headlineMedium),
                        const SizedBox(height: 6),
                        Text(
                          'Enter the username, email or phone you sign in with and we will send a reset link.',
                          style: context.text.bodyMedium?.copyWith(color: c.onSurfaceVariant),
                        ),
                        const SizedBox(height: Gaps.xl),
                        TextFormField(
                          controller: _id,
                          enabled: !_loading,
                          autocorrect: false,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) => _send(),
                          decoration: const InputDecoration(labelText: 'Username, email or phone'),
                          validator: (v) => (v == null || v.trim().length < 2) ? 'Enter your username, email or phone' : null,
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 14),
                          InfoBanner(tone: BannerTone.danger, message: _error!),
                        ],
                        const SizedBox(height: Gaps.xl),
                        PrimaryButton(label: 'Send reset link', loading: _loading, onPressed: _send),
                      ],
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
