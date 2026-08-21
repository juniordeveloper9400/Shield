import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';

/// The one input decoration in the app: rounded, filled white, brand-blue on
/// focus, [AppColors.danger] when refused.
///
/// Shared rather than rebuilt per screen so a dropdown and a text field sitting
/// in the same form cannot drift apart.
InputDecoration shieldFieldDecoration({
  String? hint,
  IconData? icon,
  Widget? suffix,
  String? prefixText,
  bool isDense = false,
}) {
  return InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(
      color: AppColors.textMuted,
      fontSize: 15,
      fontWeight: FontWeight.w400,
    ),
    prefixIcon: icon == null
        ? null
        : Icon(icon, size: 20, color: AppColors.brandBlue),
    // Sits between the icon and the caret, so a mobile number reads as
    // `+91 9876543210` while only the ten digits are ever edited.
    prefixText: prefixText,
    prefixStyle: const TextStyle(
      fontSize: 15.5,
      fontWeight: FontWeight.w700,
      color: AppColors.textDark,
    ),
    suffixIcon: suffix,
    filled: true,
    fillColor: AppColors.white,
    isDense: isDense,
    contentPadding: EdgeInsets.symmetric(vertical: isDense ? 12 : 16),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: AppColors.border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: AppColors.brandBlue, width: 1.4),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: AppColors.danger),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: AppColors.danger, width: 1.4),
    ),
    disabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: AppColors.border),
    ),
  );
}

/// A field with its label above it, used by every form in the app.
class LabelledField extends StatelessWidget {
  final String label;
  final String hint;
  final TextEditingController controller;
  final IconData? icon;
  final String? prefixText;
  final Widget? suffix;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;
  final List<TextInputFormatter>? inputFormatters;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onSubmitted;
  final bool autofocus;
  final int maxLines;

  /// Locks the value while keeping the field legible — used for the verified
  /// mobile number, which the member must see but may not edit.
  final bool readOnly;

  /// Fired on tap while [readOnly]; how the date field opens its picker.
  final VoidCallback? onTap;

  const LabelledField({
    super.key,
    required this.label,
    required this.hint,
    required this.controller,
    this.icon,
    this.prefixText,
    this.suffix,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
    this.inputFormatters,
    this.validator,
    this.onChanged,
    this.onSubmitted,
    this.autofocus = false,
    this.maxLines = 1,
    this.readOnly = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            color: AppColors.textBody,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          textCapitalization: textCapitalization,
          inputFormatters: inputFormatters,
          validator: validator,
          onChanged: onChanged,
          autofocus: autofocus,
          maxLines: maxLines,
          readOnly: readOnly,
          onTap: onTap,
          textInputAction: maxLines > 1
              ? TextInputAction.newline
              : TextInputAction.done,
          onFieldSubmitted: (_) => onSubmitted?.call(),
          style: TextStyle(
            fontSize: 15.5,
            fontWeight: FontWeight.w600,
            color: readOnly ? AppColors.textBody : AppColors.textDark,
          ),
          decoration: shieldFieldDecoration(
            hint: hint,
            icon: icon,
            suffix: suffix,
            prefixText: prefixText,
          ),
        ),
      ],
    );
  }
}
