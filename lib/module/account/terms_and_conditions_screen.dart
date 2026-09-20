import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

/// One numbered clause: a heading plus one or more paragraphs. Kept as plain
/// data (not widgets) so the whole document is one readable list below,
/// separate from how each clause is laid out.
class _Clause {
  final String title;
  final List<String> paragraphs;
  final List<String> bullets;

  const _Clause(this.title, this.paragraphs, {this.bullets = const []});
}

/// The date this copy last changed. Bump alongside any edit to [_clauses] —
/// see clause 14 ("Changes to these terms"), which points back at this same
/// value rather than a separate changelog.
const String _lastUpdated = '16 September 2026';

const List<_Clause> _clauses = [
  _Clause(
    '1. Acceptance of these terms',
    [
      'These Terms & Conditions ("Terms") govern the use of the Sahakar 360 '
          'mobile application ("Sahakar 360", "the app", "we", "us") by every '
          'member who signs in ("you"). Creating an account, verifying your '
          'mobile number, or placing an order means you accept these Terms '
          'in full. If you do not agree with any part of them, please do '
          'not use the app.',
    ],
  ),
  _Clause(
    '2. Eligibility and your account',
    [
      'You must be at least 18 years old, or using Sahakar 360 under the '
          'supervision of a parent or guardian, to create an account. Your '
          'account is identified by the mobile number you verify by OTP — '
          'keep that number and any device you stay signed in on secure, '
          'since actions taken from your account are treated as taken by '
          'you.',
      'The name, contact details, address and patient information you add '
          'to your profile must be accurate. You are responsible for '
          'keeping them up to date, particularly delivery addresses and '
          'the patients you order prescriptions or book lab tests and '
          'appointments for.',
    ],
  ),
  _Clause(
    '3. Using the app',
    [
      'We grant you a limited, non-exclusive, non-transferable right to '
          'use Sahakar 360 on your own devices to browse, purchase, and manage '
          'orders for yourself and the patients on your account. You agree '
          'not to:',
    ],
    bullets: [
      'Use the app for any unlawful purpose, or in a way that could '
          'disable, overburden or impair it for other members.',
      'Attempt to access another member’s account, order, prescription, '
          'wallet or personal information.',
      'Upload a prescription, patient detail, or review that is false, '
          'forged or not your own to give.',
      'Reverse-engineer, scrape, or misuse the app or the data it shows '
          'you.',
    ],
  ),
  _Clause(
    '4. Products, pricing and availability',
    [
      'Product listings, prices, images, and stock shown in the app are '
          'provided by the Sahakar 360 store network and may change without '
          'prior notice. We make reasonable efforts to keep prices and '
          'availability accurate, but errors can occur — if an item you '
          'ordered turns out to be mispriced or out of stock, we will '
          'contact you before fulfilling that part of the order.',
      'Images are for reference; actual packaging, strength or pack size '
          'may vary by manufacturer and batch.',
    ],
  ),
  _Clause(
    '5. Prescriptions and medical products',
    [
      'Certain products require a valid prescription. By uploading a '
          'prescription image through the app, you confirm it belongs to '
          'the patient named on the order and is genuine and current. Our '
          'pharmacists review every uploaded prescription before it is '
          'dispensed, and may contact you, adjust quantities, or decline '
          'to fulfil an item that does not match a valid, current '
          'prescription.',
      'Sahakar 360 does not provide medical advice. Information shown for '
          'products, lab packages, or health articles in the app is '
          'general in nature and is not a substitute for consulting a '
          'qualified doctor, pharmacist or dietitian.',
    ],
  ),
  _Clause(
    '6. Orders, delivery and cancellations',
    [
      'Placing an order is an offer to buy, which we accept when the order '
          'is confirmed and moves into processing. Delivery timelines shown '
          'in the app are estimates and can be affected by stock, location, '
          'prescription review, or courier delays outside our control.',
      'You may cancel an order that has not yet been dispatched from the '
          'Orders section of the app. Once an order is out for delivery or '
          'delivered, cancellation is handled as a return in line with our '
          'return and refund practice for that product category.',
    ],
  ),
  _Clause(
    '7. Payments and the Sahakar 360 Wallet',
    [
      'Orders may be paid by the payment methods offered at checkout, '
          'including the Sahakar 360 Wallet balance loaded to your account. '
          'Wallet balance is for use within the app and is not '
          'transferable to another member and not redeemable for cash '
          'except where a specific plan explicitly allows it.',
      'Where a payment or wallet debit fails or is reversed after an order '
          'was marked paid, we may hold, cancel, or ask you to settle that '
          'order again before it is dispatched.',
    ],
  ),
  _Clause(
    '8. Reward points, referrals and Health Pass',
    [
      'Reward points, referral bonuses, and any privilege or Health Pass '
          'plan shown in the app are goodwill benefits we choose to offer '
          'and may change, expire, or be discontinued at our discretion, '
          'with reasonable notice where practical. Points and plan '
          'balances have no cash value outside the redemption options we '
          'provide inside the app.',
      'We may reverse points, referral credit, or plan benefits obtained '
          'through fraud, abuse of the referral system, or a cancelled or '
          'refunded order they were tied to.',
    ],
  ),
  _Clause(
    '9. Agent and Investor programs',
    [
      'A member may be enrolled by Sahakar 360 as an Agent or Investor, which '
          'unlocks a separate portal (in this app and on the Sahakar 360 web '
          'portal) with its own commission, payout, or return terms shared '
          'with you at enrolment. Agent commissions and investor returns '
          'are calculated on verified activity and are subject to review, '
          'and may be withheld or reversed where that activity is found to '
          'be fraudulent or in breach of these Terms.',
      'Only Sahakar 360 administrators enrol or remove a member from these '
          'programs; a member cannot self-enrol as an Agent or Investor '
          'through the app.',
    ],
  ),
  _Clause(
    '10. Reviews and content you submit',
    [
      'Anything you submit through the app — a product review, a support '
          'message, a name on a patient profile — must be truthful and '
          'must not infringe anyone else’s rights or contain unlawful, '
          'defamatory or abusive content. We may remove content that '
          'breaches this and, for repeated or serious breaches, restrict '
          'the account that posted it.',
    ],
  ),
  _Clause(
    '11. Your data and privacy',
    [
      'We collect and use your account, order, health and prescription '
          'information to run Sahakar 360’s services for you, as described in '
          'our Privacy Policy. Prescription images and other health '
          'information are treated as sensitive and are only used to '
          'process the order, appointment, or lab booking they were '
          'submitted for, and for the record-keeping pharmacies and '
          'clinics are required to maintain.',
    ],
  ),
  _Clause(
    '12. Suspension and account deletion',
    [
      'We may suspend or delete an account that breaches these Terms, is '
          'used fraudulently, or is inactive or unverifiable for an '
          'extended period. A deleted account can no longer sign in to the '
          'app; your order, wallet and prescription history is retained '
          'as required for legal, medical-record, and accounting purposes '
          'even after deletion, but is no longer accessible to you through '
          'the app.',
      'You may ask us to close your account at any time from Account → '
          'Delete Account, or by contacting support.',
    ],
  ),
  _Clause(
    '13. Liability',
    [
      'To the fullest extent permitted by law, Sahakar 360 and its store '
          'network are not liable for indirect, incidental or '
          'consequential loss arising from your use of the app, delays '
          'outside our reasonable control, or decisions made on the basis '
          'of general information shown in the app rather than professional '
          'medical advice. Nothing in these Terms limits liability that '
          'cannot lawfully be excluded, including for defective medicines '
          'supplied through the app.',
    ],
  ),
  _Clause(
    '14. Changes to these Terms',
    [
      'We may update these Terms from time to time as Sahakar 360’s services '
          'change. The date at the top of this page always shows when it '
          'was last revised. Continuing to use the app after an update '
          'means you accept the revised Terms; if a change is significant, '
          'we will do our best to flag it in the app as well.',
    ],
  ),
  _Clause(
    '15. Governing law',
    [
      'These Terms are governed by the laws of India, and any dispute '
          'arising from them is subject to the exclusive jurisdiction of '
          'the courts local to Sahakar 360’s registered place of business.',
    ],
  ),
  _Clause(
    '16. Contact us',
    [
      'Questions about these Terms, or about your account, can be sent '
          'through Account → Help & Support from within the app.',
    ],
  ),
];

