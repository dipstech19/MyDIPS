class AppPermissions {
  static const String all = '*';

  // Navigation/module permissions
  static const String employeesView = 'employees.view';
  static const String pointageView = 'pointage.view';
  static const String overtimeView = 'overtime.view';
  static const String shiftsView = 'shifts.view';
  static const String stockView = 'stock.view';
  static const String reportsView = 'reports.view';
  static const String settingsView = 'settings.view';
  static const String demandesView = 'demandes.view';
  static const String logistiqueView = 'logistique.view';

  // Employee management
  static const String employeesManage = 'employees.manage';
  static const String employeesDelete = 'employees.delete';
  static const String teamsManage = 'teams.manage';
  static const String groupsManage = 'groups.manage';

  // Detailed settings permissions
  static const String adminsManage = 'settings.admins.manage';
  static const String chefAccountsManage = 'settings.chef_accounts.manage';
  static const String groupeAccountsManage = 'settings.groupe_accounts.manage';
  static const String driversManage = 'settings.drivers.manage';
  static const String postesManage = 'settings.postes.manage';
  static const String departementsManage = 'settings.departements.manage';
  static const String absenceReasonsManage = 'settings.absence_reasons.manage';
  static const String generalManage = 'settings.general.manage';
  static const String notificationsManage = 'settings.notifications.manage';
  static const String securityManage = 'settings.security.manage';
  static const String databaseManage = 'settings.database.manage';
  static const String aboutView = 'settings.about.view';
  static const String trainingManage = 'settings.training.manage';

  static const Map<String, String> labelsFr = {
    employeesView: 'Voir module Employés',
    employeesManage: 'Gérer employés (ajout/modification)',
    employeesDelete: 'Supprimer employés',
    teamsManage: 'Gérer équipes',
    groupsManage: 'Gérer groupes',
    pointageView: 'Voir module Pointage',
    overtimeView: 'Voir module Heures Sup.',
    shiftsView: 'Voir module Shifts',
    stockView: 'Voir module Gestion Magasin',
    reportsView: 'Voir module Rapports',
    settingsView: 'Voir module Paramètres',
    demandesView: 'Voir module Demandes',
    logistiqueView: 'Voir module Logistique',
    adminsManage: 'Gérer administrateurs',
    chefAccountsManage: 'Gérer comptes chefs',
    groupeAccountsManage: 'Gérer comptes groupes',
    driversManage: 'Gérer chauffeurs',
    postesManage: 'Gérer postes',
    departementsManage: 'Gérer départements',
    absenceReasonsManage: 'Gérer raisons d\'absence',
    generalManage: 'Gérer paramètres généraux',
    notificationsManage: 'Gérer notifications',
    securityManage: 'Gérer sécurité',
    databaseManage: 'Gérer base de données',
    aboutView: 'Voir section À propos',
    trainingManage: 'Gérer formations',
  };

  static const List<String> allDetailed = [
    employeesView,
    employeesManage,
    employeesDelete,
    teamsManage,
    groupsManage,
    pointageView,
    overtimeView,
    shiftsView,
    stockView,
    reportsView,
    settingsView,
    demandesView,
    logistiqueView,
    adminsManage,
    chefAccountsManage,
    groupeAccountsManage,
    driversManage,
    postesManage,
    departementsManage,
    absenceReasonsManage,
    generalManage,
    notificationsManage,
    securityManage,
    databaseManage,
    aboutView,
    trainingManage,
  ];
}
