import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/auth_state.dart';
import '../models/email_check.dart';
import '../theme/app_theme.dart';
import '../widgets/companion_effects.dart';

/// Sign in, register, or look around first.
///
/// Designed to be a pixel-perfect match for the Figma design, with fluid
/// spring physics, breathing ambient glow, and smooth staggered entrance transitions.
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> with TickerProviderStateMixin {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _registering = false;
  bool _hidePassword = true;
  String? _emailIssue; // set by the online check (domain cannot receive mail)
  bool _checkingEmail = false;

  // ── Entrance animations ──
  late final AnimationController _entranceCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  // ── Fluid breathing pulse for the ambient logo glow ──
  late final AnimationController _pulseCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  );
  late final Animation<double> _pulseGlow = Tween<double>(begin: 0.18, end: 0.42).animate(
    CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOutSine),
  );
  late final Animation<double> _pulseScale = Tween<double>(begin: 1.0, end: 1.035).animate(
    CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOutSine),
  );

  // ── Fluid shimmer light sweep across the Sign In button ──
  late final AnimationController _shimmerCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3200),
  );

  // Staggered entrance curves
  late final Animation<double> _logoFade = CurvedAnimation(
    parent: _entranceCtrl,
    curve: const Interval(0.0, 0.45, curve: Curves.easeOut),
  );
  late final Animation<double> _logoScale = Tween<double>(begin: 0.65, end: 1.0).animate(
    CurvedAnimation(parent: _entranceCtrl, curve: const Interval(0.0, 0.5, curve: Curves.easeOutBack)),
  );
  late final Animation<double> _titleFade = CurvedAnimation(
    parent: _entranceCtrl,
    curve: const Interval(0.12, 0.52, curve: Curves.easeOut),
  );
  late final Animation<Offset> _titleSlide = Tween<Offset>(
    begin: const Offset(0, 0.14),
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: _entranceCtrl, curve: const Interval(0.1, 0.5, curve: Curves.easeOutCubic)));
  late final Animation<double> _formFade = CurvedAnimation(
    parent: _entranceCtrl,
    curve: const Interval(0.25, 0.65, curve: Curves.easeOut),
  );
  late final Animation<Offset> _formSlide = Tween<Offset>(
    begin: const Offset(0, 0.1),
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: _entranceCtrl, curve: const Interval(0.2, 0.6, curve: Curves.easeOutCubic)));
  late final Animation<double> _buttonFade = CurvedAnimation(
    parent: _entranceCtrl,
    curve: const Interval(0.4, 0.78, curve: Curves.easeOut),
  );
  late final Animation<Offset> _buttonSlide = Tween<Offset>(
    begin: const Offset(0, 0.08),
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: _entranceCtrl, curve: const Interval(0.35, 0.75, curve: Curves.easeOutCubic)));
  late final Animation<double> _socialFade = CurvedAnimation(
    parent: _entranceCtrl,
    curve: const Interval(0.5, 0.92, curve: Curves.easeOut),
  );
  late final Animation<Offset> _socialSlide = Tween<Offset>(
    begin: const Offset(0, 0.06),
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: _entranceCtrl, curve: const Interval(0.45, 0.85, curve: Curves.easeOutCubic)));
  late final Animation<double> _privacyFade = CurvedAnimation(
    parent: _entranceCtrl,
    curve: const Interval(0.68, 1.0, curve: Curves.easeOut),
  );

  @override
  void initState() {
    super.initState();
    _entranceCtrl.forward();
    if (companionAnimations) {
      _pulseCtrl.repeat(reverse: true);
      _shimmerCtrl.repeat();
    }
  }

  @override
  void dispose() {
    _entranceCtrl.dispose();
    _pulseCtrl.dispose();
    _shimmerCtrl.dispose();
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_checkingEmail) return;
    _emailIssue = null;
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    final auth = context.read<AuthState>();
    if (_registering) {
      // Before making an account, make sure the address can actually receive email.
      setState(() => _checkingEmail = true);
      final issue = await EmailCheck.problem(_email.text);
      if (!mounted) return;
      setState(() {
        _checkingEmail = false;
        _emailIssue = issue;
      });
      if (issue != null) {
        _formKey.currentState!.validate();
        return;
      }
      await auth.register(_name.text.trim(), _email.text.trim(), _password.text);
      // The account waits for its confirmation link: switch to sign-in with the address filled in.
      if (mounted && auth.notice != null) setState(() => _registering = false);
    } else {
      await auth.signIn(_email.text.trim(), _password.text);
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
      backgroundColor: Colors.white,
      body: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          // Subtle warm pink glow concentrated at the top behind logo, pure white in form area, faint warmth at base
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFFDE8EC), // soft blush top wash
              Color(0xFFFFF0F4),
              Color(0xFFFFFAFC),
              Colors.white,
              Color(0xFFFFF9FB),
            ],
            stops: [0.0, 0.14, 0.28, 0.65, 1.0],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
              child: AnimatedBuilder(
                animation: Listenable.merge([_entranceCtrl, _pulseCtrl, _shimmerCtrl]),
                builder: (context, _) => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 12),

                    // ── Logo Emblem with Fluid Feather-Soft Breathing Aura ──
                    FadeTransition(
                      opacity: _logoFade,
                      child: ScaleTransition(
                        scale: _logoScale,
                        child: Center(
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // Feather-soft continuous radial glow (zero hard edges)
                              Container(
                                width: 130,
                                height: 130,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: RadialGradient(
                                    colors: [
                                      const Color(0xFFE11D48).withOpacity(_pulseGlow.value),
                                      const Color(0xFFE11D48).withOpacity(_pulseGlow.value * 0.4),
                                      Colors.transparent,
                                    ],
                                    stops: const [0.0, 0.5, 1.0],
                                  ),
                                ),
                              ),
                              // Solid circular badge with diagonal gradient & inner shadow
                              Transform.scale(
                                scale: _pulseScale.value,
                                child: Container(
                                  width: 58,
                                  height: 58,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: const LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Color(0xFFD2285C), // cherry rose top
                                        Color(0xFFAE1855), // deep plum rose bottom
                                      ],
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFFD2285C).withOpacity(0.35),
                                        blurRadius: 14,
                                        offset: const Offset(0, 5),
                                      ),
                                    ],
                                  ),
                                  child: const Center(
                                    child: Icon(
                                      Icons.favorite_rounded,
                                      color: Colors.white,
                                      size: 26,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),

                    // ── "femora" Brand Title ──
                    SlideTransition(
                      position: _titleSlide,
                      child: FadeTransition(
                        opacity: _titleFade,
                        child: const Text(
                          'femora',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 30,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF9D174D), // exact from Figma
                            letterSpacing: -0.9,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),

                    // ── Subtitle (warm stone-500) ──
                    SlideTransition(
                      position: _titleSlide,
                      child: FadeTransition(
                        opacity: _titleFade,
                        child: Text(
                          _registering
                              ? 'Create your account to keep your health history safe.'
                              : 'Welcome back. Sign in to continue.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 13.5,
                            fontWeight: FontWeight.w400,
                            color: Color(0xFF6E6864), // warm stone-500
                            height: 1.35,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 26),

                    // ── Input Fields Form ──
                    SlideTransition(
                      position: _formSlide,
                      child: FadeTransition(
                        opacity: _formFade,
                        child: Form(
                          key: _formKey,
                          child: Column(
                            children: [
                              if (_registering)
                                _field(
                                  key: const Key('auth_name'),
                                  controller: _name,
                                  hint: 'Your first name',
                                  icon: Icons.person_outline_rounded,
                                  validator: EmailCheck.nameProblem,
                                  formatters: [
                                    FilteringTextInputFormatter.allow(EmailCheck.nameCharacters),
                                    FilteringTextInputFormatter.deny(RegExp(r'^ | (?= )')), // no leading or double spaces
                                    LengthLimitingTextInputFormatter(30),
                                  ],
                                  keyboardType: TextInputType.name,
                                ),
                              _field(
                                key: const Key('auth_email'),
                                controller: _email,
                                hint: 'Email address',
                                icon: Icons.mail_outline_rounded,
                                keyboardType: TextInputType.emailAddress,
                                validator: (v) => EmailCheck.formatProblem(v) ?? _emailIssue,
                              ),
                              _field(
                                key: const Key('auth_password'),
                                controller: _password,
                                hint: 'Password',
                                icon: Icons.lock_outline_rounded,
                                obscure: _hidePassword,
                                suffix: IconButton(
                                  icon: Icon(
                                    _hidePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                    size: 20,
                                    color: const Color(0xFFA8A29E),
                                  ),
                                  onPressed: () => setState(() => _hidePassword = !_hidePassword),
                                ),
                                validator: (v) =>
                                    (v == null || v.length < 6) ? 'Use at least six characters.' : null,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // ── "Forgot password?" ──
                    if (!_registering)
                      SlideTransition(
                        position: _formSlide,
                        child: FadeTransition(
                          opacity: _formFade,
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: Padding(
                              padding: const EdgeInsets.only(top: 2, bottom: 6),
                              child: TextButton(
                                key: const Key('auth_forgot'),
                                onPressed: auth.busy ? null : _forgotPassword,
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: const Text(
                                  'Forgot password?',
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFFBE185D),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),

                    // ── Notice (e.g. confirm your email) ──
                    if (auth.notice != null)
                      Container(
                        key: const Key('auth_notice'),
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8F5EE),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.mark_email_read_outlined, size: 18, color: Color(0xFF15803D)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                auth.notice!,
                                style: const TextStyle(fontFamily: 'Inter', fontSize: 12.5, color: AppColors.textDark),
                              ),
                            ),
                          ],
                        ),
                      ),

                    // ── Error Message ──
                    if (auth.error != null)
                      Container(
                        key: const Key('auth_error'),
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFDEEF2),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline_rounded, size: 18, color: Color(0xFFE11D48)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                auth.error!,
                                style: const TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 12.5,
                                  color: AppColors.textDark,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 8),

                    // ── Primary Gradient CTA Button ──
                    SlideTransition(
                      position: _buttonSlide,
                      child: FadeTransition(
                        opacity: _buttonFade,
                        child: _primaryButton(
                          key: const Key('auth_submit'),
                          label: _registering ? 'Create account' : 'Sign In',
                          busy: auth.busy || _checkingEmail,
                          onTap: _submit,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ── Toggle Sign In / Register ──
                    SlideTransition(
                      position: _buttonSlide,
                      child: FadeTransition(
                        opacity: _buttonFade,
                        child: Center(
                          child: TextButton(
                            key: const Key('auth_toggle'),
                            onPressed: auth.busy
                                ? null
                                : () {
                                    context.read<AuthState>().clearError();
                                    setState(() => _registering = !_registering);
                                  },
                            child: Text(
                              _registering ? 'I already have an account' : "I'm new here, create an account",
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF9D174D),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),

                    // ── "or" Divider ──
                    SlideTransition(
                      position: _socialSlide,
                      child: FadeTransition(
                        opacity: _socialFade,
                        child: Row(children: const [
                          Expanded(child: Divider(color: Color(0xFFF3E8EC), thickness: 1.0)),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              'or',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 12,
                                color: Color(0xFFA8A29E),
                              ),
                            ),
                          ),
                          Expanded(child: Divider(color: Color(0xFFF3E8EC), thickness: 1.0)),
                        ]),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // ── Continue with Google ──
                    SlideTransition(
                      position: _socialSlide,
                      child: FadeTransition(
                        opacity: _socialFade,
                        child: _outlineButton(
                          key: const Key('auth_google'),
                          customIcon: const _GoogleLogo(size: 20),
                          label: 'Continue with Google',
                          onTap: auth.busy ? null : () => context.read<AuthState>().signInWithGoogle(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // ── Continue with Email Code ──
                    SlideTransition(
                      position: _socialSlide,
                      child: FadeTransition(
                        opacity: _socialFade,
                        child: _outlineButton(
                          key: const Key('auth_email_code'),
                          icon: Icons.mark_email_read_rounded,
                          iconColor: const Color(0xFFD35E81),
                          label: 'Continue with email code',
                          onTap: auth.busy ? null : () => _openEmailCodeSheet(context),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // ── Look Around First ──
                    SlideTransition(
                      position: _socialSlide,
                      child: FadeTransition(
                        opacity: _socialFade,
                        child: _outlineButton(
                          key: const Key('auth_guest'),
                          icon: Icons.visibility_outlined,
                          iconColor: const Color(0xFFD35E81),
                          label: 'Look around first',
                          onTap: auth.busy ? null : () => context.read<AuthState>().continueAsGuest(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 64),

                    // ── Privacy Shield & Reassurance Footer ──
                    FadeTransition(
                      opacity: _privacyFade,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(top: 1),
                            child: Icon(
                              Icons.shield_outlined,
                              size: 16,
                              color: Color(0xFFE08EA6),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Your results, scans and conversations stay on this phone. Your account only proves it is you.',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 11.5,
                                color: Color(0xFFA8A29E),
                                height: 1.45,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Input field matching design exactly (height 52, radius 26, border #FDDDE1) ──
  Widget _field({
    required Key key,
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    bool obscure = false,
    Widget? suffix,
    List<TextInputFormatter>? formatters,
  }) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: TextFormField(
          key: key,
          controller: controller,
          obscureText: obscure,
          keyboardType: keyboardType,
          inputFormatters: formatters,
          validator: validator,
          style: const TextStyle(fontFamily: 'Inter', fontSize: 14, color: AppColors.textDark),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(fontFamily: 'Inter', fontSize: 14, color: Color(0xFFA8A29E)),
            prefixIcon: Padding(
              padding: const EdgeInsets.only(left: 18, right: 12),
              child: Icon(icon, size: 20, color: const Color(0xFFD35E81)),
            ),
            prefixIconConstraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            suffixIcon: suffix,
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(vertical: 15, horizontal: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(26),
              borderSide: const BorderSide(color: Color(0xFFFED7DC), width: 1.0),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(26),
              borderSide: const BorderSide(color: Color(0xFFFED7DC), width: 1.0),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(26),
              borderSide: const BorderSide(color: Color(0xFFBE185D), width: 1.4),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(26),
              borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.0),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(26),
              borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.4),
            ),
          ),
        ),
      );

  // ── Primary gradient CTA with fluid press interaction & subtle light shimmer ──
  Widget _primaryButton({
    required Key key,
    required String label,
    required bool busy,
    required VoidCallback onTap,
  }) {
    final shimmerProgress = _shimmerCtrl.value;
    return _FluidPress(
      widgetKey: key,
      onTap: busy ? null : onTap,
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          gradient: busy
              ? null
              : LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    const Color(0xFFC0195C), // left ruby berry (exact from Figma)
                    Color.lerp(const Color(0xFFDE1E49), const Color(0xFFF43F5E), (math.sin(shimmerProgress * math.pi * 2) * 0.5 + 0.5) * 0.2)!, // center vibrant rose
                    const Color(0xFFC62755), // right ruby rose (exact from Figma)
                  ],
                  stops: const [0.0, 0.52, 1.0],
                ),
          color: busy ? const Color(0xFFD9C3CC) : null,
          borderRadius: BorderRadius.circular(25),
          boxShadow: busy
              ? null
              : [
                  BoxShadow(
                    color: const Color(0xFFDE1E49).withOpacity(0.36),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
        ),
        child: Center(
          child: busy
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                )
              : Text(
                  label,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
        ),
      ),
    );
  }

  // ── Outline / social button with fluid press interaction ──
  Widget _outlineButton({
    required Key key,
    IconData? icon,
    Widget? customIcon,
    Color? iconColor,
    required String label,
    required VoidCallback? onTap,
  }) =>
      _FluidPress(
        widgetKey: key,
        onTap: onTap,
        child: Container(
          height: 50,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(25),
            border: Border.all(color: const Color(0xFFF3E4E8), width: 1.0),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (customIcon != null)
                customIcon
              else if (icon != null)
                Icon(icon, size: 20, color: iconColor ?? const Color(0xFFD35E81)),
              const SizedBox(width: 9),
              Text(
                label,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF373330),
                ),
              ),
            ],
          ),
        ),
      );

  void _openEmailCodeSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheet) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(sheet).viewInsets.bottom),
        child: const _EmailCodeSignIn(),
      ),
    ).then((_) => context.mounted ? context.read<AuthState>().cancelCode() : null);
  }
}

/// Fluid spring touch interaction widget for buttons
class _FluidPress extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final Key? widgetKey;

  const _FluidPress({super.key, required this.child, this.onTap, this.widgetKey});

  @override
  State<_FluidPress> createState() => _FluidPressState();
}

class _FluidPressState extends State<_FluidPress> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 100),
    reverseDuration: const Duration(milliseconds: 220),
    lowerBound: 0.97,
    upperBound: 1.0,
  )..value = 1.0;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: widget.widgetKey,
      behavior: HitTestBehavior.opaque,
      onTapDown: widget.onTap != null ? (_) => _ctrl.animateTo(0.97, curve: Curves.easeOutCubic) : null,
      onTapUp: widget.onTap != null ? (_) => _ctrl.animateTo(1.0, curve: Curves.easeOutBack) : null,
      onTapCancel: widget.onTap != null ? () => _ctrl.animateTo(1.0, curve: Curves.easeOut) : null,
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, child) => Transform.scale(
          scale: _ctrl.value,
          child: child,
        ),
        child: widget.child,
      ),
    );
  }
}

/// Email-code sign-in: address first, then the 6-digit code that arrives by email.
class _EmailCodeSignIn extends StatefulWidget {
  const _EmailCodeSignIn();

  @override
  State<_EmailCodeSignIn> createState() => _EmailCodeSignInState();
}

class _EmailCodeSignInState extends State<_EmailCodeSignIn> {
  final _email = TextEditingController();
  final _code = TextEditingController();
  String? _issue; // what is wrong with the typed address, shown under the field

  @override
  void dispose() {
    _email.dispose();
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
            Text(waiting ? 'Enter the code we emailed you' : 'Sign in with a code by email',
                style: const TextStyle(fontFamily: 'Inter', fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textDark)),
            const SizedBox(height: 4),
            Text(
              waiting
                  ? 'It can take a minute to arrive. Check your spam folder if you do not see it.'
                  : 'We will email you a 6-digit code. No password needed.',
              style: const TextStyle(fontFamily: 'Inter', fontSize: 12.5, color: AppColors.textMuted, height: 1.4),
            ),
            const SizedBox(height: 14),
            TextField(
              key: waiting ? const Key('auth_email_code_input') : const Key('auth_email_code_address'),
              controller: waiting ? _code : _email,
              keyboardType: waiting ? TextInputType.number : TextInputType.emailAddress,
              style: const TextStyle(fontFamily: 'Inter', fontSize: 15, color: AppColors.textDark),
              decoration: InputDecoration(
                hintText: waiting ? '6-digit code' : 'you@example.com',
                filled: true,
                fillColor: AppColors.background,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              ),
            ),
            if (!waiting && _issue != null)
              Padding(
                key: const Key('auth_email_code_issue'),
                padding: const EdgeInsets.only(top: 10),
                child: Text(_issue!, style: const TextStyle(fontFamily: 'Inter', fontSize: 12.5, color: AppColors.accentPink)),
              ),
            if (auth.error != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(auth.error!, style: const TextStyle(fontFamily: 'Inter', fontSize: 12.5, color: AppColors.accentPink)),
              ),
            const SizedBox(height: 14),
            GestureDetector(
              key: const Key('auth_email_code_submit'),
              onTap: auth.busy
                  ? null
                  : () async {
                      final state = context.read<AuthState>();
                      if (!waiting) {
                        final issue = await EmailCheck.problem(_email.text);
                        if (!mounted) return;
                        setState(() => _issue = issue);
                        if (issue != null) return;
                      }
                      final ok = waiting ? await state.confirmCode(_code.text.trim()) : await state.sendCode(_email.text.trim());
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

/// Official multi-color Google 'G' icon drawn accurately with Canvas.
class _GoogleLogo extends StatelessWidget {
  const _GoogleLogo({this.size = 18});
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        size: Size(size, size),
        painter: const _GoogleLogoPainter(),
      ),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  const _GoogleLogoPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final double scale = size.width / 24.0;
    canvas.save();
    canvas.scale(scale, scale);

    // Blue #4285F4
    final bluePaint = Paint()
      ..color = const Color(0xFF4285F4)
      ..style = PaintingStyle.fill;
    final bluePath = Path()
      ..moveTo(23.745, 12.27)
      ..cubicTo(23.745, 11.48, 23.68, 10.73, 23.55, 10.01)
      ..lineTo(12, 10.01)
      ..lineTo(12, 14.54)
      ..lineTo(18.59, 14.54)
      ..cubicTo(18.3, 16.05, 17.45, 17.33, 16.2, 18.17)
      ..lineTo(20.08, 21.18)
      ..cubicTo(22.35, 19.09, 23.745, 16.01, 23.745, 12.27)
      ..close();
    canvas.drawPath(bluePath, bluePaint);

    // Green #34A853
    final greenPaint = Paint()
      ..color = const Color(0xFF34A853)
      ..style = PaintingStyle.fill;
    final greenPath = Path()
      ..moveTo(12, 24)
      ..cubicTo(15.24, 24, 17.96, 22.93, 19.93, 21.11)
      ..lineTo(16.05, 18.1)
      ..cubicTo(14.97, 18.82, 13.6, 19.25, 12, 19.25)
      ..cubicTo(8.88, 19.25, 6.23, 17.15, 5.28, 14.32)
      ..lineTo(1.27, 17.42)
      ..cubicTo(3.28, 21.41, 7.35, 24, 12, 24)
      ..close();
    canvas.drawPath(greenPath, greenPaint);

    // Yellow #FBBC05
    final yellowPaint = Paint()
      ..color = const Color(0xFFFBBC05)
      ..style = PaintingStyle.fill;
    final yellowPath = Path()
      ..moveTo(5.28, 14.32)
      ..cubicTo(5.03, 13.57, 4.9, 12.8, 4.9, 12)
      ..cubicTo(4.9, 11.2, 5.03, 10.43, 5.28, 9.68)
      ..lineTo(1.27, 6.58)
      ..cubicTo(0.46, 8.19, 0, 10.04, 0, 12)
      ..cubicTo(0, 13.96, 0.46, 15.81, 1.27, 17.42)
      ..lineTo(5.28, 14.32)
      ..close();
    canvas.drawPath(yellowPath, yellowPaint);

    // Red #EA4335
    final redPaint = Paint()
      ..color = const Color(0xFFEA4335)
      ..style = PaintingStyle.fill;
    final redPath = Path()
      ..moveTo(12, 4.75)
      ..cubicTo(13.76, 4.75, 15.34, 5.35, 16.58, 6.54)
      ..lineTo(20.02, 3.1)
      ..cubicTo(17.95, 1.18, 15.24, 0, 12, 0)
      ..cubicTo(7.35, 0, 3.28, 2.59, 1.27, 6.58)
      ..lineTo(5.28, 9.68)
      ..cubicTo(6.23, 6.85, 8.88, 4.75, 12, 4.75)
      ..close();
    canvas.drawPath(redPath, redPaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
