import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

/// One piece of a section: a paragraph, a small sub-heading, or a bullet list.
/// Plain data (not widgets), so the whole policy reads as one document below,
/// separate from how each piece is laid out.
sealed class _Part {
  const _Part();
}

class _Para extends _Part {
  final String text;
  const _Para(this.text);
}

class _Sub extends _Part {
  final String text;
  const _Sub(this.text);
}

class _Bullets extends _Part {
  final List<String> items;
  const _Bullets(this.items);
}

class _Section {
  final String title;
  final List<_Part> parts;
  const _Section(this.title, this.parts);
}

/// The date this copy last changed. Bump alongside any edit to [_sections] —
/// section 8 ("Changes to this policy") points back at this same value.
const String _lastUpdated = '16 September 2026';

/// Where a question about this policy goes.
const String privacyContactEmail = 'zabnixprivatelimited@gmail.com';

const List<_Section> _sections = [
  _Section('1. Information we collect', [
    _Sub('Information you give us:'),
    _Bullets([
      'Your name and mobile number, verified by a one-time code (OTP) sent via Firebase Phone Authentication.',
      'Delivery addresses, and details of any patients you add to your account (name, age, gender, relation, address, phone number).',
      'Prescription images you upload, and any medicine or lab-test orders you place.',
      'Payment-related information: your Sahakar 360 wallet balance and transaction history, and — for a manual bank transfer — the payment reference and receipt you submit. We do not collect or store your card, UPI PIN, or net-banking credentials; those are handled entirely by your bank or payment app.',
      'If you become a Sahakar 360 agent or investor, additional details tied to that role — referral and sales activity, commission and earnings records, or investment and store details.',
    ]),
    _Sub('Information collected automatically:'),
    _Bullets([
      'Your delivery pincode/location, used to show nearby Sahakar 360 branches and delivery estimates.',
      'Basic device and usage information (app version, crash and performance data) used to keep the app working correctly.',
    ]),
  ]),
  _Section('2. How we use your information', [
    _Bullets([
      'To create and manage your account, and verify your identity by phone.',
      'To process and deliver your orders, prescriptions, and lab bookings, and to keep you updated on their status.',
      'To operate your Sahakar 360 wallet and Sahakar HealthPass — including recording top-ups, purchases, and, where you have asked a delivery or counter staff member to collect payment, the one-time code used to confirm that.',
      'To calculate and pay agent commissions or investor returns, where those roles apply to your account.',
      'To respond to support requests, and to send order, delivery, and account-related notifications.',
      'To detect and prevent fraud, and to meet our legal and regulatory obligations.',
    ]),
    _Para('We do not sell your personal information to third parties.'),
  ]),
  _Section('3. Who we share information with', [
    _Bullets([
      'Sahakar 360 branch and pharmacy staff, so they can prepare, price, and dispatch your order or prescription.',
      'Delivery personnel, so your order can be handed to the right person at the right address.',
      'Service providers who help us run the app — for example, Firebase (Google) for phone verification, and our hosting and database providers — bound to use your information only to provide that service.',
      'Law enforcement or regulators, only where required by law.',
    ]),
  ]),
  _Section('4. Data security', [
    _Para(
      'We use industry-standard measures — encrypted connections, access '
      'controls, and secure authentication — to protect your information. '
      'No method of transmission or storage is completely secure, and we '
      'cannot guarantee absolute security, but we work to protect your data '
      'and to improve these measures over time.',
    ),
  ]),
  _Section('5. Data retention', [
    _Para(
      'We retain your information for as long as your account is active, or '
      'as needed to provide you services, comply with our legal '
      'obligations, resolve disputes, and enforce our agreements. If you '
      'delete your account from within the app, your profile, saved '
      'addresses, and patient records are permanently removed; some order '
      'and transaction records may be retained where we are legally '
      'required to keep them.',
    ),
  ]),
  _Section('6. Your choices and rights', [
    _Bullets([
      'You can review and update your profile, addresses, and patient details at any time from the Account section of the app.',
      'You can delete your account at any time from Account → Delete Account.',
      'You can contact us at any time (details below) to ask what information we hold about you, or to request its correction or deletion.',
    ]),
  ]),
  _Section('7. Children’s privacy', [
    _Para(
      'The app is intended for use by adults placing orders on behalf of '
      'themselves or their family members (added as “patients” on their own '
      'account). We do not knowingly collect account information directly '
      'from children.',
    ),
  ]),
  _Section('8. Changes to this policy', [
    _Para(
      'We may update this Privacy Policy from time to time. If we make '
      'material changes, we will update the “Last updated” date above, and '
      'where appropriate, notify you within the app.',
    ),
  ]),
  _Section('9. Contact us', [
    _Para(
      'If you have any questions about this Privacy Policy or how your '
      'information is handled, contact us at:',
    ),
    _Para(privacyContactEmail),
  ]),
];

/// The Privacy Policy, reached from Account → Privacy Policy and from the
/// "Privacy Policy" link on the sign-in screen. Static, read-only content,
/// laid out like the Terms & Conditions beside it (white app bar with a
/// hairline divider, the document on the app's page tint).
///
/// Shown inside the app rather than sent to a browser, so it opens the same
/// with no connection and never depends on a separate website being up.
class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  /// Opens the policy over the current screen.
  static Future<void> open(BuildContext context) {
    return Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageTint,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        surfaceTintColor: AppColors.white,
        elevation: 0,
        title: const Text(
          'Privacy Policy',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.textDark,
          ),
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: AppColors.border),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          Container(
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'This Privacy Policy explains how Sahakar 360 (“we”, “us”, '
                  '“our”) collects, uses, shares, and protects information '
                  'when you use the Sahakar 360 app — including ordering '
                  'medicines and lab tests, uploading prescriptions, using '
                  'the Sahakar 360 wallet and Sahakar HealthPass, and — where '
                  'applicable — the agent and investor sections of the app.',
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: AppColors.textBody,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'By creating an account or otherwise using the app, you '
                  'agree to the collection and use of information as '
                  'described in this policy.',
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: AppColors.textBody,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 6,
                  children: [
                    const Icon(
                      Icons.event_outlined,
                      size: 15,
                      color: AppColors.textMuted,
                    ),
                    Text(
                      'Last updated: $_lastUpdated',
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                for (final section in _sections)
                  _SectionView(
                    section,
                    isLast: identical(section, _sections.last),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionView extends StatelessWidget {
  final _Section section;
  final bool isLast;

  const _SectionView(this.section, {required this.isLast});

  static const TextStyle _body = TextStyle(
    fontSize: 13.5,
    height: 1.55,
    color: AppColors.textBody,
  );

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            section.title,
            style: const TextStyle(
              fontSize: 15.5,
              fontWeight: FontWeight.w700,
              color: AppColors.textDark,
            ),
          ),
          for (final part in section.parts) ...[
            const SizedBox(height: 8),
            switch (part) {
              _Para(:final text) => SelectableText(text, style: _body),
              _Sub(:final text) => Text(
                text,
                style: _body.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark,
                ),
              ),
              _Bullets(:final items) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final item in items)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(top: 6),
                            child: Icon(
                              Icons.circle,
                              size: 5,
                              color: AppColors.textMuted,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(child: Text(item, style: _body)),
                        ],
                      ),
                    ),
                ],
              ),
            },
          ],
        ],
      ),
    );
  }
}
