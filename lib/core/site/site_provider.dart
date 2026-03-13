import 'package:flutter/material.dart';
import 'site_model.dart';

class SiteProvider extends ChangeNotifier {
  String? _selectedSiteId = SiteId.all;
  String? get selectedSiteId => _selectedSiteId;
  void setSelectedSite(String? value) {
    if (value != _selectedSiteId) {
      _selectedSiteId = value ?? SiteId.all;
      notifyListeners();
    }
  }
}
