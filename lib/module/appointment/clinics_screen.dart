import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../location/location_sheet.dart';
import 'clinic.dart';
import 'clinic_detail_screen.dart';

/// Directory of clinics and hospitals, shown by the Appointment destination.
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
      body: Column(
        children: [
          _CurvedHeader(area: _area, onChangeArea: _chooseArea),
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

/// Rounded brand header used across the clinic screens.
class _CurvedHeader extends StatelessWidget {
  final String area;
  final VoidCallback onChangeArea;

  const _CurvedHeader({required this.area, required this.onChangeArea});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.brandBlue, AppColors.brandNavy],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(26)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 16, 20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _CircleBack(),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Clinics & Hospitals',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppColors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    InkWell(
                      onTap: onChangeArea,
                      borderRadius: BorderRadius.circular(6),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.location_on_outlined,
                              size: 16,
                              color: Color(0xFFDCE7F7),
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                area,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.white,
                                ),
                              ),
                            ),
                            const Icon(
                              Icons.keyboard_arrow_down_rounded,
                              size: 18,
                              color: AppColors.white,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CircleBack extends StatelessWidget {
  const _CircleBack();

  @override
  Widget build(BuildContext context) {
    final navigator = Navigator.of(context);

    return Material(
      color: AppColors.transparent,
      shape: const CircleBorder(side: BorderSide(color: Color(0x66FFFFFF))),
      child: InkWell(
        // No-op when this is a root tab with nothing to pop.
        onTap: navigator.canPop() ? navigator.pop : null,
        customBorder: const CircleBorder(),
        child: const SizedBox(
          width: 38,
          height: 38,
          child: Icon(
            Icons.chevron_left_rounded,
            size: 26,
            color: AppColors.white,
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
        color: isFavourite ? AppColors.brandGreenDeep : AppColors.greenTint,
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
              color: isFavourite ? AppColors.white : AppColors.brandGreenDeep,
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
