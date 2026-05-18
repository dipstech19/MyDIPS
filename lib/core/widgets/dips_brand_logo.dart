import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Logo entreprise (`assets/images/logo.png`) — connexion et barre latérale.
class DipsBrandLogo extends StatelessWidget {
  const DipsBrandLogo({
    super.key,
    this.height = 56,
    this.width,
    this.fit = BoxFit.contain,
    this.alignment = Alignment.center,
  });

  final double height;
  final double? width;
  final BoxFit fit;
  final AlignmentGeometry alignment;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/logo.png',
      height: height,
      width: width,
      fit: fit,
      alignment: alignment,
      errorBuilder: (context, error, stackTrace) => _fallback(height),
    );
  }

  static Widget _fallback(double h) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.business, color: AppColors.brand, size: h * 0.85),
        const SizedBox(height: 4),
        Text(
          'DIPS',
          style: TextStyle(
            color: AppColors.brand,
            fontSize: (h * 0.45).clamp(14, 28),
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
