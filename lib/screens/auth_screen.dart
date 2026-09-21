import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/auth_state.dart';
import '../theme/app_theme.dart';
import '../widgets/companion_effects.dart';

/// Sign in, register, or look around first.
///
/// A woman opening a breast-cancer app may not want to hand over an email before she trusts it, so
/// "Look around first" is offered as plainly as the form, and the screen says what is kept where.
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _registering = false;
  bool _hidePassword = true;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    final auth = context.read<AuthState>();
    if (_registering) {
      await auth.register(_name.text, _email.text, _password.text);
    } else {
      await auth.signIn(_email.text, _password.text);
    }
  }

  Future<void> _forgotPassword() async {
    final email = _email.text.trim();
    final auth = context.read<AuthState>();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please type your email address first, then tap this again.')),
      );
      return;
    }
    if (await auth.resetPassword(email) && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('A link to set a new password has been sent to $email.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthState>();
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 8),
                Center(
                  child: GlowRing(
                    size: 76,
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: const BoxDecoration(gradient: AppColors.buttonGradient, shape: BoxShape.circle),
                      child: const Icon(Icons.favorite_rounded, color: Colors.white, size: 30),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                const Text('femora',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontFamily: 'Inter', fontSize: 34, fontWeight: FontWeight.w800, color: AppColors.primaryBerry, letterSpacing: -1)),
                const SizedBox(height: 6),
                Text(
                  _registering ? 'Create your account to keep your health history safe.' : 'Welcome back. Sign in to continue.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontFamily: 'Inter', fontSize: 13.5, color: AppColors.textMuted, height: 1.4),
                ),
                const SizedBox(height: 22),
                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      if (_registering)
                        _field(
                          key: const Key('auth_name'),
                          controller: _name,
                          hint: 'Your first name',
                          icon: Icons.person_outline_rounded,
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Please tell me what to call you.' : null,
                        ),
                      _field(
                        key: const Key('auth_email'),
                        controller: _email,
                        hint: 'Email address',
                        icon: Icons.mail_outline_rounded,
                        keyboardType: TextInputType.emailAddress,
                        validator: (v) =>
                            (v == null || !v.contains('@') || !v.contains('.')) ? 'Please enter a valid email address.' : null,
                      ),
                      _field(
                        key: const Key('auth_password'),
                        controller: _password,
                        hint: 'Password',
                        icon: Icons.lock_outline_rounded,
                        obscure: _hidePassword,
                        suffix: IconButton(
                          icon: Icon(_hidePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                              size: 20, color: AppColors.textLight),
                          onPressed: () => setState(() => _hidePassword = !_hidePassword),
                        ),
                        validator: (v) => (v == null || v.length < 6) ? 'Use at least six characters.' : null,
                      ),
                    ],
                  ),
                ),
                if (!_registering)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      key: const Key('auth_forgot'),
                      onPressed: auth.busy ? null : _forgotPassword,
                      child: const Text('Forgot password?',
                          style: TextStyle(fontFamily: 'Inter', fontSize: 12.5, color: AppColors.primaryBerry)),
                    ),
                  ),
                if (auth.error != null)
                  Container(
                    key: const Key('auth_error'),
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(color: const Color(0xFFFDEEF2), borderRadius: BorderRadius.circular(14)),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline_rounded, size: 18, color: AppColors.accentPink),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(auth.error!,
                              style: const TextStyle(fontFamily: 'Inter', fontSize: 12.5, color: AppColors.textDark)),
                        ),
                      ],
                    ),
                  ),
                _primaryButton(
                  key: const Key('auth_submit'),
                  label: _registering ? 'Create account' : 'Sign in',
                  busy: auth.busy,
                  onTap: _submit,
                ),
                const SizedBox(height: 10),
                TextButton(
                  key: const Key('auth_toggle'),
                  onPressed: auth.busy
                      ? null
                      : () {
                          context.read<AuthState>().clearError();
                          setState(() => _registering = !_registering);
                        },
                  child: Text(
                    _registering ? 'I already have an account' : "I'm new here, create an account",
                    style: const TextStyle(fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primaryBerry),
                  ),
                ),
                const SizedBox(height: 6),
                Row(children: [
                  const Expanded(child: Divider(color: Color(0xFFE8E2EC))),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Text('or', style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: AppColors.textLight)),
                  ),
                  const Expanded(child: Divider(color: Color(0xFFE8E2EC))),
                ]),
                const SizedBox(height: 12),
                _outlineButton(
                  key: const Key('auth_google'),
                  icon: Icons.g_mobiledata_rounded,
                  label: 'Continue with Google',
                  onTap: auth.busy ? null : () => context.read<AuthState>().signInWithGoogle(),
                ),
                const SizedBox(height: 8),
                _outlineButton(
                  key: const Key('auth_phone'),
                  icon: Icons.phone_iphone_rounded,
                  label: 'Continue with phone number',
                  onTap: auth.busy ? null : () => _openPhoneSheet(context),
                ),
                const SizedBox(height: 8),
                _outlineButton(
                  key: const Key('auth_guest'),
                  icon: Icons.visibility_outlined,
                  label: 'Look around first',
                  onTap: auth.busy ? null : () => context.read<AuthState>().continueAsGuest(),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Your results, scans and conversations stay on this phone. Your account only proves it is you.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontFamily: 'Inter', fontSize: 11.5, color: AppColors.textLight, height: 1.4),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _field({
    required Key key,
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    bool obscure = false,
    Widget? suffix,
  }) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextFormField(
          key: key,
          controller: controller,
          obscureText: obscure,
          keyboardType: keyboardType,
          validator: validator,
          style: const TextStyle(fontFamily: 'Inter', fontSize: 14, color: AppColors.textDark),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(fontFamily: 'Inter', fontSize: 14, color: AppColors.textLight),
            prefixIcon: Icon(icon, size: 20, color: AppColors.primaryBerry),
            suffixIcon: suffix,
            filled: true,
            fillColor: AppColors.cardWhite,
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFF0DCE3))),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.primaryBerry, width: 1.4)),
          ),
        ),
      );

  Widget _primaryButton({required Key key, required String label, required bool busy, required VoidCallback onTap}) => GestureDetector(
        key: key,
        onTap: busy ? null : onTap,
        child: Container(
          height: 52,
          decoration: BoxDecoration(
            gradient: busy ? null : AppColors.buttonGradient,
            color: busy ? const Color(0xFFD9C3CC) : null,
            borderRadius: BorderRadius.circular(26),
            boxShadow: AppTheme.softShadow,
          ),
          child: Center(
            child: busy
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                : Text(label,
                    style: const TextStyle(fontFamily: 'Inter', fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
          ),
        ),
      );

  Widget _outlineButton({required Key key, required IconData icon, required String label, required VoidCallback? onTap}) =>
      GestureDetector(
        key: key,
        onTap: onTap,
        child: Container(
          height: 48,
          decoration: BoxDecoration(
            color: AppColors.cardWhite,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFF0DCE3)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 21, color: AppColors.primaryBerry),
              const SizedBox(width: 9),
              Text(label, style: const TextStyle(fontFamily: 'Inter', fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.textDark)),
            ],
          ),
        ),
      );

  void _openPhoneSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.cardWhite,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheet) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(sheet).viewInsets.bottom),
        child: const _PhoneSignIn(),
      ),
    ).then((_) => context.mounted ? context.read<AuthState>().cancelCode() : null);
  }
}

