import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import 'patient_book.dart';
import 'patient_form_sheet.dart';

/// "Who is this for?" — the row the prescription upload puts above its
/// proceed bar.
///
/// Doubles as the entry point for adding the first patient, so an empty book
/// is not a dead end in the middle of a flow.
class PatientPicker extends StatelessWidget {
  final Patient? selected;
  final ValueChanged<Patient> onSelect;

  /// Overridden by the upload screen when it is showing Malayalam. Defaults
  /// keep every other caller as it was.
  final String label;
  final String hint;

  const PatientPicker({
    super.key,
    required this.selected,
    required this.onSelect,
    this.label = 'Prescription is for',
    this.hint = 'Select patient',
  });

  Future<void> _choose(BuildContext context) async {
    final chosen = await PatientSelectSheet.show(context, selected: selected);
    if (chosen != null) {
      onSelect(chosen);
    }
  }

  @override
  Widget build(BuildContext context) {
    final patient = selected;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          // An unanswered choice is drawn as an open question rather than as
          // an error: nothing has gone wrong yet.
          color: patient == null ? AppColors.searchBorder : AppColors.brandBlue,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _choose(context),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
          child: Row(
            children: [
              Icon(
                Icons.person_outline_rounded,
                size: 22,
                color: patient == null
                    ? AppColors.textMuted
                    : AppColors.brandBlue,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      patient == null ? hint : patient.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDark,
                      ),
                    ),
                    if (patient != null) ...[
                      const SizedBox(height: 1),
                      Text(
                        patient.summary,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(
                Icons.keyboard_arrow_down_rounded,
                color: AppColors.textDark,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The sheet the picker opens: everyone on the account, plus a way to add.
class PatientSelectSheet extends StatelessWidget {
  final Patient? selected;

  const PatientSelectSheet({super.key, this.selected});

  static Future<Patient?> show(BuildContext context, {Patient? selected}) {
    return showModalBottomSheet<Patient>(
      context: context,
      backgroundColor: AppColors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) => PatientSelectSheet(selected: selected),
    );
  }

  Future<void> _addPatient(BuildContext context) async {
    final navigator = Navigator.of(context);
    final saved = await PatientFormSheet.show(context);
    if (saved != null) {
      // A patient added from here is the one being chosen, so the sheet
      // closes with it rather than making the choice twice.
      navigator.pop(saved);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: ListenableBuilder(
        listenable: PatientBook.instance,
        builder: (context, _) {
          final patients = PatientBook.instance.patients;

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 12, 8),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Select patient',
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textDark,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                      color: AppColors.textDark,
                      tooltip: 'Close',
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: AppColors.border),
              if (patients.isEmpty)
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 24, 20, 8),
                  child: Text(
                    'No patients on this account yet.',
                    style: TextStyle(fontSize: 14.5, color: AppColors.textBody),
                  ),
                )
              else
                // Bounded rather than shrink-wrapped: a long list must scroll
                // inside the sheet instead of pushing the Add row off screen.
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.sizeOf(context).height * 0.45,
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    padding: EdgeInsets.zero,
                    itemCount: patients.length,
                    separatorBuilder: (_, _) =>
                        const Divider(height: 1, color: AppColors.border),
                    itemBuilder: (context, index) {
                      final patient = patients[index];
                      return _PatientRow(
                        patient: patient,
                        isSelected: patient.id == selected?.id,
                        onTap: () => Navigator.of(context).pop(patient),
                      );
                    },
                  ),
                ),
              const Divider(height: 1, color: AppColors.border),
              InkWell(
                onTap: () => _addPatient(context),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                  child: Row(
                    children: [
                      Icon(
                        Icons.person_add_alt_1_rounded,
                        size: 21,
                        color: AppColors.brandBlue,
                      ),
                      SizedBox(width: 12),
                      Text(
                        'Add a new patient',
                        style: TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.brandBlue,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 6),
            ],
          );
        },
      ),
    );
  }
}

class _PatientRow extends StatelessWidget {
  final Patient patient;
  final bool isSelected;
  final VoidCallback onTap;

  const _PatientRow({
    required this.patient,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    patient.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    patient.summary,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textMuted,
                    ),
                  ),
                  if (patient.address.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      patient.address,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            Icon(
              isSelected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_unchecked_rounded,
              size: 23,
              color: isSelected ? AppColors.brandBlue : AppColors.searchBorder,
            ),
          ],
        ),
      ),
    );
  }
}
