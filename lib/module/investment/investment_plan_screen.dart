import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

/// The Investment Plan: an exclusive unit-share opportunity in Sahakar
/// Medicals & Surgicals flagship outlets — a headline card, the key figures,
/// why members invest, the plan at a glance, and a closing call to action.
///
/// Opened from the menu drawer, directly under the Dashboard panel.
class InvestmentPlanScreen extends StatelessWidget {
  const InvestmentPlanScreen({super.key});

  static const String _intro =
      'Sahakar Medicals and Surgicals, Kerala’s leading healthcare '
      'organization, offers an exclusive investment opportunity in its '
      'flagship outlets. With a minimum investment of ₹1.5 lakhs per '
      'unit share, investors enjoy 100% assured returns while becoming part '
      'of a trusted healthcare brand — stable financial growth that also '
      'widens access to quality healthcare across Kerala.';

  static const List<_Highlight> _highlights = [
    _Highlight(
      icon: Icons.account_balance_outlined,
      title: 'Assured and Secure Investment',
      body:
          'Investors are guaranteed a 100% return on investment, making this '
          'plan a safe and stable financial opportunity. Sahakar’s strong '
          'brand reputation ensures reliability and consistent performance in '
          'the healthcare market.',
    ),
    _Highlight(
      icon: Icons.medical_services_outlined,
      title: 'Exclusive Healthcare Benefits',
      body:
          'As part of the plan, investors receive free medicines, medical '
          'services, and healthcare support. This added value ensures both '
          'financial and personal health benefits for every participant.',
    ),
    _Highlight(
      icon: Icons.volunteer_activism_outlined,
      title: 'Contributing to Kerala’s Healthcare Growth',
      body:
          'By investing, individuals play a vital role in enhancing '
          'Kerala’s healthcare ecosystem. The initiative supports '
          'Sahakar’s mission to expand quality medical access while '
          'generating meaningful social impact alongside financial returns.',
    ),
  ];

  static const List<_PlanPoint> _planPoints = [
    _PlanPoint(title: 'Minimum Investment', body: '₹1.5 lakhs per unit share.'),
    _PlanPoint(
      title: '100% Assured ROI',
      body:
          'Sahakar Medicals & Surgicals guarantee a 100% return on '
          'investment.',
    ),
    _PlanPoint(
      title: 'Additional Medical Benefits',
      body:
          'Investors receive other medical benefits, services, and health '
          'support.',
    ),
  ];

  void _register(BuildContext context) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text(
            'Thanks for your interest — our team will reach out with '
            'equity details.',
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageTint,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        surfaceTintColor: AppColors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textDark),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: const Text(
          'Investment Plan',
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
        padding: const EdgeInsets.only(bottom: 28),
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: _HeaderCard(intro: _intro),
          ),
          const SizedBox(height: 14),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: _FiguresRow(),
          ),
          const SizedBox(height: 24),
          const _SectionTitle(
            title: 'Why invest',
            caption: 'What every unit share carries with it.',
          ),
          const SizedBox(height: 14),
          for (final h in _highlights)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: _HighlightCard(highlight: h),
            ),
          const SizedBox(height: 12),
          const _SectionTitle(
            title: 'The plan at a glance',
            caption: 'Three things to know before you commit.',
          ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                for (var i = 0; i < _planPoints.length; i++)
                  _PlanRow(index: i + 1, point: _planPoints[i]),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _CtaCard(onTap: () => _register(context)),
          ),
        ],
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  final String intro;

  const _HeaderCard({required this.intro});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.brandBlue, AppColors.brandNavy],
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.brandGreen,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              '100% ASSURED ROI',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.6,
                color: AppColors.textDark,
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'The Investment Plan',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: AppColors.white,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            intro,
            style: const TextStyle(
              fontSize: 13.5,
              height: 1.5,
              color: Color(0xFFDCE7F7),
            ),
          ),
        ],
      ),
    );
  }
}

class _FiguresRow extends StatelessWidget {
  const _FiguresRow();

  @override
  Widget build(BuildContext context) {
    // IntrinsicHeight bounds the row so the three tiles can stretch to a
    // shared height even though the surrounding list is unbounded.
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: const [
          Expanded(
            child: _FigureTile(
              value: '₹1.5L',
              label: 'Per unit share',
              accent: AppColors.brandBlue,
            ),
          ),
          SizedBox(width: 10),
          Expanded(
            child: _FigureTile(
              value: '100%',
              label: 'Assured return',
              accent: AppColors.brandGreenDeep,
            ),
          ),
          SizedBox(width: 10),
          Expanded(
            child: _FigureTile(
              value: 'Free',
              label: 'Medical benefits',
              accent: AppColors.brandBlue,
            ),
          ),
        ],
      ),
    );
  }
}

class _FigureTile extends StatelessWidget {
  final String value;
  final String label;
  final Color accent;

  const _FigureTile({
    required this.value,
    required this.label,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: accent,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            maxLines: 2,
            style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final String caption;

  const _SectionTitle({required this.title, required this.caption});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w700,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            caption,
            style: const TextStyle(fontSize: 13.5, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

class _HighlightCard extends StatelessWidget {
  final _Highlight highlight;

  const _HighlightCard({required this.highlight});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.pageTint,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(highlight.icon, size: 21, color: AppColors.brandBlue),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  highlight.title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  highlight.body,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.45,
                    color: AppColors.textBody,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanRow extends StatelessWidget {
  final int index;
  final _PlanPoint point;

  const _PlanRow({required this.index, required this.point});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AppColors.brandBlue,
              shape: BoxShape.circle,
            ),
            child: Text(
              '$index',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: AppColors.white,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  point.title,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  point.body,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.45,
                    color: AppColors.textBody,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CtaCard extends StatelessWidget {
  final VoidCallback onTap;

  const _CtaCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.greenTint,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.brandGreen),
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Redefining the pharmacy experience',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.brandGreenDark,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'At Sahakar Hyper Pharmacy, best-in-class service through wide '
            'product ranges, the best prices, awareness, healthcare '
            'counselling and professional services makes your pharmacy '
            'experience great.',
            style: TextStyle(
              fontSize: 13,
              height: 1.5,
              color: AppColors.textBody,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onTap,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.brandGreenDeep,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                'Get Equity',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Highlight {
  final IconData icon;
  final String title;
  final String body;

  const _Highlight({
    required this.icon,
    required this.title,
    required this.body,
  });
}

class _PlanPoint {
  final String title;
  final String body;

  const _PlanPoint({required this.title, required this.body});
}
