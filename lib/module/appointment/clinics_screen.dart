import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../location/location_sheet.dart';
import 'clinic.dart';
import 'clinic_detail_screen.dart';

/// Directory of clinics and hospitals, shown by the Appointments destination.
class ClinicsScreen extends StatefulWidget {
  const ClinicsScreen({super.key});

  @override
  State<ClinicsScreen> createState() => _ClinicsScreenState();
}

class _ClinicsScreenState extends State<ClinicsScreen> {
  String _area = 'Perinthalmanna';
  String _query = '';
  final Set<String> _favourites = {};

  List<Clinic> get _results {
    if (_query.trim().isEmpty) {
      return ClinicDirectory.clinics;
    }
    final needle = _query.trim().toLowerCase();
    return ClinicDirectory.clinics
        .where(
          (clinic) =>
              clinic.name.toLowerCase().contains(needle) ||
              clinic.type.toLowerCase().contains(needle),
        )
        .toList();
  }

  Future<void> _chooseArea() async {
    final pincode = await LocationSheet.show(context, '');
    if (pincode != null && mounted) {
      setState(() => _area = LocationSheet.describe(pincode));
    }
  }

  @override
  Widget build(BuildContext context) {
    final results = _results;

    return Scaffold(
      backgroundColor: AppColors.pageTint,
      // The same head every other tab wears: white, dark title, a hairline
      // under it. This screen used to carry a green curved banner of its own,
      // which made Appointments look like a different app from Dietitian and
      // the wallet sitting either side of it.
      appBar: AppBar(
        backgroundColor: AppColors.white,
        surfaceTintColor: AppColors.white,
        elevation: 0,
        title: const Text(
          'Clinics & Hospitals',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.textDark,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(42),
          child: Column(
            children: [
              _AreaPicker(area: _area, onChangeArea: _chooseArea),
              const Divider(height: 1, color: AppColors.border),
            ],
          ),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: _SearchField(
              hint: 'Search clinics or hospitals...',
              onChanged: (value) => setState(() => _query = value),
            ),
          ),
          Expanded(
            child: results.isEmpty
                ? const _EmptyResults()
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    itemCount: results.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final clinic = results[index];
                      return _ClinicCard(
                        clinic: clinic,
                        isFavourite: _favourites.contains(clinic.name),
                        onToggleFavourite: () => setState(() {
                          if (!_favourites.remove(clinic.name)) {
                            _favourites.add(clinic.name);
                          }
                        }),
                        onOpen: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ClinicDetailScreen(clinic: clinic),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

/// Which area the list is showing, and the way to change it.
///
/// It used to be the second line of a banner. Without the banner it needs a
/// home of its own, and under the title is where it was — the difference is
/// that it is now dark text on white like every other control on the screen.
class _AreaPicker extends StatelessWidget {
  final String area;
  final VoidCallback onChangeArea;

  const _AreaPicker({required this.area, required this.onChangeArea});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 0, 16, 8),
        child: InkWell(
          onTap: onChangeArea,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.location_on_outlined,
                  size: 17,
                  color: AppColors.brandBlue,
                ),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    area,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.brandBlue,
                    ),
                  ),
                ),
                const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 19,
                  color: AppColors.brandBlue,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  final String hint;
  final ValueChanged<String> onChanged;

  const _SearchField({required this.hint, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return TextField(
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 15.5),
        prefixIcon: const Icon(
          Icons.search_rounded,
          color: AppColors.brandBlue,
          size: 22,
        ),
        filled: true,
        fillColor: AppColors.white,
        contentPadding: const EdgeInsets.symmetric(vertical: 16),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: const BorderSide(color: AppColors.brandBlue, width: 1.4),
        ),
      ),
    );
  }
}

class _ClinicCard extends StatelessWidget {
  final Clinic clinic;
  final bool isFavourite;
  final VoidCallback onToggleFavourite;
  final VoidCallback onOpen;

  const _ClinicCard({
    required this.clinic,
    required this.isFavourite,
    required this.onToggleFavourite,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              ClinicLogo(clinic: clinic, size: 58),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      clinic.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 6),
                    _MetaRow(
                      icon: Icons.location_on_outlined,
                      text: clinic.location,
                    ),
                    const SizedBox(height: 3),
                    _MetaRow(icon: Icons.phone_outlined, text: clinic.phone),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _FavouriteButton(
                isFavourite: isFavourite,
                onTap: onToggleFavourite,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Lettermark tile standing in for a clinic logo asset.
class ClinicLogo extends StatelessWidget {
  final Clinic clinic;
  final double size;

  const ClinicLogo({super.key, required this.clinic, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: clinic.tint,
        borderRadius: BorderRadius.circular(size * 0.22),
        border: Border.all(color: AppColors.border),
      ),
      alignment: Alignment.center,
      child: Text(
        clinic.initials,
        style: TextStyle(
          fontSize: size * 0.34,
          fontWeight: FontWeight.w800,
          color: AppColors.brandBlue,
        ),
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _MetaRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 15, color: AppColors.textMuted),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13.5, color: AppColors.textBody),
          ),
        ),
      ],
    );
  }
}

class _FavouriteButton extends StatelessWidget {
  final bool isFavourite;
  final VoidCallback onTap;

  const _FavouriteButton({required this.isFavourite, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: isFavourite,
      label: isFavourite ? 'Remove from saved' : 'Save clinic',
      child: Material(
        color: isFavourite ? AppColors.brandBlue : AppColors.chipBlueTint,
        shape: const CircleBorder(),
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: 42,
            height: 42,
            child: Icon(
              isFavourite ? Icons.favorite_rounded : Icons.favorite_border,
              size: 21,
              color: isFavourite ? AppColors.white : AppColors.brandBlue,
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyResults extends StatelessWidget {
  const _EmptyResults();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.search_off_rounded,
            size: 52,
            color: AppColors.searchBorder,
          ),
          SizedBox(height: 12),
          Text(
            'No clinics match your search',
            style: TextStyle(fontSize: 15.5, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}
