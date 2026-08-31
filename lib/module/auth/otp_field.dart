import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_colors.dart';

/// A row of single-digit boxes for entering a code.
///
/// The boxes are decoration only — one real field sits invisibly over them and
/// holds the whole code. That is what makes paste, backspace and SMS autofill
/// behave, all of which break when each box is its own input.
class OtpField extends StatefulWidget {
  /// Holds the digits entered so far. The parent reads the code from here.
  final TextEditingController controller;

  final int length;

  /// Paints every box in the error colour after a rejected code.
  final bool hasError;

  /// Fired once the last box is filled, so a complete code submits itself.
  final ValueChanged<String>? onCompleted;

  final bool autofocus;

  /// Supply one to drive focus from the parent — e.g. to put the keyboard back
  /// after a rejected code. When null the field owns a node of its own.
  final FocusNode? focusNode;

  const OtpField({
    super.key,
    required this.controller,
    this.length = 6,
    this.hasError = false,
    this.onCompleted,
    this.autofocus = true,
    this.focusNode,
  });

  @override
  State<OtpField> createState() => _OtpFieldState();
}

class _OtpFieldState extends State<OtpField> {
  /// Used only when the parent did not pass a [FocusNode] of its own.
  FocusNode? _ownFocusNode;

  FocusNode get _focusNode =>
      widget.focusNode ?? (_ownFocusNode ??= FocusNode());

  /// The last code [onCompleted] fired for, so re-focusing a full field does
  /// not submit it a second time.
  String? _submitted;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_handleChange);
    _focusNode.addListener(_repaint);
  }

  @override
  void didUpdateWidget(OtpField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      oldWidget.focusNode?.removeListener(_repaint);
      _focusNode.addListener(_repaint);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleChange);
    widget.focusNode?.removeListener(_repaint);
    _ownFocusNode
      ?..removeListener(_repaint)
      ..dispose();
    super.dispose();
  }

  void _repaint() {
    if (mounted) {
      setState(() {});
    }
  }

  void _handleChange() {
    _repaint();
    final code = widget.controller.text;
    if (code.length < widget.length) {
      _submitted = null;
      return;
    }
    if (code != _submitted) {
      _submitted = code;
      widget.onCompleted?.call(code);
    }
  }

  @override
  Widget build(BuildContext context) {
    final code = widget.controller.text;
    // Where the next digit lands — the box that reads as active.
    final cursor = code.length.clamp(0, widget.length - 1);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _focusNode.requestFocus(),
      child: SizedBox(
        height: 58,
        child: Stack(
          children: [
            Row(
              children: [
                for (var i = 0; i < widget.length; i++) ...[
                  if (i > 0) const SizedBox(width: 9),
                  Expanded(
                    child: _OtpBox(
                      digit: i < code.length ? code[i] : '',
                      active: _focusNode.hasFocus && i == cursor,
                      hasError: widget.hasError,
                    ),
                  ),
                ],
              ],
            ),
            // Transparent text and no cursor: the field is only here to own
            // the keyboard and the value.
            Positioned.fill(
              child: TextField(
                controller: widget.controller,
                focusNode: _focusNode,
                autofocus: widget.autofocus,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                // Lets Android surface the code from the SMS it just received.
                autofillHints: const [AutofillHints.oneTimeCode],
                showCursor: false,
                enableInteractiveSelection: false,
                cursorColor: AppColors.transparent,
                style: const TextStyle(
                  color: AppColors.transparent,
                  fontSize: 1,
                  height: 0.01,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(widget.length),
                ],
                decoration: const InputDecoration(
                  counterText: '',
                  isDense: true,
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OtpBox extends StatelessWidget {
  final String digit;
  final bool active;
  final bool hasError;

  const _OtpBox({
    required this.digit,
    required this.active,
    required this.hasError,
  });

  @override
  Widget build(BuildContext context) {
    final Color line;
    if (hasError) {
      line = AppColors.danger;
    } else if (active || digit.isNotEmpty) {
      line = AppColors.brandBlue;
    } else {
      line = AppColors.border;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 140),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: digit.isEmpty ? AppColors.pageTint : AppColors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: line, width: active || hasError ? 1.6 : 1),
      ),
      child: Text(
        digit,
        style: TextStyle(
          fontSize: 21,
          fontWeight: FontWeight.w800,
          color: hasError ? AppColors.danger : AppColors.textDark,
        ),
      ),
    );
  }
}
