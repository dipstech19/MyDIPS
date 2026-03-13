/// معرفات المواقع (المراكز): الجديدة، آسفي
class SiteId {
  static const String jadida = 'jadida';
  static const String safi = 'safi';
  static const String all = 'all';

  static const List<String> values = [jadida, safi];

  static String label(String siteId) {
    switch (siteId) {
      case jadida:
        return 'الجديدة';
      case safi:
        return 'آسفي';
      case all:
        return 'الكل';
      default:
        return siteId;
    }
  }

  static String labelFr(String siteId) {
    switch (siteId) {
      case jadida:
        return 'El Jadida';
      case safi:
        return 'Safi';
      case all:
        return 'Tous';
      default:
        return siteId;
    }
  }

  /// فلترة قائمة حسب الموقع: allowedSiteIds للمشرف، selectedSiteId للأدمن العام
  static List<T> filterBySite<T>(
    List<T> list,
    List<String>? allowedSiteIds,
    String? selectedSiteId,
    String Function(T) getSiteId,
  ) {
    if (allowedSiteIds != null && allowedSiteIds.isNotEmpty && !allowedSiteIds.contains(all)) {
      return list.where((e) => allowedSiteIds.contains(getSiteId(e))).toList();
    }
    if (selectedSiteId != null && selectedSiteId != all) {
      return list.where((e) => getSiteId(e) == selectedSiteId).toList();
    }
    return list;
  }
}
