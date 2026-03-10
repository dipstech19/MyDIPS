import 'dart:io';
import 'package:flutter/material.dart';

/// A smart avatar widget that handles both network URLs and local file paths
class SmartAvatar extends StatelessWidget {
  final String? imageUrl;
  final String fallbackText;
  final double radius;
  final Color? backgroundColor;
  final Color? textColor;

  const SmartAvatar({
    super.key,
    this.imageUrl,
    required this.fallbackText,
    this.radius = 20,
    this.backgroundColor,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = backgroundColor ?? const Color(0xFF1565C0).withOpacity(0.15);
    final txtColor = textColor ?? const Color(0xFF1565C0);
    
    // Check if we have a valid image URL
    if (imageUrl == null || imageUrl!.isEmpty) {
      return _buildFallbackAvatar(bgColor, txtColor);
    }
    
    final url = imageUrl!;
    
    // Check if it's a network URL (starts with http:// or https://)
    if (url.startsWith('http://') || url.startsWith('https://')) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: bgColor,
        backgroundImage: NetworkImage(url),
        onBackgroundImageError: (_, __) {},
        child: null,
      );
    }
    
    // Check if it's a local file path
    if (_isLocalFilePath(url)) {
      final file = File(url);
      if (file.existsSync()) {
        return CircleAvatar(
          radius: radius,
          backgroundColor: bgColor,
          backgroundImage: FileImage(file),
          onBackgroundImageError: (_, __) {},
        );
      }
    }
    
    // Fallback to text avatar
    return _buildFallbackAvatar(bgColor, txtColor);
  }
  
  bool _isLocalFilePath(String path) {
    // Windows paths
    if (path.contains(':\\') || path.contains(':/')) return true;
    // Unix/Mac paths
    if (path.startsWith('/')) return true;
    return false;
  }
  
  Widget _buildFallbackAvatar(Color bgColor, Color txtColor) {
    final initial = fallbackText.isNotEmpty ? fallbackText[0].toUpperCase() : '?';
    return CircleAvatar(
      radius: radius,
      backgroundColor: bgColor,
      child: Text(
        initial,
        style: TextStyle(
          color: txtColor,
          fontWeight: FontWeight.bold,
          fontSize: radius * 0.8,
        ),
      ),
    );
  }
}
