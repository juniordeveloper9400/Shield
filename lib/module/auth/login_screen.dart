import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_colors.dart';
import '../../widgets/labelled_field.dart';
import 'auth_service.dart';
import 'auth_widgets.dart';
import 'otp_field.dart';

/// Which half of the flow is on screen.
enum _Step { details, otp }

/// The sign-in gate: name, then mobile number, then a one-time code.
///
/// One screen rather than three routes. The number field is revealed by the
/// name being usable, and the code step replaces the details in place, so the
/// member only ever sees the one thing being asked of them next.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _otp = TextEditingController();

  _Step _step = _Step.details;
  bool _busy = false;
  String? _error;

  Timer? _cooldown;
  int _secondsLeft = 0;

  @override
  void initState() {
    super.initState();
    // The number field appears the moment the name is usable, so both fields
    // have to rebuild this screen as they are typed into.
    _name.addListener(_repaint);
    _phone.addListener(_repaint);
    _otp.addListener(_clearErrorOnEdit);
  }

  @override
  void dispose() {
    _cooldown?.cancel();
    _name
      ..removeListener(_repaint)
      ..dispose();
    _phone
      ..removeListener(_repaint)
      ..dispose();
    _otp
      ..removeListener(_clearErrorOnEdit)
      ..dispose();
    super.dispose();
  }

  void _repaint() {
    if (mounted) {
      setState(() {});
    }
  }

  /// Editing a rejected code takes the boxes out of the error state.
  void _clearErrorOnEdit() {
    if (_error != null && mounted) {
      setState(() => _error = null);
    }
  }

  bool get _nameReady => AuthService.validateName(_name.text) == null;

  bool get _phoneReady => AuthService.validatePhone(_phone.text) == null;

  // ---- Actions ----

  Future<void> _sendOtp() async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });
    // Stands in for the SMS round trip, so the button spends a beat in its
    // pending state instead of jumping straight to the code boxes.
    await Future<void>.delayed(const Duration(milliseconds: 450));
    if (!mounted) {
      return;
    }

    final failure = AuthService.instance.requestOtp(
      name: _name.text,
      phone: _phone.text,
    );
    if (failure != null) {
      setState(() {
        _busy = false;
        _error = 'Could not send the code. Check your details.';
      });
      return;
    }

    _otp.clear();
    setState(() {
      _busy = false;
      _step = _Step.otp;
      _error = null;
    });
    _startCooldown();
    _announceCode();
  }

  void _resend() {
    if (_secondsLeft > 0) {
      return;
    }
    AuthService.instance.requestOtp(name: _name.text, phone: _phone.text);
    _otp.clear();
    setState(() => _error = null);
    _startCooldown();
    _announceCode();
  }

  Future<void> _verify([String? completed]) async {
    final code = completed ?? _otp.text;
    if (code.length < AuthService.otpLength) {
      setState(() => _error = 'Enter the ${AuthService.otpLength}-digit code');
      return;
    }

    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    await Future<void>.delayed(const Duration(milliseconds: 350));
    if (!mounted) {
      return;
    }

    final failure = AuthService.instance.verifyOtp(code);
    if (failure == OtpError.wrongOtp) {
      setState(() {
        _busy = false;
        _error = 'That code is incorrect. Check the SMS and try again.';
      });
      return;
    }
    if (failure != null) {
      // The pending request is gone — start over rather than retry blindly.
      setState(() {
        _busy = false;
        _step = _Step.details;
        _error = 'That code expired. Request a new one.';
      });
      return;
    }

    _cooldown?.cancel();
    setState(() => _busy = false);
    // The sent-code notice is stale the moment the code is accepted, and
    // leaving it up would hold back whatever the next screen has to say.
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    // Signed in. As the launch gate this screen is the whole route and the
    // session change swaps it out; pushed over the app, it pops itself.
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop(true);
    }
  }

  void _backToDetails() {
    AuthService.instance.cancelOtp();
    _cooldown?.cancel();
    _otp.clear();
    setState(() {
      _step = _Step.details;
      _error = null;
      _secondsLeft = 0;
    });
  }

  void _startCooldown() {
    _cooldown?.cancel();
    setState(() => _secondsLeft = AuthService.resendCooldown.inSeconds);
    _cooldown = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() => _secondsLeft--);
      if (_secondsLeft <= 0) {
        timer.cancel();
      }
    });
  }

  /// There is no SMS behind this build, so the code is handed over on screen.
  void _announceCode() {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 3),
          content: Text(
            'OTP sent to +91 ${_phone.text} · demo code ${AuthService.demoOtp}',
          ),
        ),
      );
  }

  // ---- Build ----

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // Back on the code step returns to the details rather than leaving.
      canPop: _step == _Step.details,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _backToDetails();
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.white,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(22, 28, 22, 28),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const AuthBrandMark(),
                    const SizedBox(height: 26),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      child: _step == _Step.details
                          ? _buildDetails()
                          : _buildOtp(),
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

  Widget _buildDetails() {
    return Column(
      key: const ValueKey(_Step.details),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AuthHeading(
          title: 'Sign in to SHIELD',
          subtitle:
              'Start with your name — we will verify your mobile number with '
              'a one-time code.',
        ),
        const SizedBox(height: 20),
        Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LabelledField(
                label: 'Full name',
                hint: 'Enter your name',
                controller: _name,
                icon: Icons.person_outline_rounded,
                textCapitalization: TextCapitalization.words,
                inputFormatters: [LengthLimitingTextInputFormatter(40)],
                validator: AuthService.validateName,
              ),
              // Revealed by the name, not sitting greyed out beside it: one
              // question at a time, and the growth is what signals progress.
              AnimatedSize(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                alignment: Alignment.topCenter,
                child: _nameReady
                    ? Padding(
                        padding: const EdgeInsets.only(top: 14),
                        child: LabelledField(
                          label: 'Mobile number',
                          hint: '10-digit mobile number',
                          controller: _phone,
                          icon: Icons.phone_iphone_rounded,
                          prefixText: '+91  ',
                          keyboardType: TextInputType.phone,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(10),
                          ],
                          validator: AuthService.validatePhone,
                          onSubmitted: _phoneReady ? _sendOtp : null,
                        ),
                      )
                    : const SizedBox(width: double.infinity),
              ),
            ],
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 14),
          AuthErrorNote(message: _error!),
        ],
        const SizedBox(height: 20),
        AuthButton(
          label: 'Get OTP',
          busy: _busy,
          onPressed: _nameReady && _phoneReady ? _sendOtp : null,
        ),
        const SizedBox(height: 16),
        const Text(
          'By continuing you agree to the Terms of Use and Privacy Policy.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            height: 1.4,
            color: AppColors.textMuted,
          ),
        ),
      ],
    );
  }

  Widget _buildOtp() {
    return Column(
      key: const ValueKey(_Step.otp),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AuthHeading(
          title: 'Verify your number',
          subtitle:
              'Enter the ${AuthService.otpLength}-digit code sent to '
              '+91 ${_phone.text}.',
        ),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: _busy ? null : _backToDetails,
            icon: const Icon(Icons.arrow_back_rounded, size: 17),
            label: const Text('Change details'),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.brandBlue,
              minimumSize: Size.zero,
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              textStyle: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        const SizedBox(height: 18),
        OtpField(
          controller: _otp,
          length: AuthService.otpLength,
          hasError: _error != null,
          onCompleted: _verify,
        ),
        if (_error != null) ...[
          const SizedBox(height: 14),
          AuthErrorNote(message: _error!),
        ],
        const SizedBox(height: 14),
        _ResendRow(secondsLeft: _secondsLeft, onResend: _resend),
        const SizedBox(height: 18),
        AuthButton(label: 'Verify & continue', busy: _busy, onPressed: _verify),
        const SizedBox(height: 16),
        const _DemoCodeHint(),
      ],
    );
  }
}

