import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/auth/auth_provider.dart';
import 'core/auth/login_page.dart';
import 'core/locale/app_locale.dart';
import 'core/theme/app_theme.dart';
import 'core/utils/responsive.dart';
import 'layout/main_layout.dart';
import 'modules/employees/employees_provider.dart';
import 'modules/employees/postes_provider.dart';
import 'modules/Paramètres/admins_provider.dart';
import 'modules/Paramètres/chauffeurs_provider.dart';
import 'modules/Paramètres/chef_comptes_provider.dart';
import 'modules/pointage/pointage_provider.dart';
import 'modules/magasin/magasin_provider.dart';
import 'modules/employees/conges_provider.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('Firebase init error: $e');
  }
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => LocaleProvider()),
        ChangeNotifierProvider(create: (_) => EmployeesProvider()),
        ChangeNotifierProvider(create: (_) => PostesProvider()),
        ChangeNotifierProvider(create: (_) => AdminsProvider()),
        ChangeNotifierProvider(create: (_) => ChauffeursProvider()),
        ChangeNotifierProvider(create: (_) => ChefComptesProvider()),
        ChangeNotifierProvider(create: (_) => PointageProvider()),
        ChangeNotifierProvider(create: (_) => MagasinProvider()),
        ChangeNotifierProvider(create: (_) => CongesProvider()),
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
      theme: appTheme,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: textScaler(context),
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