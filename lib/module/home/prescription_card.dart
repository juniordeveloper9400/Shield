import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

/// Upload-a-prescription card with the call-to-order row beneath it.
class PrescriptionCard extends StatelessWidget {
  const PrescriptionCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF4E8),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFF3D9BC)),
                  ),
                  child: const Icon(
                    Icons.assignment_outlined,
                    size: 24,
                    color: Color(0xFFE07B39),
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Add a prescription',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textDark,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'to place your order',
                        style: TextStyle(
                          fontSize: 13.5,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.file_upload_outlined, size: 19),
                  label: const Text(
                    'Upload',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.brandBlue,
                    side: const BorderSide(color: AppColors.brandBlue),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Row(
              children: [
                const Expanded(
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: 'Or call us to order on ',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textBody,
                          ),
                        ),
                        TextSpan(
                          text: '09240250346',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Material(
                  color: AppColors.white,
                  shape: RoundedRectangleBorder(
                    side: const BorderSide(color: AppColors.brandBlue),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: InkWell(
                    onTap: () {},
                    borderRadius: BorderRadius.circular(10),
                    child: const SizedBox(
                      width: 46,
                      height: 42,
                      child: Icon(
                        Icons.phone_in_talk_outlined,
                        size: 21,
                        color: AppColors.brandBlue,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
