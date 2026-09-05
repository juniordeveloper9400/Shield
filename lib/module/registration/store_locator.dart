import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import 'shield_store.dart';

/// How a request for the member's location ended.
enum LocationOutcome {
  /// Got a fix — [StoreLocationResult.position] is set.
  ok,

  /// The member said no this time — asking again may still work.
  denied,

  /// The member picked "don't ask again" — only Settings can turn it back on.
  deniedForever,

  /// Location services are switched off on the device.
  serviceOff,

  /// Timed out or the platform threw.
  failed,
}

/// The result of [StoreLocator.locate]: an outcome and, on success, the
/// branches re-ordered by real distance with the closest one named.
class StoreLocationResult {
  final LocationOutcome outcome;
  final Position? position;

  /// Every branch, nearest first, when [outcome] is [LocationOutcome.ok].
  /// Empty otherwise.
  final List<ShieldStore> ranked;

  /// The single closest branch with coordinates on record, or null.
  final ShieldStore? nearest;

  const StoreLocationResult({
    required this.outcome,
    this.position,
    this.ranked = const [],
    this.nearest,
  });

  bool get ok => outcome == LocationOutcome.ok;

  /// Distance in km from the member to [store], rounded to one decimal, or null.
  double? kmTo(ShieldStore store) {
    final p = position;
    if (p == null) return null;
    return store.distanceKmFrom(p.latitude, p.longitude);
  }
}

/// Asks the device for the member's location and ranks the SHIELD branches by
/// distance from it. Used by the registration form and the privilege-plan
/// activation checkout — both let the member share their location to get the
/// nearest branch pre-selected, and both keep working (pincode ranking) if
/// they decline.
class StoreLocator {
  const StoreLocator._();

  /// Test hook: when set, [locate] returns this instead of touching the
  /// platform. Widget tests can neither grant a permission nor reach a GPS, so
  /// anything that drives the store map sets this in `setUp`.
  @visibleForTesting
  static Future<StoreLocationResult> Function()? debugLocate;

  /// One call: check services, ask permission if needed, get a position, and
  /// rank the branches. Never throws.
  static Future<StoreLocationResult> locate() async {
    final override = debugLocate;
    if (override != null) {
      return override();
    }
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return const StoreLocationResult(outcome: LocationOutcome.serviceOff);
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        return const StoreLocationResult(
          outcome: LocationOutcome.deniedForever,
        );
      }
      if (permission == LocationPermission.denied) {
        return const StoreLocationResult(outcome: LocationOutcome.denied);
      }

      // High accuracy, matching DeviceLocation's address-form request: on
      // Android, medium accuracy can resolve to a coarse WiFi/cell-tower fix
      // that lands hundreds of metres to a couple of kilometres off — enough
      // to visibly wrong-foot the "X km away" figure and the ranking, even
      // though the distance math itself is correct.
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );

      final ranked =
          StoreDirectory.nearestTo(position.latitude, position.longitude);
      return StoreLocationResult(
        outcome: LocationOutcome.ok,
        position: position,
        ranked: ranked,
        nearest: ranked.isNotEmpty && ranked.first.hasLocation
            ? ranked.first
            : null,
      );
    } catch (error) {
      debugPrint('StoreLocator: could not get a fix — $error');
      return const StoreLocationResult(outcome: LocationOutcome.failed);
    }
  }

  /// `2.3 km` / `840 m` — a distance for a store card.
  static String label(double km) {
    if (km < 1) {
      return '${(km * 1000).round()} m';
    }
    return '${km.toStringAsFixed(1)} km';
  }

  /// A one-line reason for the SnackBar when [locate] did not return `ok`.
  /// Mirrors [DeviceLocation.message] but keeps the branch list usable in the
  /// wording, since — unlike the address form — this picker never blocks.
  static String message(LocationOutcome outcome) {
    switch (outcome) {
      case LocationOutcome.ok:
        return '';
      case LocationOutcome.denied:
        return 'Location permission was declined. Allow it to rank branches '
            'by distance — the list below still works.';
      case LocationOutcome.deniedForever:
        return 'Location is blocked for this app. Turn it on in Settings to '
            'rank branches by distance.';
      case LocationOutcome.serviceOff:
        return 'Location is switched off on this device. Turn it on to rank '
            'branches by distance.';
      case LocationOutcome.failed:
        return 'Could not get your location. Check your connection and try '
            'again — the list below still works.';
    }
  }
}
