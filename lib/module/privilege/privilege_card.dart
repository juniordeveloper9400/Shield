import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import 'privilege_card_face.dart';
import 'privilege_screen.dart';
import 'privilege_tier.dart';

/// Home entry point for the privilege programme, sat under the hero banner.
class PrivilegeCard extends StatelessWidget {
  const PrivilegeCard({super.key});

  @override
  Widget build(BuildContext context) {
    final entry = PrivilegeProgramme.tiers.first;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 14),
      child: Material(
        color: AppColors.brandNavy,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: () => Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const PrivilegeScreen())),
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // The card itself rather than an icon of one: the programme
                // is a card, and a member recognises it on the screen it is
                // activated on because it is the same card face.
                SizedBox(
                  width: 104,
                  height: 104 / PrivilegeCardFace.aspectRatio,
                  child: PrivilegeCardFace(tier: entry, compact: true),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Activate your Privilege Programme',
                        style: TextStyle(
                          fontSize: 15.5,
                          height: 1.25,
                          fontWeight: FontWeight.w700,
                          color: AppColors.white,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Load ${entry.amountLabel}, get ${entry.bonusLabel} '
                        'free. Every card adds 10%.',
                        style: TextStyle(
                          fontSize: 12.5,
                          height: 1.35,
                          color: AppColors.white.withValues(alpha: 0.75),
                        ),
                      ),
                      const SizedBox(height: 9),
                      // One pip per card, in each card's own colour, so the
                      // range is previewed before the screen is opened.
                      //
                      // Scaled down rather than wrapped on a narrow screen:
                      // the five read as a range only while they sit on one
                      // line, and the card face beside them takes the width
                      // that used to be spare.
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Row(
                          children: [
                            for (final tier in PrivilegeProgramme.tiers)
                              Container(
                                width: 22,
                                height: 5,
                                margin: const EdgeInsets.only(right: 5),
                                decoration: BoxDecoration(
                                  color: tier.accent,
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.white,
                  size: 22,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
