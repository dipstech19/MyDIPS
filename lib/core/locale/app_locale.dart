import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// اللغة: فرنسية (افتراضي) أو عربية
class LocaleProvider extends ChangeNotifier {
  String _locale = 'fr';
  String get locale => _locale;
  bool get isArabic => _locale == 'ar';

  void setLocale(String value) {
    if (value != _locale && (value == 'fr' || value == 'ar')) {
      _locale = value;
      notifyListeners();
    }
  }

  void toggleLocale() {
    _locale = _locale == 'fr' ? 'ar' : 'fr';
    notifyListeners();
  }
}

/// ترجمات التطبيق — فرنسية وعربية
class AppTranslations {
  static const Map<String, String> fr = {
    'app_title': 'DIPS - Système de Gestion',
    'nav_dashboard': 'Tableau de bord',
    'nav_employees': 'Employés',
    'nav_pointage': 'Pointage',
    'nav_stock': 'Stock',
    'nav_rapports': 'Rapports',
    'nav_settings': 'Paramètres',
    'nav_send_report': 'Envoyer rapport',
    'role_directeur': 'Directeur',
    'role_chef_equipe': 'Chef Équipe',
    'role_chauffeur': 'Chauffeur',
    'logout': 'Déconnexion',
    'logout_confirm': 'Voulez-vous vraiment vous déconnecter ?',
    'cancel': 'Annuler',
    'disconnect': 'Déconnecter',
    'pointage_title': 'Pointage — Présence quotidienne',
    'pointage_subtitle_chef': 'Choisissez l\'écran pour votre équipe',
    'pointage_subtitle_driver': 'Page chauffeur — Liste du jour',
    'pointage_subtitle_admin': 'Choisissez l\'écran selon votre rôle',
    'my_team': 'Mon équipe',
    'my_team_subtitle': 'Chef — Uniquement les travailleurs de votre équipe',
    'add_worker': 'Ajouter un travailleur',
    'add_worker_subtitle': 'Chef — Ajouter un travailleur d\'une autre équipe',
    'today_list': 'Liste du jour',
    'today_list_subtitle': 'Tous les équipes et travailleurs',
    'send_report_note': 'Envoyer un rapport ou une note',
    'send_report_note_subtitle': 'Envoyer à un chef d\'équipe ou au Super Admin',
    'no_pointage_options': 'Aucune option de pointage pour ce compte.',
    'chefs_side_title': 'Chefs d\'équipe',
    'select_chef': 'Sélectionnez un chef pour voir ses travailleurs',
    'workers_of': 'Travailleurs de',
    'present': 'Présent',
    'absent': 'Absent',
    'not_in_vehicle': 'Pas dans le véhicule',
    'not_in_vehicle_hint': 'Vient seul (voiture / vélo)',
    'send_report_btn': 'Envoyer le rapport',
    'report_sent': 'Rapport envoyé',
    'report_sent_to': 'Rapport envoyé à',
    'no_teams': 'Aucune équipe',
    'no_workers': 'Aucun travailleur dans cette équipe',
    'report_page_title': 'Envoyer un rapport ou une note',
    'report_content': 'Contenu :',
    'report_content_hint': 'Écrivez le rapport ou la note...',
    'report_send_to': 'Envoyer à :',
    'report_super_admin': 'Super Admin',
    'report_specific_chef': 'Chef d\'équipe spécifique',
    'report_choose_chef': 'Choisir le chef',
    'report_send': 'Envoyer',
    'report_write_first': 'Veuillez écrire le rapport ou la note d\'abord.',
    'badge_chef': 'Chef Équipe',
    'badge_driver': 'Chauffeur',
    'section_team_workers': 'Travailleurs de l\'équipe',
    'section_by_chef': 'Équipe par chef',
    'search_name_cin': 'Recherche par nom ou CIN...',
    'other_teams_info': 'Travailleurs d\'autres équipes — vous pouvez les ajouter à la vôtre',
    'added': 'Ajouté',
    'add': 'Ajouter',
    'cin_label': 'CIN',
    'chef_label': 'Chef',
    'language': 'Langue',
    'arabic': 'العربية',
    'french': 'Français',
    'report_presence_title': 'Rapport de présence',
    'report_presents': 'Présents',
    'report_absents': 'Absents',
    'report_not_in_vehicle_list': 'Pas dans le véhicule (liste chauffeur)',
    'report_by_chef': 'Par chef d\'équipe',
    'report_no_data': 'Aucune donnée',
  };

