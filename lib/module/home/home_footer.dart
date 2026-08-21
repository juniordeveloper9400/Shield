import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

/// Closing block of the home feed: a way to reach a human, the standard
/// site links, and the legal line.
///
/// The links and the contact actions have no destinations yet — there is no
/// content site and no support backend in the project — so each one says so
/// rather than silently doing nothing when tapped.
class HomeFooter extends StatelessWidget {
  const HomeFooter({super.key});

  static const List<String> links = [
    'About us',
    'Contact us',
    'Terms of use',
    'Privacy policy',
    'Returns & refunds',
    'FAQs',
  ];

  static void _notReadyYet(BuildContext context, String label) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('$label is coming soon')));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppColors.brandNavy,
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Image.asset(
                'assets/logos/shield_logo.png',
                height: 30,
                fit: BoxFit.contain,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'SHIELD',
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4,
                    color: AppColors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Genuine medicine, delivered for less.',
            style: TextStyle(
              fontSize: 13.5,
              height: 1.4,
              color: AppColors.white.withValues(alpha: 0.72),
            ),
          ),
          const SizedBox(height: 18),
          const _Heading('Need a hand?'),
          const SizedBox(height: 10),
          _ContactRow(
            icon: Icons.support_agent_rounded,
            label: 'Talk to a pharmacist',
            detail: 'Every day, 8am to 10pm',
            onTap: () => _notReadyYet(context, 'Pharmacist support'),
          ),
          const SizedBox(height: 10),
          _ContactRow(
            icon: Icons.chat_bubble_outline_rounded,
            label: 'Chat with us',
            detail: 'Usually replies within a few minutes',
            onTap: () => _notReadyYet(context, 'Chat'),
          ),
          const SizedBox(height: 10),
          _ContactRow(
            icon: Icons.mail_outline_rounded,
            label: 'Email us',
            detail: 'For orders, refunds and account questions',
            onTap: () => _notReadyYet(context, 'Email support'),
          ),
          const SizedBox(height: 20),
          const _Heading('SHIELD'),
          const SizedBox(height: 10),
          // Wrap, not Row: six links never fit one line, and the count is
          // likely to grow.
          Wrap(
            spacing: 18,
            runSpacing: 12,
            children: [
              for (final link in links)
                _FooterLink(
                  label: link,
                  onTap: () => _notReadyYet(context, link),
                ),
            ],
          ),
          // The social links live in the sign-off directly above this footer,
          // as brand discs. Repeating them here as labelled chips would put
          // the same three destinations on screen twice.
          const SizedBox(height: 20),
          Divider(color: AppColors.white.withValues(alpha: 0.16), height: 1),
          const SizedBox(height: 14),
          Text(
            '© 2026 SHIELD. Prescription medicines are dispensed only against '
            'a valid prescription.',
            style: TextStyle(
              fontSize: 11.5,
              height: 1.45,
              color: AppColors.white.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  final String text;

  const _Heading(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: AppColors.white,
      ),
    );
  }
}

class _ContactRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String detail;
  final VoidCallback onTap;

  const _ContactRow({
    required this.icon,
    required this.label,
    required this.detail,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 19, color: AppColors.brandGreen),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.white,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    detail,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.white.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: AppColors.white.withValues(alpha: 0.5),
            ),
          ],
        ),
      ),
    );
  }
}

class _FooterLink extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _FooterLink({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          color: AppColors.white.withValues(alpha: 0.82),
        ),
      ),
    );
  }
}
