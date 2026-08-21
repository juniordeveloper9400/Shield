import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Unified image widget that seamlessly renders either a remote URL
/// (http/https) or a local asset path, with loading indicators and graceful
/// fallback to an icon.
class AppImage extends StatelessWidget {
  final String? image;
  final IconData? fallbackIcon;
  final double? iconSize;
  final Color? iconColor;
  final BoxFit fit;
  final Alignment alignment;
  final double? width;
  final double? height;

  const AppImage({
    super.key,
    required this.image,
    this.fallbackIcon,
    this.iconSize,
    this.iconColor,
    this.fit = BoxFit.contain,
    this.alignment = Alignment.center,
    this.width,
    this.height,
  });

  static bool isNetwork(String? path) {
    if (path == null) return false;
    final trimmed = path.trim().toLowerCase();
    return trimmed.startsWith('http://') || trimmed.startsWith('https://');
  }

  @override
  Widget build(BuildContext context) {
    final imagePath = image?.trim();
    if (imagePath == null || imagePath.isEmpty) {
      return _buildFallback();
    }

    if (isNetwork(imagePath)) {
      return Image.network(
        imagePath,
        width: width,
        height: height,
        fit: fit,
        alignment: alignment,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Center(
            child: SizedBox(
              width: (iconSize ?? 24) * 0.7,
              height: (iconSize ?? 24) * 0.7,
              child: const CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.brandBlue,
              ),
            ),
          );
        },
        errorBuilder: (_, _, _) => _buildFallback(),
      );
    }

    return Image.asset(
      imagePath,
      width: width,
      height: height,
      fit: fit,
      alignment: alignment,
      errorBuilder: (_, _, _) => _buildFallback(),
    );
  }

  Widget _buildFallback() {
    if (fallbackIcon != null) {
      return Icon(
        fallbackIcon,
        size: iconSize,
        color: iconColor ?? AppColors.brandBlue,
      );
    }
    return const SizedBox.shrink();
  }
}