  static const Map<String, String> ar = {
    'app_title': 'DIPS - نظام الإدارة',
    'nav_dashboard': 'لوحة التحكم',
    'nav_employees': 'الموظفون',
    'nav_pointage': 'الحضور',
    'nav_stock': 'المخزون',
    'nav_rapports': 'التقارير',
    'nav_settings': 'الإعدادات',
    'nav_send_report': 'إرسال تقرير',
    'role_directeur': 'المدير',
    'role_chef_equipe': 'شاف دكيب',
    'role_chauffeur': 'سائق',
    'logout': 'تسجيل الخروج',
    'logout_confirm': 'هل تريد فعلاً تسجيل الخروج؟',
    'cancel': 'إلغاء',
    'disconnect': 'تسجيل الخروج',
    'pointage_title': 'Pointage — الحضور اليومي',
    'pointage_subtitle_chef': 'اختر الشاشة المناسبة لفريقك',
    'pointage_subtitle_driver': 'صفحة خاصة بالسائق — قائمة اليوم',
    'pointage_subtitle_admin': 'اختر الشاشة المناسبة لدورك',
    'my_team': 'فريقي',
    'my_team_subtitle': 'Chef — عمال فريقك فقط',
    'add_worker': 'إضافة عامل',
    'add_worker_subtitle': 'Chef — إضافة عامل من فريق آخر',
    'today_list': 'قائمة اليوم',
    'today_list_subtitle': 'كل الفرق والعمال',
    'send_report_note': 'إرسال تقرير أو ملاحظة',
    'send_report_note_subtitle': 'إرسال إلى شاف دكيب محدد أو السوبر أدمن',
    'no_pointage_options': 'لا توجد خيارات pointage لهذا الحساب.',
    'chefs_side_title': 'شافات الدكيب',
    'select_chef': 'اختر شافاً لعرض عماله',
    'workers_of': 'عمال',
    'present': 'حاضر',
    'absent': 'غائب',
    'not_in_vehicle': 'ليس ضمن الركاب',
    'not_in_vehicle_hint': 'يأتي لوحده (سيارة / دراجة)',
    'send_report_btn': 'إرسال التقرير',
    'report_sent': 'تم إرسال التقرير',
    'report_sent_to': 'تم إرسال التقرير إلى',
    'no_teams': 'لا توجد فرق',
    'no_workers': 'لا يوجد عمال في هذا الفريق',
    'report_page_title': 'إرسال تقرير أو ملاحظة',
    'report_content': 'المحتوى:',
    'report_content_hint': 'اكتب التقرير أو الملاحظة...',
    'report_send_to': 'إرسال إلى:',
    'report_super_admin': 'السوبر أدمن',
    'report_specific_chef': 'شاف دكيب محدد',
    'report_choose_chef': 'اختر الشاف',
    'report_send': 'إرسال',
    'report_write_first': 'اكتب التقرير أو الملاحظة أولاً.',
    'badge_chef': 'شاف دكيب',
    'badge_driver': 'شوفير',
    'section_team_workers': 'عمال الفريق',
    'section_by_chef': 'الفريق حسب الشاف',
    'search_name_cin': 'بحث بالاسم أو CIN...',
    'other_teams_info': 'عمال من فرق أخرى — يمكنك إضافتهم لفريقك',
    'added': 'مضاف',
    'add': 'إضافة',
    'cin_label': 'CIN',
    'chef_label': 'شاف',
    'language': 'اللغة',
    'arabic': 'العربية',
    'french': 'Français',
    'report_presence_title': 'تقرير الحضور',
    'report_presents': 'حاضرون',
    'report_absents': 'غائبون',
    'report_not_in_vehicle_list': 'ليس ضمن الركاب (قائمة السائق)',
    'report_by_chef': 'حسب الشاف',
    'report_no_data': 'لا توجد بيانات',
  };

  static String get(String locale, String key) {
    final map = locale == 'ar' ? ar : fr;
    return map[key] ?? key;
  }
}

/// استدعاء الترجمة حسب locale الحالي (يُستخدم مع Provider)
String tr(BuildContext context, String key) {
  final locale = context.watch<LocaleProvider>().locale;
  return AppTranslations.get(locale, key);
}