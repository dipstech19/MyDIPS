import 'dart:math' as math;

import 'package:flutter/material.dart';

/// عتبات الشاشة
/// Mobile: < 600px | Tablet: 600–900px | Desktop: > 900px
double screenWidth(BuildContext context) =>
    MediaQuery.sizeOf(context).width;

double screenHeight(BuildContext context) =>
    MediaQuery.sizeOf(context).height;

bool isMobile(BuildContext context) =>
    screenWidth(context) < 600;

bool isTablet(BuildContext context) {
  final w = screenWidth(context);
  return w >= 600 && w < 900;
}

bool isDesktop(BuildContext context) =>
    screenWidth(context) >= 900;

bool isDesktopOrTablet(BuildContext context) =>
    !isMobile(context);

/// هامش الصفحة حسب العرض
double pagePadding(BuildContext context) =>
    isMobile(context) ? 12 : (isTablet(context) ? 20 : 24);

/// أقصى عرض للمحتوى على الشاشات الكبيرة (لتوسيط وقراءة أفضل)
double maxContentWidth(BuildContext context) =>
    isMobile(context) ? double.infinity : 1200;

/// حجم خط العنوان
double titleFontSize(BuildContext context) =>
    isMobile(context) ? 20 : (isTablet(context) ? 24 : 26);

/// حجم خط ثانوي
double subtitleFontSize(BuildContext context) =>
    isMobile(context) ? 12 : 13;

/// أقصى عرض للنوافذ المنبثقة (يتكيف مع الهاتف)
double dialogMaxWidth(BuildContext context) =>
    math.min(900, screenWidth(context) - 32);

/// هامش النوافذ المنبثقة (أقل على الهاتف)
double dialogMargin(BuildContext context) =>
    isMobile(context) ? 16 : 28;

/// أقصى ارتفاع للنوافذ المنبثقة (لتجنب القص على الهاتف)
double dialogMaxHeight(BuildContext context) =>
    screenHeight(context) * 0.9;

/// تكبير النص المحكم (يدعم إعدادات الجهاز مع حدود معقولة)
TextScaler textScaler(BuildContext context) =>
    MediaQuery.textScalerOf(context).clamp(
      minScaleFactor: 0.85,
      maxScaleFactor: 1.35,
    );