/// Countdown, then a live resend link.
class _ResendRow extends StatelessWidget {
  final int secondsLeft;
  final VoidCallback onResend;

  const _ResendRow({required this.secondsLeft, required this.onResend});

  @override
  Widget build(BuildContext context) {
    if (secondsLeft > 0) {
      final seconds = secondsLeft.toString().padLeft(2, '0');
      return Text(
        'Resend code in 0:$seconds',
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 13.5,
          fontWeight: FontWeight.w600,
          color: AppColors.textMuted,
        ),
      );
    }

    // Wrap, not Row: at a large text scale the prompt and the link stack
    // instead of running off the edge.
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        const Text(
          'Did not get the code?',
          style: TextStyle(fontSize: 13.5, color: AppColors.textBody),
        ),
        TextButton(
          onPressed: onResend,
          style: TextButton.styleFrom(
            minimumSize: Size.zero,
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: const Text(
            'Resend OTP',
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
              color: AppColors.brandBlue,
            ),
          ),
        ),
      ],
    );
  }
}

/// Surfaces the stand-in code while there is no SMS gateway behind the form.
class _DemoCodeHint extends StatelessWidget {
  const _DemoCodeHint();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.offerTint,
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      child: Text(
        'Demo mode · any number works, the code is ${AuthService.demoOtp}',
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
          color: AppColors.brandBlue,
        ),
      ),
    );
  }
}
