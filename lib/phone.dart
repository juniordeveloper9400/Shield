import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'theme/app_colors.dart';

/// Opens the platform dialer on a number.
class Dialer {
  const Dialer._();

  /// The launch itself, behind a seam so tests can watch it without a dialer
  /// to open. Reset with [resetForTest] afterwards.
  @visibleForTesting
  static Future<bool> Function(Uri uri) opener = launchUrl;

  @visibleForTesting
  static void resetForTest() => opener = launchUrl;

  /// `tel:` with everything but digits and a leading plus stripped, so a
  /// number written for people — spaces, dashes, brackets — still dials.
  static Uri uriFor(String number) {
    final cleaned = number.replaceAll(RegExp(r'[^0-9+]'), '');
    return Uri(scheme: 'tel', path: cleaned);
  }

  /// Opens the dialer with [number] filled in, ready to place.
  ///
  /// The dialer, not the call: placing one outright needs the CALL_PHONE
  /// permission, and an order line is not worth asking a member for that.
  /// A failure says so rather than doing nothing — on a tablet with no dialer
  /// installed, a silent no-op looks like a broken button.
  static Future<void> call(BuildContext context, String number) async {
    final messenger = ScaffoldMessenger.of(context);
    var opened = false;
    try {
      opened = await opener(uriFor(number));
    } catch (_) {
      opened = false;
    }
    if (opened) {
      return;
    }

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('Could not open the dialer. Call $number to order.'),
          backgroundColor: AppColors.textDark,
        ),
      );
  }
}
