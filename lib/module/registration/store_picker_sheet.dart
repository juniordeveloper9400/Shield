import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../theme/app_colors.dart';
import 'shield_store.dart';
import 'store_locator.dart';

/// A bottom sheet for picking a SHIELD branch, with a "Use my location" action
/// that re-orders the list by real distance and tags each branch with how far
/// it is.
///
/// Identical on the APK and the web build: [StoreLocator.locate] takes its fix
/// from the OS on mobile and from the browser's geolocation prompt on web, and
/// the list underneath stays usable if location is never granted.
class StorePickerSheet extends StatefulWidget {
  /// The branch currently in effect, marked as selected when the sheet opens.
  final String selectedId;

  const StorePickerSheet({super.key, required this.selectedId});

  /// Opens the sheet and resolves to the branch the member picked, or null when
  /// they dismissed it without choosing.
  static Future<ShieldStore?> show(
    BuildContext context, {
    required String selectedId,
  }) {
    return showModalBottomSheet<ShieldStore>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) => StorePickerSheet(selectedId: selectedId),
    );
  }

  @override
  State<StorePickerSheet> createState() => _StorePickerSheetState();
}

class _StorePickerSheetState extends State<StorePickerSheet> {
  StoreLocationResult? _location;
  bool _locating = false;

  /// The list to show: distance-ranked once the member has shared their
  /// location, otherwise directory order — which follows the database copy
  /// [StoreCatalog] loads.
  List<ShieldStore> get _stores {
    final ranked = _location?.ranked;
    return (ranked != null && ranked.isNotEmpty) ? ranked : StoreDirectory.all;
  }

  @override
  void initState() {
    super.initState();
    StoreCatalog.instance.addListener(_onCatalogChanged);
    StoreCatalog.instance.ensureLoaded();
  }

  @override
  void dispose() {
    StoreCatalog.instance.removeListener(_onCatalogChanged);
    super.dispose();
  }

  void _onCatalogChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _useMyLocation() async {
    if (_locating) {
      return;
    }
    setState(() => _locating = true);
    final result = await StoreLocator.locate();
    if (!mounted) {
      return;
    }
    setState(() {
      _locating = false;
      if (result.ok) {
        _location = result;
      }
    });
    if (!result.ok) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(StoreLocator.message(result.outcome)),
            action: switch (result.outcome) {
              LocationOutcome.deniedForever => SnackBarAction(
                  label: 'Settings',
                  onPressed: Geolocator.openAppSettings,
                ),
              LocationOutcome.serviceOff => SnackBarAction(
                  label: 'Settings',
                  onPressed: Geolocator.openLocationSettings,
                ),
              _ => null,
            },
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.of(context).size.height * 0.82;

    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(18, 14, 18, 2),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Choose your store',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textDark,
                  ),
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(18, 0, 18, 10),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'The branch that packs and dispatches this order.',
                  style: TextStyle(fontSize: 12.5, color: AppColors.textMuted),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _locating ? null : _useMyLocation,
                  icon: _locating
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.brandBlue,
                          ),
                        )
                      : const Icon(Icons.my_location_rounded, size: 18),
                  label: Text(
                    _locating
                        ? 'Finding the nearest branch…'
                        : _location != null
                            ? 'Sorted by distance from you'
                            : 'Use my location',
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.brandBlue,
                    side: const BorderSide(
                      color: AppColors.brandBlue,
                      width: 1.3,
                    ),
                    minimumSize: const Size.fromHeight(44),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(9),
                    ),
                  ),
                ),
              ),
            ),
            const Divider(height: 1, color: AppColors.border),
            Flexible(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 14),
                itemCount: _stores.length,
                itemBuilder: (context, index) {
                  final store = _stores[index];
                  final km = _location?.kmTo(store);
                  return _StoreOption(
                    store: store,
                    selected: store.id == widget.selectedId,
                    distanceLabel: km == null ? null : StoreLocator.label(km),
                    onTap: () => Navigator.of(context).pop(store),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One branch row in the picker — name, address, an optional "x km" once a
/// location fix has landed, and a radio that fills in for the current pick.
class _StoreOption extends StatelessWidget {
  final ShieldStore store;
  final bool selected;
  final String? distanceLabel;
  final VoidCallback onTap;

  const _StoreOption({
    required this.store,
    required this.selected,
    required this.distanceLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final distanceLabel = this.distanceLabel;

    return Material(
      color: selected ? AppColors.chipBlueTint : AppColors.white,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? AppColors.brandBlue : AppColors.border,
            ),
          ),
          padding: const EdgeInsets.all(11),
          child: Row(
            children: [
              Icon(
                selected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_unchecked_rounded,
                size: 20,
                color: selected ? AppColors.brandBlue : AppColors.textMuted,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      store.name,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textDark,
                      ),
                    ),
                    Text(
                      store.addressLine,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              if (distanceLabel != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.panelBlue,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    distanceLabel,
                    style: const TextStyle(
                      fontSize: 11,
                      height: 1,
                      fontWeight: FontWeight.w800,
                      color: AppColors.brandBlue,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
