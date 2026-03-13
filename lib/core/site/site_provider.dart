import 'package:flutter/material.dart';
import 'site_model.dart';

/// فلتر الموقع للأدمن العام: الكل / الجديدة / آسفي
class SiteProvider extends ChangeNotifier {
  /// عند null أو "all" = عرض الكل؛ "jadida" أو "safi" = عرض الموقع فقط
  String? _selectedSiteId = SiteId.all;

  String? get selectedSiteId => _selectedSiteId;

  void setSelectedSite(String? siteId) {
    if (_selectedSiteId == siteId) return;
    _selectedSiteId = siteId ?? SiteId.all;
    notifyListeners();
  }
}
