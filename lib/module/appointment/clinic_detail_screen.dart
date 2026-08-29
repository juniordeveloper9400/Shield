import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import 'clinic.dart';
import 'clinics_screen.dart';

/// Clinic profile with its bookable doctors.
class ClinicDetailScreen extends StatefulWidget {
  final Clinic clinic;

  const ClinicDetailScreen({super.key, required this.clinic});

  @override
  State<ClinicDetailScreen> createState() => _ClinicDetailScreenState();
}

class _ClinicDetailScreenState extends State<ClinicDetailScreen> {
  String _query = '';
  String? _speciality;
  bool _expanded = false;

  List<Doctor> get _results {
    final needle = _query.trim().toLowerCase();
    return widget.clinic.doctors.where((doctor) {
      final matchesQuery =
          needle.isEmpty || doctor.name.toLowerCase().contains(needle);
      final matchesSpeciality =
          _speciality == null || doctor.speciality == _speciality;
      return matchesQuery && matchesSpeciality;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final clinic = widget.clinic;
    final results = _results;

    return Scaffold(
      backgroundColor: AppColors.pageTint,
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          _DetailHeader(clinic: clinic),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _Identity(clinic: clinic),
          ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _Description(
              text: clinic.description,
              expanded: _expanded,
              onToggle: () => setState(() => _expanded = !_expanded),
            ),
          ),
          const SizedBox(height: 20),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'Available Doctors',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.textDark,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: _DoctorSearch(
                    onChanged: (value) => setState(() => _query = value),
                  ),
                ),
                const SizedBox(width: 10),
                _FilterButton(
                  isActive: _speciality != null,
                  onTap: () => setState(() => _speciality = null),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: clinic.specialities.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final speciality = clinic.specialities[index];
                return _SpecialityChip(
                  label: speciality,
                  isSelected: _speciality == speciality,
                  onTap: () => setState(
                    () => _speciality = _speciality == speciality
                        ? null
                        : speciality,
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          if (results.isEmpty)
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 24, 20, 40),
              child: Center(
                child: Text(
                  'No doctors match this filter',
                  style: TextStyle(fontSize: 15, color: AppColors.textMuted),
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
              child: Column(
                children: [
                  for (final doctor in results) ...[
                    _DoctorRow(doctor: doctor),
                    const SizedBox(height: 10),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _DetailHeader extends StatelessWidget {
  final Clinic clinic;

  const _DetailHeader({required this.clinic});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      // Extra height below the banner so the logo tile can overlap it.
      height: 236,
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          Container(
            height: 186,
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.brandBlue, AppColors.brandBlue],
              ),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(26)),
            ),
            child: const _BannerPattern(),
          ),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 16, 0),
              child: Row(
                children: [
                  Material(
                    color: AppColors.white,
                    shape: const CircleBorder(),
                    child: InkWell(
                      onTap: () => Navigator.of(context).maybePop(),
                      customBorder: const CircleBorder(),
                      child: const SizedBox(
                        width: 38,
                        height: 38,
                        child: Icon(
                          Icons.chevron_left_rounded,
                          size: 26,
                          color: AppColors.textDark,
                        ),
                      ),
                    ),
                  ),
                  const Spacer(),
                ],
              ),
            ),
          ),
          Positioned(
            right: 20,
            top: 118,
            child: Material(
              color: AppColors.white,
              shape: const CircleBorder(),
              elevation: 2,
              child: InkWell(
                onTap: () {},
                customBorder: const CircleBorder(),
                child: const SizedBox(
                  width: 52,
                  height: 52,
                  child: Icon(
                    Icons.my_location_rounded,
                    size: 24,
                    color: AppColors.brandBlue,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 116,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.textDark.withValues(alpha: 0.12),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClinicLogo(clinic: clinic, size: 76),
            ),
          ),
        ],
      ),
    );
  }
}

/// Faint medical glyphs echoing the reference banner artwork.
class _BannerPattern extends StatelessWidget {
  const _BannerPattern();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(26)),
      child: Stack(
        children: [
          Positioned(
            right: -14,
            top: 10,
            child: Icon(
              Icons.medical_services_outlined,
              size: 96,
              color: AppColors.white.withValues(alpha: 0.10),
            ),
          ),
          Positioned(
            right: 86,
            top: 74,
            child: Icon(
              Icons.medical_services_outlined,
              size: 62,
              color: AppColors.white.withValues(alpha: 0.08),
            ),
          ),
          Positioned(
            left: -10,
            top: 96,
            child: Icon(
              Icons.medical_services_outlined,
              size: 74,
              color: AppColors.white.withValues(alpha: 0.08),
            ),
          ),
        ],
      ),
    );
  }
}

