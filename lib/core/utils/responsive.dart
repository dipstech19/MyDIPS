import 'package:flutter/material.dart';

bool isMobile(BuildContext context) => MediaQuery.of(context).size.width < 850;

bool isTablet(BuildContext context) =>
    MediaQuery.of(context).size.width >= 850 &&
    MediaQuery.of(context).size.width < 1100;

bool isDesktop(BuildContext context) =>
    MediaQuery.of(context).size.width >= 1100;

double pagePadding(BuildContext context) {
  if (isMobile(context)) return 16.0;
  if (isTablet(context)) return 24.0;
  return 32.0;
}
