import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import 'prescription_copy.dart';
import 'prescription_form.dart';
import 'prescription_record.dart';

/// "Add new prescription", opened over the list rather than replacing it.
///
/// Holds the same form the screen shows when nothing has been uploaded yet, so
/// there is one upload flow rather than two that have to be kept in step. It
/// opens over the list because the prescriptions already added are the reason
/// a second one is being uploaded — losing sight of them would be losing the
/// context for the choice.
class PrescriptionFormSheet extends StatefulWidget {
  final PrescriptionCopy copy;

  const PrescriptionFormSheet({super.key, required this.copy});

  /// Returns the filed record, or null when the sheet is dismissed.
  static Future<PrescriptionRecord?> show(
    BuildContext context, {
    required PrescriptionCopy copy,
  }) {
    return showModalBottomSheet<PrescriptionRecord>(
      context: context,
      backgroundColor: AppColors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) => PrescriptionFormSheet(copy: copy),
    );
  }

  @override
  State<PrescriptionFormSheet> createState() => _PrescriptionFormSheetState();
}

class _PrescriptionFormSheetState extends State<PrescriptionFormSheet> {
  final PrescriptionFormController _form = PrescriptionFormController();

  @override
  void dispose() {
    _form.dispose();
    super.dispose();
  }

  void _submit() {
    final record = _form.addTo(PrescriptionBook.instance);
    Navigator.of(context).pop(record);
  }

  @override
  Widget build(BuildContext context) {
    final copy = widget.copy;

    return Padding(
      // Lifts the submit button clear of the keyboard when the custom-days
      // field has focus.
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.92,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.searchBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      copy.newPrescription,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textDark,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                    color: AppColors.textMuted,
                    tooltip: MaterialLocalizations.of(
                      context,
                    ).closeButtonTooltip,
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.border),
            Flexible(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                children: [
                  PrescriptionFormBody(
                    controller: _form,
                    copy: copy,
                    showHeading: false,
                  ),
                ],
              ),
            ),
            _SubmitBar(form: _form, label: copy.addPrescription, onSubmit: _submit),
          ],
        ),
      ),
    );
  }
}

class _SubmitBar extends StatelessWidget {
  final PrescriptionFormController form;
  final String label;
  final VoidCallback onSubmit;

  const _SubmitBar({
    required this.form,
    required this.label,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.white,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          child: SizedBox(
            width: double.infinity,
            child: ListenableBuilder(
              listenable: form,
              builder: (context, _) {
                return FilledButton(
                  onPressed: form.isComplete ? onSubmit : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.brandBlue,
                    disabledBackgroundColor: AppColors.searchBorder,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.white,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