/// Phone sign-in: number first, then the code that arrives by SMS.
class _PhoneSignIn extends StatefulWidget {
  const _PhoneSignIn();

  @override
  State<_PhoneSignIn> createState() => _PhoneSignInState();
}

class _PhoneSignInState extends State<_PhoneSignIn> {
  final _phone = TextEditingController(text: '+92');
  final _code = TextEditingController();

  @override
  void dispose() {
    _phone.dispose();
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthState>();
    final waiting = auth.awaitingCode;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(waiting ? 'Enter the code we sent you' : 'Sign in with your phone number',
                style: const TextStyle(fontFamily: 'Inter', fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textDark)),
            const SizedBox(height: 4),
            Text(
              waiting
                  ? 'Your phone may fill it in by itself. If it does, you are already signed in.'
                  : 'Include the country code, for example +92 300 1234567.',
              style: const TextStyle(fontFamily: 'Inter', fontSize: 12.5, color: AppColors.textMuted, height: 1.4),
            ),
            const SizedBox(height: 14),
            TextField(
              key: waiting ? const Key('auth_sms_code') : const Key('auth_phone_number'),
              controller: waiting ? _code : _phone,
              keyboardType: TextInputType.phone,
              style: const TextStyle(fontFamily: 'Inter', fontSize: 15, color: AppColors.textDark),
              decoration: InputDecoration(
                hintText: waiting ? '6-digit code' : '+92 300 1234567',
                filled: true,
                fillColor: AppColors.background,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              ),
            ),
            if (auth.error != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(auth.error!, style: const TextStyle(fontFamily: 'Inter', fontSize: 12.5, color: AppColors.accentPink)),
              ),
            const SizedBox(height: 14),
            GestureDetector(
              key: const Key('auth_phone_submit'),
              onTap: auth.busy
                  ? null
                  : () async {
                      final state = context.read<AuthState>();
                      final ok = waiting ? await state.confirmCode(_code.text) : await state.sendCode(_phone.text);
                      if (ok && waiting && context.mounted) Navigator.pop(context);
                    },
              child: Container(
                height: 50,
                decoration: BoxDecoration(
                  gradient: auth.busy ? null : AppColors.buttonGradient,
                  color: auth.busy ? const Color(0xFFD9C3CC) : null,
                  borderRadius: BorderRadius.circular(25),
                ),
                child: Center(
                  child: auth.busy
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white))
                      : Text(waiting ? 'Confirm code' : 'Send me a code',
                          style: const TextStyle(fontFamily: 'Inter', fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
