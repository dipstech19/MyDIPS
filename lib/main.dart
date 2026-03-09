import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'layout/main_layout.dart';
import 'core/auth/auth_provider.dart';
import 'core/locale/app_locale.dart';
import 'modules/employees/employees_provider.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => LocaleProvider()),
        ChangeNotifierProvider(create: (_) => EmployeesProvider()),
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
      title: 'Système de gestion DIPS',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1565C0),
        ),
        useMaterial3: true,
      ),
      home: const MainLayout(), // ← ligne manquante → écran noir sans elle
    );
  }
}