import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../utils/responsive.dart';
import 'auth_provider.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscure = true;
  String? _error;

  void _login() {
    final auth = context.read<AuthProvider>();
    final ok = auth.login(_usernameCtrl.text.trim(), _passwordCtrl.text);
    if (!ok) {
      setState(() => _error = 'Nom d\'utilisateur ou mot de passe incorrect');
    }
  }

  @override
  Widget build(BuildContext context) {
    final mobile = isMobile(context);
    final padding = pagePadding(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: mobile ? _buildMobileLayout(padding) : _buildDesktopLayout(padding),
    );
  }

  Widget _buildMobileLayout(double padding) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: padding, vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Logo compact en haut
            Padding(
              padding: const EdgeInsets.only(top: 24, bottom: 20),
              child: Column(
                children: [
                  Icon(Icons.business, color: const Color(0xFF1565C0), size: 52),
                  const SizedBox(height: 10),
                  const Text('DIPS', style: TextStyle(color: Color(0xFF1565C0), fontSize: 28, fontWeight: FontWeight.bold)),
                  Text('Système de Gestion', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                ],
              ),
            ),
            _loginForm(20, true),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopLayout(double padding) {
    return Row(
      children: [
        Expanded(
          child: Container(
            color: const Color(0xFF1565C0),
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.business, color: Colors.white, size: 80),
                SizedBox(height: 20),
                Text('DIPS', style: TextStyle(color: Colors.white, fontSize: 48, fontWeight: FontWeight.bold)),
                SizedBox(height: 8),
                Text('Système de Gestion', style: TextStyle(color: Colors.white70, fontSize: 18)),
                SizedBox(height: 40),
                _FeatureItem(icon: Icons.people, text: 'Gestion des Employés'),
                _FeatureItem(icon: Icons.access_time, text: 'Pointage'),
                _FeatureItem(icon: Icons.inventory_2, text: 'Stock'),
                _FeatureItem(icon: Icons.bar_chart, text: 'Rapports'),
              ],
            ),
          ),
        ),
        Expanded(
          child: Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(padding),
              child: Container(
                width: 400,
                padding: const EdgeInsets.all(40),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 30, offset: const Offset(0, 10)),
                  ],
                ),
                child: _loginForm(0, false),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _loginForm(double cardPadding, bool isMobile) {
    final titleSize = isMobile ? 22.0 : 28.0;
    final spacing = isMobile ? 20.0 : 32.0;
    final fieldSpacing = isMobile ? 12.0 : 16.0;

    Widget form = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Bienvenue', style: TextStyle(fontSize: titleSize, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text('Connectez-vous à votre compte', style: TextStyle(color: Colors.grey[600], fontSize: isMobile ? 13 : 14)),
        SizedBox(height: spacing),

        Text('Nom d\'utilisateur', style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
        const SizedBox(height: 8),
        TextField(
          controller: _usernameCtrl,
          decoration: InputDecoration(
            hintText: 'admin',
            prefixIcon: const Icon(Icons.person_outline),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            filled: true,
            fillColor: Colors.grey.shade50,
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: isMobile ? 12 : 14),
          ),
          onSubmitted: (_) => _login(),
        ),
        SizedBox(height: fieldSpacing),

        Text('Mot de passe', style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
        const SizedBox(height: 8),
        TextField(
          controller: _passwordCtrl,
          obscureText: _obscure,
          decoration: InputDecoration(
            hintText: '••••••',
            prefixIcon: const Icon(Icons.lock_outline),
            suffixIcon: IconButton(
              icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
              onPressed: () => setState(() => _obscure = !_obscure),
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            filled: true,
            fillColor: Colors.grey.shade50,
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: isMobile ? 12 : 14),
          ),
          onSubmitted: (_) => _login(),
        ),

        if (_error != null) ...[
          SizedBox(height: fieldSpacing),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red.shade200),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 18),
                const SizedBox(width: 8),
                Expanded(child: Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13))),
              ],
            ),
          ),
        ],

        SizedBox(height: isMobile ? 20 : 24),

        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _login,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1565C0),
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(vertical: isMobile ? 14 : 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            child: Text('Se connecter', style: TextStyle(fontSize: isMobile ? 15 : 16, fontWeight: FontWeight.w600)),
          ),
        ),

        SizedBox(height: isMobile ? 16 : 20),

        Container(
          padding: EdgeInsets.all(isMobile ? 10 : 12),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Comptes de test:', style: TextStyle(color: Colors.blue.shade700, fontWeight: FontWeight.bold, fontSize: 12)),
              const SizedBox(height: 4),
              Text('admin / 1234  →  Directeur', style: TextStyle(color: Colors.blue.shade600, fontSize: 12)),
              Text('fatima / 1234  →  Chef Équipe', style: TextStyle(color: Colors.blue.shade600, fontSize: 12)),
            ],
          ),
        ),
      ],
    );

    if (cardPadding > 0) {
      return Container(
        width: double.infinity,
        padding: EdgeInsets.all(cardPadding),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 20, offset: const Offset(0, 6)),
          ],
        ),
        child: form,
      );
    }
    return form;
  }
}

class _FeatureItem extends StatelessWidget {
  final IconData icon;
  final String text;
  const _FeatureItem({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white70, size: 20),
          const SizedBox(width: 10),
          Text(text, style: const TextStyle(color: Colors.white70, fontSize: 15)),
        ],
      ),
    );
  }
}