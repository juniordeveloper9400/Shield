import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// A file size in the units a person reads it in: KB under a megabyte, MB
/// over it.
String readableBytes(int bytes) {
  if (bytes >= 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }
  return '${(bytes / 1024).toStringAsFixed(0)} KB';
}

/// One of the two ways a file gets into the app: the camera, or what is
/// already on the phone.
///
/// Lives here rather than beside either of the forms that draw it. A
/// prescription and a payment receipt are photographed the same way, out of
/// the same two places, and a second copy of this tile would have drifted
/// from the first the moment one of them was restyled.
///
/// Expands: the tiles are always laid out as a pair sharing a row.
class UploadSourceTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool enabled;
  final VoidCallback onTap;

  const UploadSourceTile({
    super.key,
    required this.icon,
    required this.label,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: AppColors.offerTint,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.searchBorder),
            ),
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 34, color: AppColors.brandBlue),
                const SizedBox(height: 10),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 15,
                    height: 1.25,
                    fontWeight: FontWeight.w600,
                    color: AppColors.brandBlue,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The file that has been picked: what it is called, how big it is, and
/// whether that size is going to be a problem.
///
/// Green while it is fine and red once it is over the cap, because a file
/// that will be refused on submit should say so at the moment it is chosen
/// rather than at the moment the member presses the button.
class UploadedFileCard extends StatelessWidget {
  final String name;
  final int bytes;
  final bool tooLarge;

  /// The cap, written the way the guidance beside it writes it — "5 MB".
  final String limitLabel;

  /// What the member is doing next with the file, once it is in: "ready to
  /// upload", "ready to submit". The card is used on two different forms and
  /// they finish with different words.
  final String readyLabel;

  final String removeLabel;
  final VoidCallback onRemove;

  const UploadedFileCard({
    super.key,
    required this.name,
    required this.bytes,
    required this.tooLarge,
    required this.limitLabel,
    required this.removeLabel,
    required this.onRemove,
    this.readyLabel = 'ready to upload',
  });

  @override
  Widget build(BuildContext context) {
    final size = readableBytes(bytes);

    return Container(
      decoration: BoxDecoration(
        color: tooLarge ? AppColors.dangerTint : AppColors.greenTint,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: tooLarge ? AppColors.dangerLine : AppColors.brandGreenDeep,
        ),
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Icon(
            tooLarge ? Icons.error_outline_rounded : Icons.check_circle_outline,
            size: 22,
            color: tooLarge ? AppColors.danger : AppColors.brandGreenDeep,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  tooLarge
                      ? '$size · exceeds the $limitLabel limit'
                      : '$size · $readyLabel',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: tooLarge ? AppColors.danger : AppColors.textBody,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onRemove,
            icon: const Icon(Icons.close_rounded, size: 20),
            color: AppColors.textMuted,
            tooltip: removeLabel,
          ),
        ],
      ),
    );
  }
}
