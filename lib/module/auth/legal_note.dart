import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../account/privacy_policy_screen.dart';
import '../account/terms_and_conditions_screen.dart';

/// "By continuing you agree to the Terms of Use and Privacy Policy." — with
/// both names actually opening their pages, inside the app, instead of being
/// inert text. The same two documents the Account menu opens.
///
/// Its own small [State] purely so the two [TapGestureRecognizer]s that inline
/// taps need get disposed properly rather than leaking.
class TermsAndPrivacyNote extends StatefulWidget {
  const TermsAndPrivacyNote({super.key});

  @override
  State<TermsAndPrivacyNote> createState() => _TermsAndPrivacyNoteState();
}

class _TermsAndPrivacyNoteState extends State<TermsAndPrivacyNote> {
  late final TapGestureRecognizer _terms;
  late final TapGestureRecognizer _privacy;

  @override
  void initState() {
    super.initState();
    _terms = TapGestureRecognizer()
      ..onTap = () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const TermsAndConditionsScreen()),
      );
    _privacy = TapGestureRecognizer()
      ..onTap = () => PrivacyPolicyScreen.open(context);
  }

  @override
  void dispose() {
    _terms.dispose();
    _privacy.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const muted = TextStyle(
      fontSize: 12,
      height: 1.4,
      color: AppColors.textMuted,
    );
    const link = TextStyle(
      fontSize: 12,
      height: 1.4,
      fontWeight: FontWeight.w700,
      color: AppColors.brandBlue,
      decoration: TextDecoration.underline,
    );
    return Text.rich(
      TextSpan(
        style: muted,
        children: [
          const TextSpan(text: 'By continuing you agree to the '),
          TextSpan(text: 'Terms of Use', style: link, recognizer: _terms),
          const TextSpan(text: ' and '),
          TextSpan(text: 'Privacy Policy', style: link, recognizer: _privacy),
          const TextSpan(text: '.'),
        ],
      ),
      textAlign: TextAlign.center,
    );
  }
}
