import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import 'lab_cart_screen.dart';
import 'lab_cart_service.dart';

/// The lab basket's own entry point, counting bookings rather than units.
///
/// A separate widget from `CartBadge` because it reads a separate basket: the
/// two counts must never be shown against each other's icon.
class LabCartBadge extends StatelessWidget {
  const LabCartBadge({super.key});

  static const Color badgeColour = Color(0xFFD93025);

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: LabCartService.instance,
      builder: (context, _) {
        final count = LabCartService.instance.bookingCount;

        return Tooltip(
          message: 'Lab bookings',
          child: Material(
            color: AppColors.white,
            shape: const CircleBorder(
              side: BorderSide(color: AppColors.searchBorder),
            ),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () => Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const LabCartScreen())),
              child: SizedBox(
                width: 42,
                height: 42,
                // Clip.none so the count can sit proud of the circle rather
                // than being cut off by it.
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    const Center(
                      child: Icon(
                        Icons.shopping_cart_outlined,
                        size: 21,
                        color: AppColors.textDark,
                      ),
                    ),
                    if (count > 0)
                      Positioned(
                        top: -2,
                        right: -2,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 1,
                          ),
                          constraints: const BoxConstraints(minWidth: 18),
                          decoration: BoxDecoration(
                            color: badgeColour,
                            shape: BoxShape.rectangle,
                            borderRadius: BorderRadius.circular(9),
                            border: Border.all(
                              color: AppColors.white,
                              width: 2,
                            ),
                          ),
                          child: Text(
                            count > 99 ? '99+' : '$count',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 10.5,
                              height: 1.3,
                              fontWeight: FontWeight.w800,
                              color: AppColors.white,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