/// The Terms & Conditions document, reached from Account → Terms &
/// Conditions. Static, read-only content — a numbered legal document laid
/// out the same way every other secondary screen off the account menu is
/// (white app bar with a hairline divider, content on the app's page tint).
class TermsAndConditionsScreen extends StatelessWidget {
  const TermsAndConditionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageTint,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        surfaceTintColor: AppColors.white,
        elevation: 0,
        title: const Text(
          'Terms & Conditions',
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
                  'These Terms & Conditions explain the rules for using the '
                  'Sahakar 360 app. Please read them carefully.',
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
                for (final clause in _clauses) _ClauseView(clause),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ClauseView extends StatelessWidget {
  final _Clause clause;

  const _ClauseView(this.clause);

  @override
  Widget build(BuildContext context) {
    final isLast = clause == _clauses.last;
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            clause.title,
            style: const TextStyle(
              fontSize: 15.5,
              fontWeight: FontWeight.w700,
              color: AppColors.textDark,
            ),
          ),
          for (final paragraph in clause.paragraphs) ...[
            const SizedBox(height: 6),
            Text(
              paragraph,
              style: const TextStyle(
                fontSize: 13.5,
                height: 1.55,
                color: AppColors.textBody,
              ),
            ),
          ],
          if (clause.bullets.isNotEmpty) ...[
            const SizedBox(height: 8),
            for (final bullet in clause.bullets)
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
                    Expanded(
                      child: Text(
                        bullet,
                        style: const TextStyle(
                          fontSize: 13.5,
                          height: 1.55,
                          color: AppColors.textBody,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}
