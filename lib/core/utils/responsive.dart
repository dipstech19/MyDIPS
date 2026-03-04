import 'package:flutter/material.dart';

/// عتبة الهاتف: أقل من 600px = هاتف
bool isMobile(BuildContext context) {
  return MediaQuery.sizeOf(context).width < 600;
}

bool isDesktopOrTablet(BuildContext context) {
  return !isMobile(context);
}

/// هامش مناسب حسب العرض
double pagePadding(BuildContext context) {
  return isMobile(context) ? 12 : 24;
}
