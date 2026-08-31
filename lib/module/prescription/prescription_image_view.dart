import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

/// A full-screen look at the prescription image the member has just picked,
/// before it is filed.
///
/// The upload card can show a name and a size and a thumbnail, but none of
/// those answer "is this page readable" — so the card opens this, where the
/// picture fills the screen and pinch-zoom brings the small print up close.
class PrescriptionImageView extends StatelessWidget {
  final Uint8List bytes;

  /// The file's name, shown in the bar so the member knows which upload they
  /// are looking at when more than one has been added.
  final String name;

  const PrescriptionImageView({
    super.key,
    required this.bytes,
    required this.name,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        surfaceTintColor: Colors.black,
        foregroundColor: AppColors.white,
        elevation: 0,
        title: Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.white,
          ),
        ),
      ),
      body: Center(
        child: InteractiveViewer(
          maxScale: 5,
          child: Image.memory(
            bytes,
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => const Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'This image could not be shown.',
                style: TextStyle(color: AppColors.white, fontSize: 14),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
