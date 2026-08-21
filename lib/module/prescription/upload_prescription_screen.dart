import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../cart/cart_service.dart';
import 'prescription_copy.dart';
import 'prescription_detail_card.dart';
import 'prescription_form.dart';
import 'prescription_form_sheet.dart';
import 'prescription_record.dart';

/// Prescription flow, in two halves.
///
/// With nothing uploaded the screen is the upload form: pick from camera or
/// gallery, review the file against the stated rules, say who it is for, how
/// much to dispense, and whether it repeats. Once something has been uploaded
/// the same screen becomes the list of prescriptions, each one a form for the
/// medicines on it — because from that point on the question is no longer
/// "how do I upload this" but "what is on it, and do I want it".
class UploadPrescriptionScreen extends StatefulWidget {
  const UploadPrescriptionScreen({super.key});

  /// Cap from the on-screen guidance.
  static const int maxBytes = kPrescriptionMaxBytes;

  @override
  State<UploadPrescriptionScreen> createState() =>
      _UploadPrescriptionScreenState();
}

class _UploadPrescriptionScreenState extends State<UploadPrescriptionScreen> {
  final PrescriptionBook _book = PrescriptionBook.instance;

  /// The inline form, shown only while the book is empty. Replaced rather than
  /// reused after a submission, so a second prescription never opens with the
  /// first one's file and patient already filled in.
  PrescriptionFormController _form = PrescriptionFormController();

  /// Screen-local, and deliberately not remembered between visits: a member
  /// who switches once to read the steps should not find the whole flow in a
  /// language they did not choose the next time they upload.
  AppLanguage _language = AppLanguage.english;

  PrescriptionCopy get _copy => PrescriptionCopy.of(_language);

  @override
  void initState() {
    super.initState();
    _book.addListener(_onBookChanged);
  }

  @override
  void dispose() {
    _book.removeListener(_onBookChanged);
    _form.dispose();
    super.dispose();
  }

  void _onBookChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _submitInlineForm() {
    final record = _form.addTo(_book);
    setState(() {
      final spent = _form;
      _form = PrescriptionFormController();
      spent.dispose();
    });
    _say('${record.patient.name} · ${record.supplyLabel}');
  }

  Future<void> _addAnother() async {
    final record = await PrescriptionFormSheet.show(context, copy: _copy);
    if (record != null && mounted) {
      _say('${record.patient.name} · ${record.supplyLabel}');
    }
  }

  void _delete(PrescriptionRecord record) {
    final index = _book.indexOf(record.id);
    _book.remove(record.id);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(_copy.prescriptionRemoved),
          action: SnackBarAction(
            label: _copy.undo,
            // Deleting a card takes every medicine typed onto it with it, so
            // the way back is offered rather than a confirmation asked for.
            onPressed: () => _book.insert(index, record),
          ),
        ),
      );
  }

  void _addToCart(PrescriptionRecord record) {
    final lines = record.dispensable;
    for (final medicine in lines) {
      CartService.instance.add(
        name: medicine.name.trim(),
        pack:
            '${_copy.intake} ${medicine.intake.code} · '
            '${record.days} ${_copy.total.toLowerCase()}',
        price: 0,
        qty: medicine.intake.totalFor(record.days),
      );
    }
    record.inCart = true;
    _book.touch();
    _say('${lines.length} · ${_copy.sentToCart}');
  }

  void _say(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _onChanged() {
    setState(() {});
    _book.touch();
  }

  @override
  Widget build(BuildContext context) {
    final empty = _book.isEmpty;

    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        surfaceTintColor: AppColors.white,
        elevation: 0,
        title: const Text(
          'Upload Prescription',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.textDark,
          ),
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: AppColors.border),
        ),
      ),
      body: empty ? _buildUploadForm() : _buildPrescriptionList(),
      bottomNavigationBar: empty
          ? _BottomBar(
              label: _copy.proceed,
              // Rebuilt as the form fills in, without the screen holding a
              // second copy of its state to know when.
              listenable: _form,
              enabled: () => _form.isComplete,
              onPressed: _submitInlineForm,
            )
          : _BottomBar(
              label: _copy.addNewPrescription,
              icon: Icons.add_rounded,
              filled: false,
              enabled: () => true,
              onPressed: _addAnother,
            ),
    );
  }

  Widget _buildUploadForm() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      children: [
        _LanguageToggle(
          language: _language,
          onSelect: (language) => setState(() => _language = language),
        ),
        const SizedBox(height: 16),
        PrescriptionFormBody(controller: _form, copy: _copy),
        const SizedBox(height: 20),
        _OrderStepsBox(copy: _copy),
        const SizedBox(height: 22),
        const Divider(height: 1, color: AppColors.border),
        const SizedBox(height: 22),
        _PharmacistCallCard(copy: _copy),
      ],
    );
  }

  Widget _buildPrescriptionList() {
    final records = _book.records;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      children: [
        _LanguageToggle(
          language: _language,
          onSelect: (language) => setState(() => _language = language),
        ),
        const SizedBox(height: 16),
        Text(
          _copy.yourPrescriptions,
          style: const TextStyle(
            fontSize: 18,
            height: 1.3,
            fontWeight: FontWeight.w700,
            color: AppColors.textDark,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          _copy.yourPrescriptionsIntro,
          style: const TextStyle(
            fontSize: 14.5,
            height: 1.4,
            color: AppColors.textBody,
          ),
        ),
        const SizedBox(height: 18),
        for (final record in records)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: PrescriptionDetailCard(
              key: ValueKey(record.id),
              record: record,
              copy: _copy,
              onChanged: _onChanged,
              onDelete: () => _delete(record),
              onAddToCart: () => _addToCart(record),
            ),
          ),
        const SizedBox(height: 6),
        _PharmacistCallCard(copy: _copy),
      ],
    );
  }
}

