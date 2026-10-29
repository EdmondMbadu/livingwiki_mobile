import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../core/app_state.dart';
import '../core/theme.dart';
import '../core/widgets.dart';

Future<bool> requireSignIn(BuildContext context) async {
  if (AppScope.of(context).user != null) return true;
  await Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (_) => const AuthScreen()));
  return context.mounted && AppScope.of(context).user != null;
}

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final form = GlobalKey<FormState>();
  final email = TextEditingController(),
      password = TextEditingController(),
      name = TextEditingController();
  bool create = false,
      reset = false,
      busy = false,
      obscure = true,
      agreed = false;
  String? error, success;
  Future<void> run(Future<void> Function() action, {bool close = true}) async {
    setState(() {
      busy = true;
      error = null;
      success = null;
    });
    try {
      await action();
      if (mounted && close) Navigator.pop(context);
    } catch (e) {
      if (mounted) setState(() => error = friendlyError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> submit() async {
    if (!form.currentState!.validate()) return;
    final state = AppScope.of(context);
    if (create && !agreed) {
      setState(() => error = 'Please accept the terms and privacy policy.');
      return;
    }
    await run(() async {
      if (reset) {
        await state.repository.call('sendAccountPasswordResetEmail', {
          'email': email.text.trim().toLowerCase(),
        });
        if (mounted) {
          setState(
            () =>
                success = 'If this account exists, a reset link is on its way.',
          );
        }
      } else if (create) {
        final result = await state.repository.auth
            .createUserWithEmailAndPassword(
              email: email.text.trim(),
              password: password.text,
            );
        await result.user!.updateDisplayName(name.text.trim());
        await state.repository.syncProfile();
        await state.repository.call('sendAccountVerificationEmail', {
          'redirectTo': '/home',
        });
      } else {
        await state.repository.auth.signInWithEmailAndPassword(
          email: email.text.trim(),
          password: password.text,
        );
      }
    }, close: !reset);
  }

  Future<void> google() => run(() async {
    final auth = AppScope.of(context).repository.auth;
    if (kIsWeb) {
      await auth.signInWithPopup(GoogleAuthProvider());
    } else {
      await GoogleSignIn.instance.initialize(
        serverClientId:
            '661893013313-gt45ll6ghpr5jo2qa00erkt6285ku8dl.apps.googleusercontent.com',
      );
      final account = await GoogleSignIn.instance.authenticate();
      await auth.signInWithCredential(
        GoogleAuthProvider.credential(idToken: account.authentication.idToken),
      );
    }
  });
  @override
  void dispose() {
    email.dispose();
    password.dispose();
    name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(28, 10, 28, 40),
          children: [
            const Icon(Icons.spa_outlined, size: 44, color: Palette.forest),
            const SizedBox(height: 28),
            const Center(child: Eyebrow('A world worth knowing')),
            const SizedBox(height: 16),
            Text(
              reset
                  ? 'Find your way back.'
                  : create
                  ? 'Stay curious.\nMake it yours.'
                  : 'Welcome back,\ncurious soul.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.displayMedium,
            ),
            const SizedBox(height: 14),
            Text(
              reset
                  ? 'We’ll send you a link to reset your password.'
                  : 'Your places, stories, and discoveries.\nAll connected to your LivingWiki account.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Palette.muted),
            ),
            const SizedBox(height: 32),
            if (!reset) ...[
              OutlinedButton.icon(
                onPressed: busy ? null : google,
                icon: const Icon(Icons.g_mobiledata_rounded, size: 28),
                label: const Text('Continue with Google'),
              ),
              if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) ...[
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: busy
                      ? null
                      : () => run(() async {
                          await AppScope.of(context).repository.auth
                              .signInWithProvider(AppleAuthProvider());
                        }),
                  icon: const Icon(Icons.apple),
                  label: const Text('Continue with Apple'),
                ),
              ],
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Row(
                  children: [
                    Expanded(child: Divider()),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'or with email',
                        style: TextStyle(color: Palette.muted, fontSize: 12),
                      ),
                    ),
                    Expanded(child: Divider()),
                  ],
                ),
              ),
            ],
            Form(
              key: form,
              child: Column(
                children: [
                  if (create) ...[
                    TextFormField(
                      controller: name,
                      autofillHints: const [AutofillHints.name],
                      decoration: const InputDecoration(labelText: 'Your name'),
                      validator: (v) => v == null || v.trim().isEmpty
                          ? 'Enter your name.'
                          : null,
                    ),
                    const SizedBox(height: 14),
                  ],
                  TextFormField(
                    controller: email,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    decoration: const InputDecoration(
                      labelText: 'Email address',
                    ),
                    validator: (v) =>
                        v == null ||
                            !RegExp(
                              r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
                            ).hasMatch(v.trim())
                        ? 'Enter a valid email address.'
                        : null,
                  ),
                  if (!reset) ...[
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: password,
                      obscureText: obscure,
                      autofillHints: [
                        create
                            ? AutofillHints.newPassword
                            : AutofillHints.password,
                      ],
                      onFieldSubmitted: (_) => busy ? null : submit(),
                      decoration: InputDecoration(
                        labelText: 'Password',
                        suffixIcon: IconButton(
                          tooltip: obscure ? 'Show password' : 'Hide password',
                          onPressed: () => setState(() => obscure = !obscure),
                          icon: Icon(
                            obscure
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                        ),
                      ),
                      validator: (v) => v == null || v.length < (create ? 8 : 1)
                          ? (create
                                ? 'Use at least 8 characters.'
                                : 'Enter your password.')
                          : null,
                    ),
                  ],
                  if (create)
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: agreed,
                      onChanged: busy
                          ? null
                          : (v) => setState(() => agreed = v!),
                      title: Wrap(
                        children: [
                          const Text(
                            'I agree to the ',
                            style: TextStyle(fontSize: 12),
                          ),
                          InkWell(
                            onTap: () => openUrl(
                              context,
                              'https://livingwiki.com/terms',
                            ),
                            child: const Text(
                              'terms',
                              style: TextStyle(
                                fontSize: 12,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                          const Text(' and ', style: TextStyle(fontSize: 12)),
                          InkWell(
                            onTap: () => openUrl(
                              context,
                              'https://livingwiki.com/privacy',
                            ),
                            child: const Text(
                              'privacy policy.',
                              style: TextStyle(
                                fontSize: 12,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (error != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  if (success != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        success!,
                        style: const TextStyle(color: Palette.forest),
                      ),
                    ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: BusyButton(
                      busy: busy,
                      label: reset
                          ? 'Send reset link'
                          : create
                          ? 'Create account'
                          : 'Sign in',
                      onPressed: submit,
                    ),
                  ),
                ],
              ),
            ),
            if (!create && !reset)
              TextButton(
                onPressed: busy
                    ? null
                    : () => setState(() {
                        reset = true;
                        error = null;
                      }),
                child: const Text('Forgot your password?'),
              ),
            const SizedBox(height: 18),
            TextButton(
              onPressed: busy
                  ? null
                  : () => setState(() {
                      if (reset) {
                        reset = false;
                      } else {
                        create = !create;
                      }
                      error = null;
                      success = null;
                    }),
              child: Text(
                reset
                    ? 'Back to sign in'
                    : create
                    ? 'Already exploring? Sign in'
                    : 'New here? Create an account',
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
