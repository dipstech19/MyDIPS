import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/auth/auth_provider.dart';
import 'core/auth/login_page.dart';
import 'layout/main_layout.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => AuthProvider(),
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
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF1565C0)),
        useMaterial3: true,
      ),
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