import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../location/address_book.dart';
import '../location/address_form_screen.dart';
import '../patients/patient_book.dart';
import '../patients/patient_form_sheet.dart';

/// "Patient & address details": who an order is for and where it goes,
/// chosen together on one screen since the order summary needs both before it
/// can move on to payment.
///
/// Opened from the "Change" link on either row of the order summary's
/// deliver-to/patient strip. Saving here commits the address straight to
/// [AddressBook] — the same singleton every other delivery-address surface
/// reads from — and hands the chosen patient back to the caller, which has
/// nowhere else to keep one.
class PatientAddressDetailsScreen extends StatefulWidget {
  /// The patient already chosen on the order summary, if any — carried in
  /// rather than read off a shared store, since nothing else in the app
  /// tracks "the current patient" the way [AddressBook] tracks "the current
  /// address".
  final Patient? initialPatient;

  const PatientAddressDetailsScreen({super.key, this.initialPatient});

  @override
  State<PatientAddressDetailsScreen> createState() =>
      _PatientAddressDetailsScreenState();
}

class _PatientAddressDetailsScreenState
    extends State<PatientAddressDetailsScreen> {
  Patient? _patient;
  Address? _address;

  @override
  void initState() {
    super.initState();
    _patient = widget.initialPatient;
    _address = AddressBook.instance.deliverTo;
  }

  bool get _canSave => _patient != null && _address != null;

  Future<void> _addPatient() async {
    final saved = await PatientFormSheet.show(context);
    if (saved != null && mounted) {
      setState(() => _patient = saved);
    }
  }

  Future<void> _editPatient(Patient patient) async {
    final saved = await PatientFormSheet.show(context, existing: patient);
    if (saved != null && mounted) {
      // Editing may have changed the very record selected — carry the fresh
      // copy forward rather than leaving the row pointed at the stale one.
      setState(() => _patient = saved);
    }
  }

  Future<void> _addAddress() async {
    final saved = await Navigator.of(context).push<Address>(
      MaterialPageRoute(builder: (_) => const AddressFormScreen()),
    );
    if (saved != null && mounted) {
      setState(() => _address = saved);
    }
  }

  void _save() {
    final address = _address;
    if (address != null) {
      // A freshly-added address already became deliverTo the moment it was
      // saved; this only matters when an existing one was picked instead.
      AddressBook.instance.select(address);
    }
    Navigator.of(context).pop(_patient);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageTint,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        surfaceTintColor: AppColors.white,
        elevation: 0,
        title: const Text(
          'Patient & address details',
          style: TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w700,
            color: AppColors.textDark,
          ),
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: AppColors.border),
        ),
      ),
      body: ListenableBuilder(
        listenable: Listenable.merge([
          PatientBook.instance,
          AddressBook.instance,
        ]),
        builder: (context, _) {
          final patients = PatientBook.instance.patients;
          final addresses = AddressBook.instance.addresses;

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              _SectionHeader(
                title: 'Select Patient',
                actionLabel: 'Add Patient',
                onAction: _addPatient,
              ),
              const SizedBox(height: 10),
              if (patients.isEmpty)
                const _EmptyNote(text: 'No patients on this account yet.')
              else
                for (final patient in patients)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _PatientTile(
                      patient: patient,
                      selected: patient.id == _patient?.id,
                      onTap: () => setState(() => _patient = patient),
                      onEdit: () => _editPatient(patient),
                    ),
                  ),
              const SizedBox(height: 22),
              _SectionHeader(
                title: 'Select Address',
                actionLabel: 'Add Address',
                onAction: _addAddress,
              ),
              const SizedBox(height: 10),
              if (addresses.isEmpty)
                const _EmptyNote(text: 'No saved addresses yet.')
              else
                for (final address in addresses)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _AddressTile(
                      address: address,
                      selected: identical(address, _address),
                      onTap: () => setState(() => _address = address),
                    ),
                  ),
            ],
          );
        },
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppColors.white,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _canSave ? _save : null,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.brandBlue,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  'Save & continue',
                  style: TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String actionLabel;
  final VoidCallback onAction;

  const _SectionHeader({
    required this.title,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.textDark,
            ),
          ),
        ),
        TextButton.icon(
          onPressed: onAction,
          icon: const Icon(Icons.add_rounded, size: 18),
          label: Text(actionLabel),
          style: TextButton.styleFrom(
            foregroundColor: AppColors.brandBlue,
            minimumSize: Size.zero,
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            textStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _EmptyNote extends StatelessWidget {
  final String text;

  const _EmptyNote({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 13.5, color: AppColors.textMuted),
      ),
    );
  }
}

/// One row on "Select Patient": a radio for who this order is for, and a
/// pencil to fix up their details without leaving the list to do it.
class _PatientTile extends StatelessWidget {
  final Patient patient;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onEdit;

  const _PatientTile({
    required this.patient,
    required this.selected,
    required this.onTap,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.offerTint : AppColors.white,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? AppColors.brandBlue : AppColors.border,
              width: selected ? 1.4 : 1,
            ),
          ),
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Icon(
                selected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_unchecked_rounded,
                size: 21,
                color: selected ? AppColors.brandBlue : AppColors.searchBorder,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      patient.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${patient.ageLine} · ${patient.gender.label}',
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              if (patient.relation == PatientRelation.self) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.chipBlueTint,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Me',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.brandBlue,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
              ],
              IconButton(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined, size: 18),
                color: AppColors.textMuted,
                tooltip: 'Edit patient',
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One row on "Select Address" — the same label-plus-summary shape the
/// checkout's own delivery panel prints, just picked from rather than edited.
class _AddressTile extends StatelessWidget {
  final Address address;
  final bool selected;
  final VoidCallback onTap;

  const _AddressTile({
    required this.address,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.offerTint : AppColors.white,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? AppColors.brandBlue : AppColors.border,
              width: selected ? 1.4 : 1,
            ),
          ),
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                selected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_unchecked_rounded,
                size: 21,
                color: selected ? AppColors.brandBlue : AppColors.searchBorder,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Who this address is for leads — the same order the
                    // patient row above it reads in, so an address a patient
                    // form put on file is recognisable as theirs at a glance.
                    Text(
                      address.receiver,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${address.label.label} (${address.pincode})',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textBody,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      address.summary,
                      style: const TextStyle(
                        fontSize: 12.5,
                        height: 1.4,
                        color: AppColors.textMuted,
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
