import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/auth/auth_provider.dart';
import 'core/auth/login_page.dart';
import 'core/locale/app_locale.dart';
import 'core/site/site_provider.dart';
import 'core/theme/app_theme.dart' as theme;
import 'core/notifications/local_notifications_service.dart';
import 'core/notifications/ops_notifications_service.dart';
import 'core/notifications/push_notifications_service.dart';
import 'layout/main_layout.dart';
import 'modules/employees/employees_provider.dart';
import 'modules/employees/departements_provider.dart';
import 'modules/employees/postes_provider.dart';
import 'modules/groupes/groupes_provider.dart';
import 'modules/groupes/groupe_comptes_provider.dart';
import 'modules/distribution/distribution_groups_provider.dart';
import 'modules/distribution/distribution_shifts_provider.dart';
import 'modules/distribution/distribution_comptes_provider.dart';
import 'modules/distribution/distribution_swaps_provider.dart';
import 'modules/Paramètres/admins_provider.dart';
import 'modules/Paramètres/chauffeurs_provider.dart';
import 'modules/Paramètres/chef_comptes_provider.dart';
import 'modules/pointage/pointage_provider.dart';
import 'modules/pointage/absence_reasons_provider.dart';
import 'modules/shifts/shifts_provider.dart';
import 'modules/magasin/magasin_provider.dart';
import 'modules/employees/conges_provider.dart';
import 'modules/Demandes/leave_requests_provider.dart';
import 'modules/overtime/overtime_provider.dart';
import 'core/firebase_bootstrap.dart';
import 'firebase_options.dart';

/// Android/iOS: prefer native config from `google-services.json` / `GoogleService-Info.plist`
/// (avoids subtle mismatches with Dart [FirebaseOptions] in release). Fallback to explicit options.
Future<void> configureFirebaseForApp() async {
  firebaseBootstrapLastError = null;
  if (kIsWeb) {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.web);
    return;
  }
  switch (defaultTargetPlatform) {
    case TargetPlatform.android:
      try {
        await Firebase.initializeApp();
        return;
      } catch (e, st) {
        debugPrint('Firebase Android native init failed, trying explicit options: $e\n$st');
      }
      await Firebase.initializeApp(options: DefaultFirebaseOptions.android);
      return;
    case TargetPlatform.iOS:
      try {
        await Firebase.initializeApp();
        return;
      } catch (e, st) {
        debugPrint('Firebase iOS native init failed, trying explicit options: $e\n$st');
      }
      await Firebase.initializeApp(options: DefaultFirebaseOptions.ios);
      return;
    default:
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
      return;
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final rootScaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();
  try {
    await configureFirebaseForApp();
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
  } catch (e, st) {
    firebaseBootstrapLastError = e.toString();
    debugPrint('Firebase init error: $e\n$st');
  }
  await LocalNotificationsService.instance.initialize();
  await PushNotificationsService.instance.initialize(
    scaffoldMessengerKey: rootScaffoldMessengerKey,
  );
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
        ChangeNotifierProvider(create: (_) => DistributionShiftsProvider()),
        ChangeNotifierProvider(create: (_) => DistributionComptesProvider()),
        ChangeNotifierProvider(create: (_) => DistributionSwapsProvider()),
        ChangeNotifierProvider(create: (_) => AdminsProvider()),
        ChangeNotifierProvider(create: (_) => ChauffeursProvider()),
        ChangeNotifierProvider(create: (_) => ChefComptesProvider()),
        ChangeNotifierProvider(create: (_) => PointageProvider()),
        ChangeNotifierProvider(create: (_) => AbsenceReasonsProvider()),
        ChangeNotifierProvider(create: (_) => ShiftsProvider()),
        ChangeNotifierProvider(create: (_) => MagasinProvider()..init()),
        ChangeNotifierProvider(create: (_) => CongesProvider()),
        ChangeNotifierProvider(create: (_) => LeaveRequestsProvider()),
        ChangeNotifierProvider(create: (_) => OvertimeProvider()),
      ],
      child: MyApp(scaffoldMessengerKey: rootScaffoldMessengerKey),
    ),
  );
}

class MyApp extends StatelessWidget {
  final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey;
  const MyApp({super.key, required this.scaffoldMessengerKey});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'My DIPS',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: scaffoldMessengerKey,
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

class _AppRoot extends StatefulWidget {
  const _AppRoot();

  @override
  State<_AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<_AppRoot> {
  String? _lastBoundUserId;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final currentId = auth.currentUser?.id;
    if (_lastBoundUserId != currentId) {
      _lastBoundUserId = currentId;
      unawaited(PushNotificationsService.instance.bindUser(auth.currentUser));
      unawaited(OpsNotificationsService.instance.bindUser(auth.currentUser));
    }
    return auth.isLoggedIn ? const MainLayout() : const LoginPage();
  }
}