class _Identity extends StatelessWidget {
  final Clinic clinic;

  const _Identity({required this.clinic});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: Text(
                clinic.name,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 23,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textDark,
                ),
              ),
            ),
            if (clinic.isVerified) ...[
              const SizedBox(width: 6),
              const Icon(
                Icons.verified_rounded,
                size: 21,
                color: AppColors.brandBlue,
              ),
            ],
          ],
        ),
        const SizedBox(height: 6),
        Text(
          clinic.type,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 14.5, color: AppColors.textMuted),
        ),
        const SizedBox(height: 10),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 12,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _IconText(icon: Icons.location_on_rounded, text: clinic.location),
            Container(width: 1, height: 14, color: AppColors.border),
            _IconText(icon: Icons.phone_rounded, text: clinic.phone),
          ],
        ),
      ],
    );
  }
}

class _IconText extends StatelessWidget {
  final IconData icon;
  final String text;

  const _IconText({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: AppColors.textMuted),
        const SizedBox(width: 5),
        Text(
          text,
          style: const TextStyle(fontSize: 14, color: AppColors.textBody),
        ),
      ],
    );
  }
}

class _Description extends StatelessWidget {
  final String text;
  final bool expanded;
  final VoidCallback onToggle;

  const _Description({
    required this.text,
    required this.expanded,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          text,
          textAlign: TextAlign.justify,
          maxLines: expanded ? null : 2,
          overflow: expanded ? TextOverflow.visible : TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 14,
            height: 1.5,
            color: AppColors.textMuted,
          ),
        ),
        TextButton(
          onPressed: onToggle,
          style: TextButton.styleFrom(
            minimumSize: Size.zero,
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: Text(
            expanded ? 'read less' : 'read more',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.brandBlue,
            ),
          ),
        ),
      ],
    );
  }
}

class _DoctorSearch extends StatelessWidget {
  final ValueChanged<String> onChanged;

  const _DoctorSearch({required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return TextField(
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: 'Search doctors...',
        hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 15),
        prefixIcon: const Icon(
          Icons.search_rounded,
          color: AppColors.textMuted,
          size: 21,
        ),
        filled: true,
        fillColor: AppColors.white,
        contentPadding: const EdgeInsets.symmetric(vertical: 15),
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

class _FilterButton extends StatelessWidget {
  final bool isActive;
  final VoidCallback onTap;

  const _FilterButton({required this.isActive, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isActive ? AppColors.brandBlue : AppColors.border,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        // Clears the speciality filter; disabled while none is applied.
        onTap: isActive ? onTap : null,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: 52,
          height: 52,
          child: Icon(
            Icons.tune_rounded,
            size: 22,
            color: isActive ? AppColors.white : AppColors.textBody,
          ),
        ),
      ),
    );
  }
}

class _SpecialityChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _SpecialityChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected ? AppColors.brandBlue : AppColors.white,
      borderRadius: BorderRadius.circular(30),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(30),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: isSelected ? AppColors.brandBlue : AppColors.border,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w600,
              color: isSelected ? AppColors.white : AppColors.textDark,
            ),
          ),
        ),
      ),
    );
  }
}

class _DoctorRow extends StatelessWidget {
  final Doctor doctor;

  const _DoctorRow({required this.doctor});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: () {},
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 54,
                height: 54,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.categoryPanel,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  doctor.initials,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: AppColors.brandBlue,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      doctor.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      doctor.speciality,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13.5,
                        color: AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '₹${doctor.fee}',
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.brandBlue,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.chevron_right_rounded,
                size: 22,
                color: AppColors.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
