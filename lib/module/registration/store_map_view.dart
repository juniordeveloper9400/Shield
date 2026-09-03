import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../theme/app_colors.dart';
import 'shield_store.dart';
import 'store_locator.dart';

/// The "Your SHIELD store" branch map.
///
/// Every branch is a **red pin with its name on a tag above it**; the chosen
/// branch is a deeper red and larger. Tapping a pin selects that branch. A
/// "Use my location" button is optional sugar — it drops a "you" dot and hands
/// a distance-ranked list back through [onLocated] — and the picker underneath
/// stays fully usable if it is never pressed, so the map never blocks
/// registration.
///
/// OpenStreetMap tiles: no API key, no billing, and the same on the APK and
/// the web build.
class StoreMapView extends StatefulWidget {
  final String? selectedId;
  final ValueChanged<ShieldStore> onSelected;

  /// Fired once a location fix lands, so the caller can re-rank its list.
  final ValueChanged<StoreLocationResult>? onLocated;

  /// Where the map opens before any fix — usually the pincode-suggested branch.
  final ShieldStore? focusOn;

  const StoreMapView({
    super.key,
    required this.selectedId,
    required this.onSelected,
    this.onLocated,
    this.focusOn,
  });

  /// Test hook: widget tests cannot load OSM tiles and `pumpAndSettle` snags on
  /// the map's timers, so they set this to `false` and get an inert stand-in.
  @visibleForTesting
  static bool renderMap = true;

  @override
  State<StoreMapView> createState() => _StoreMapViewState();
}

class _StoreMapViewState extends State<StoreMapView> {
  final MapController _map = MapController();
  StoreLocationResult? _loc;
  bool _busy = false;

  /// Branches that have coordinates on record — the only ones that can be
  /// pinned.
  List<ShieldStore> get _located =>
      StoreDirectory.all.where((s) => s.hasLocation).toList();

  LatLng get _initialCenter {
    final focus = widget.focusOn;
    if (focus != null && focus.hasLocation) {
      return LatLng(focus.latitude!, focus.longitude!);
    }
    final located = _located;
    if (located.isEmpty) {
      return const LatLng(11.0, 76.1); // Malappuram-ish
    }
    var lat = 0.0, lng = 0.0;
    for (final s in located) {
      lat += s.latitude!;
      lng += s.longitude!;
    }
    return LatLng(lat / located.length, lng / located.length);
  }

  Future<void> _locate() async {
    if (_busy) return;
    setState(() => _busy = true);
    final result = await StoreLocator.locate();
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (result.ok) _loc = result;
    });
    if (result.ok) {
      widget.onLocated?.call(result);
      final p = result.position;
      if (p != null) _map.move(LatLng(p.latitude, p.longitude), 11);
    } else {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(
              'Could not get your location. The list below still works.',
            ),
          ),
        );
    }
  }

  void _select(ShieldStore s) {
    widget.onSelected(s);
    if (s.hasLocation) {
      _map.move(LatLng(s.latitude!, s.longitude!), _map.camera.zoom);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!StoreMapView.renderMap) {
      return const SizedBox.shrink();
    }

    final me = _loc?.position;
    final mePoint = me == null ? null : LatLng(me.latitude, me.longitude);

    // Unselected pins first, the selected one last so its tag sits on top.
    final ordered = [
      for (final s in _located)
        if (s.id != widget.selectedId) s,
      for (final s in _located)
        if (s.id == widget.selectedId) s,
    ];

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        height: 240,
        child: Stack(
          children: [
            FlutterMap(
              mapController: _map,
              options: MapOptions(
                initialCenter: _initialCenter,
                initialZoom: 10.5,
                minZoom: 8,
                maxZoom: 17,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.pinchZoom |
                      InteractiveFlag.drag |
                      InteractiveFlag.doubleTapZoom |
                      InteractiveFlag.flingAnimation,
                ),
              ),
              children: [
                TileLayer(
                  urlTemplate:
                      'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.zabnix.shield',
                ),
                MarkerLayer(
                  markers: [
                    if (mePoint != null)
                      Marker(
                        point: mePoint,
                        width: 22,
                        height: 22,
                        child: const _MeDot(),
                      ),
                    for (final s in ordered)
                      Marker(
                        point: LatLng(s.latitude!, s.longitude!),
                        width: 156,
                        height: 66,
                        alignment: Alignment.bottomCenter,
                        child: _StorePin(
                          name: s.area,
                          selected: s.id == widget.selectedId,
                          onTap: () => _select(s),
                        ),
                      ),
                  ],
                ),
              ],
            ),
            Positioned(
              right: 8,
              bottom: 8,
              child: _RoundButton(
                busy: _busy,
                icon: Icons.my_location_rounded,
                onTap: _locate,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MeDot extends StatelessWidget {
  const _MeDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.brandBlue,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: [
          BoxShadow(
            color: AppColors.brandBlue.withValues(alpha: 0.4),
            blurRadius: 8,
            spreadRadius: 1,
          ),
        ],
      ),
    );
  }
}

/// A branch marker: the store name on a small white tag, directly above a red
/// map pin whose tip marks the branch. The selected branch gets a deeper red,
/// a bolder tag and a larger pin.
class _StorePin extends StatelessWidget {
  final String name;
  final bool selected;
  final VoidCallback onTap;

  const _StorePin({
    required this.name,
    required this.selected,
    required this.onTap,
  });

  static const Color _red = Color(0xFFE23744);
  static const Color _redDeep = Color(0xFFC0182A);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Flexible(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 154),
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: selected ? _redDeep : const Color(0x33000000),
                  width: selected ? 1.2 : 1,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 3,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10.5,
                  height: 1.15,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w700,
                  color: selected ? _redDeep : AppColors.textDark,
                ),
              ),
            ),
          ),
          const SizedBox(height: 1),
          Icon(
            Icons.location_on,
            size: selected ? 40 : 30,
            color: selected ? _redDeep : _red,
            shadows: const [
              Shadow(color: Colors.black38, blurRadius: 3, offset: Offset(0, 1)),
            ],
          ),
        ],
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  final IconData icon;
  final bool busy;
  final VoidCallback onTap;

  const _RoundButton({
    required this.icon,
    required this.busy,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 2,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: busy ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: busy
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.brandBlue,
                  ),
                )
              : Icon(icon, size: 20, color: AppColors.brandBlue),
        ),
      ),
    );
  }
}