/// Two-option switch between the languages the screen is written in.
///
/// Both options are labelled in their own script, so a reader who cannot read
/// the current one can still find their way out of it — which is the whole
/// point of a language switch and the one thing a flag or a globe icon
/// cannot do.
class _LanguageToggle extends StatelessWidget {
  final AppLanguage language;
  final ValueChanged<AppLanguage> onSelect;

  const _LanguageToggle({required this.language, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.pageTint,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppColors.border),
        ),
        padding: const EdgeInsets.all(3),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 7),
              child: Icon(
                Icons.translate_rounded,
                size: 17,
                color: AppColors.brandBlue,
              ),
            ),
            for (final option in AppLanguage.values)
              _LanguageOption(
                option: option,
                isSelected: option == language,
                onTap: () => onSelect(option),
              ),
          ],
        ),
      ),
    );
  }
}

class _LanguageOption extends StatelessWidget {
  final AppLanguage option;
  final bool isSelected;
  final VoidCallback onTap;

  const _LanguageOption({
    required this.option,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: isSelected,
      label: option.label,
      child: Material(
        color: isSelected ? AppColors.brandBlue : AppColors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            // The code is decoration; the accessible name is the language,
            // set on the Semantics above. Left in, the two merge and a reader
            // hears "English E N G".
            child: ExcludeSemantics(
              child: Text(
                option.code,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w700,
                  letterSpacing: 0.4,
                  color: isSelected ? AppColors.white : AppColors.textBody,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The ordering procedure, numbered, with a rule running between the steps.
///
/// It sits below the form rather than above it: someone who already knows the
/// flow should not have to scroll past an explanation to use it, and someone
/// who does not will read down to it.
class _OrderStepsBox extends StatelessWidget {
  final PrescriptionCopy copy;

  const _OrderStepsBox({required this.copy});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            copy.howToOrder,
            style: const TextStyle(
              fontSize: 16.5,
              fontWeight: FontWeight.w800,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            copy.howToOrderIntro,
            style: const TextStyle(
              fontSize: 13,
              height: 1.35,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 14),
          for (var index = 0; index < copy.steps.length; index++)
            _OrderStepRow(
              number: index + 1,
              step: copy.steps[index],
              isLast: index == copy.steps.length - 1,
            ),
        ],
      ),
    );
  }
}

class _OrderStepRow extends StatelessWidget {
  final int number;
  final OrderStep step;
  final bool isLast;

  const _OrderStepRow({
    required this.number,
    required this.step,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 26,
                height: 26,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: AppColors.brandBlue,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '$number',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppColors.white,
                  ),
                ),
              ),
              // The thread joining one step to the next, so the column reads
              // as a sequence rather than as five separate notes.
              if (!isLast)
                const Expanded(
                  child: VerticalDivider(
                    width: 26,
                    thickness: 1.5,
                    color: AppColors.border,
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 10 : 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    step.title,
                    style: const TextStyle(
                      fontSize: 14.5,
                      height: 1.3,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    step.detail,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      color: AppColors.textBody,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PharmacistCallCard extends StatelessWidget {
  final PrescriptionCopy copy;

  const _PharmacistCallCard({required this.copy});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: const BoxDecoration(
              color: Color(0xFFF6D98C),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.support_agent_rounded,
              size: 30,
              color: Color(0xFF6B4E12),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  copy.pharmacistTitle,
                  style: const TextStyle(
                    fontSize: 16.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  copy.pharmacistDetail,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.4,
                    color: AppColors.textBody,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.greenTint,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              copy.free,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.brandGreenDark,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The one action bar at the foot of the screen: Proceed while the form is
/// being filled in, "Add new prescription" once the list has taken over.
class _BottomBar extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool filled;

  /// Rebuild trigger; null when the label's enablement cannot change.
  final Listenable? listenable;

  final bool Function() enabled;
  final VoidCallback onPressed;

  const _BottomBar({
    required this.label,
    this.icon,
    this.filled = true,
    this.listenable,
    required this.enabled,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final bar = Container(
      decoration: const BoxDecoration(
        color: AppColors.white,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          child: SizedBox(width: double.infinity, child: _button()),
        ),
      ),
    );

    final trigger = listenable;
    if (trigger == null) {
      return bar;
    }
    return ListenableBuilder(listenable: trigger, builder: (_, _) => bar);
  }

  Widget _button() {
    final text = Text(
      label,
      style: TextStyle(
        fontSize: 16.5,
        fontWeight: FontWeight.w700,
        color: filled ? AppColors.white : AppColors.brandBlue,
      ),
    );
    final action = enabled() ? onPressed : null;

    if (!filled) {
      return OutlinedButton.icon(
        onPressed: action,
        icon: icon == null
            ? null
            : Icon(icon, size: 20, color: AppColors.brandBlue),
        label: text,
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: AppColors.brandBlue, width: 1.4),
          backgroundColor: AppColors.offerTint,
          padding: const EdgeInsets.symmetric(vertical: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );
    }

    return FilledButton(
      onPressed: action,
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.brandBlue,
        disabledBackgroundColor: AppColors.searchBorder,
        padding: const EdgeInsets.symmetric(vertical: 17),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: text,
    );
  }
}
