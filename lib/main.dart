import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/auth/auth_provider.dart';
import 'core/auth/login_page.dart';
import 'core/locale/app_locale.dart';
import 'core/site/site_model.dart';
import 'core/site/site_provider.dart';
import 'core/theme/app_theme.dart' as theme;
import 'core/utils/responsive.dart';
import 'layout/main_layout.dart';
import 'modules/employees/employees_provider.dart';
import 'modules/employees/departements_provider.dart';
import 'modules/employees/postes_provider.dart';
import 'modules/groupes/groupes_provider.dart';
import 'modules/groupes/groupe_comptes_provider.dart';
import 'modules/distribution/distribution_groups_provider.dart';
import 'modules/distribution/distribution_comptes_provider.dart';
import 'modules/Paramètres/admins_provider.dart';
import 'modules/Paramètres/chauffeurs_provider.dart';
import 'modules/Paramètres/chef_comptes_provider.dart';
import 'modules/pointage/pointage_provider.dart';
import 'modules/pointage/absence_reasons_provider.dart';
import 'modules/shifts/shifts_provider.dart';
import 'modules/magasin/magasin_provider.dart';
import 'modules/employees/conges_provider.dart';
import 'modules/overtime/overtime_provider.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    // Firestore — résilience (réseau lent / coupures):
    // - Persistance disque: moins de re-téléchargements; lectures possibles depuis le cache si déjà chargées.
    // - Les écritures sont mises en file d’attente hors ligne puis envoyées au retour du réseau (SDK).
    // - Ne pas multiplier les requêtes: regrouper en WriteBatch côté repository quand c’est pertinent.
    try {
      FirebaseFirestore.instance.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      );
    } catch (e) {
      debugPrint('Firestore settings: $e');
    }
  } catch (e) {
    debugPrint('Firebase init error: $e');
  }
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => SiteProvider()),
        ChangeNotifierProvider(create: (_) => LocaleProvider()),
        ChangeNotifierProvider(create: (_) => EmployeesProvider()),
        ChangeNotifierProvider(create: (_) => DepartementsProvider()),
        ChangeNotifierProvider(create: (_) => PostesProvider()),
        ChangeNotifierProvider(create: (_) => GroupesProvider()),
        ChangeNotifierProvider(create: (_) => GroupeComptesProvider()),
        ChangeNotifierProvider(create: (_) => DistributionGroupsProvider()),
        ChangeNotifierProvider(create: (_) => DistributionComptesProvider()),
        ChangeNotifierProvider(create: (_) => AdminsProvider()),
        ChangeNotifierProvider(create: (_) => ChauffeursProvider()),
        ChangeNotifierProvider(create: (_) => ChefComptesProvider()),
        ChangeNotifierProvider(create: (_) => PointageProvider()),
        ChangeNotifierProvider(create: (_) => AbsenceReasonsProvider()),
        ChangeNotifierProvider(create: (_) => ShiftsProvider()),
        ChangeNotifierProvider(create: (_) => MagasinProvider()..init()),
        ChangeNotifierProvider(create: (_) => CongesProvider()),
        ChangeNotifierProvider(create: (_) => OvertimeProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DIPS - Système de Gestion',
      debugShowCheckedModeBanner: false,
      theme: theme.appTheme,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: theme.textScaler(context),
          ),
          child: child!,
        );
      },
      home: const _AppRoot(),
    );
  }
}

class _AppRoot extends StatelessWidget {
  const _AppRoot();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    // إذا مدخلش → Login, إذا دخل → التطبيق
    return auth.isLoggedIn ? const MainLayout() : const LoginPage();
  }
}