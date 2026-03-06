import 'package:flutter/material.dart';

String tr(BuildContext context, String key) {
  // Simule une traduction de base
  final translations = {
    'nav_dashboard': 'Tableau de bord',
    'nav_employees': 'Employés',
    'nav_pointage': 'Pointage',
    'nav_stock': 'Magasin',
    'nav_rapports': 'Rapports',
    'nav_settings': 'Paramètres',
    'nav_send_report': 'Envoyer rapport',
    'role_directeur': 'Directeur',
    'role_chauffeur': 'Chauffeur',
    'role_chef_equipe': 'Chef d\'équipe',
    'logout': 'Déconnexion',
    'logout_confirm': 'Voulez-vous vraiment vous déconnecter ?',
    'cancel': 'Annuler',
    'disconnect': 'Se déconnecter',
    'french': 'Français',
    'arabic': 'العربية',
  };
  return translations[key] ?? key;
}

class LocaleProvider extends ChangeNotifier {
  String _locale = 'fr';
  String get locale => _locale;

  void setLocale(String l) {
    _locale = l;
    notifyListeners();
  }
}
