import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
<<<<<<< HEAD
=======
import 'core/auth/auth_provider.dart';
import 'core/auth/login_page.dart';
>>>>>>> d4f0996 (Add auth module, employees module with models and widgets)
import 'layout/main_layout.dart';
import 'core/auth/auth_provider.dart';
import 'core/locale/app_locale.dart';
import 'modules/employees/employees_provider.dart';

void main() {
  runApp(
<<<<<<< HEAD
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => LocaleProvider()),
        ChangeNotifierProvider(create: (_) => EmployeesProvider()),
      ],
=======
    ChangeNotifierProvider(
      create: (_) => AuthProvider(),
>>>>>>> d4f0996 (Add auth module, employees module with models and widgets)
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
<<<<<<< HEAD
      title: 'Système de gestion DIPS',
=======
      title: 'DIPS - Système de Gestion',
>>>>>>> d4f0996 (Add auth module, employees module with models and widgets)
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF1565C0)),
        useMaterial3: true,
      ),
<<<<<<< HEAD
      home: const MainLayout(), // ← ligne manquante → écran noir sans elle
=======
      home: const _AppRoot(),
>>>>>>> d4f0996 (Add auth module, employees module with models and widgets)
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