import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/auth/auth_provider.dart';
import '../modules/Paramètres/paramètres.dart';
import '../modules/employees/employees_page.dart';
import '../modules/magasin/gestion_magasin.dart';

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _selectedIndex = 0;

  final List<_NavItem> _navItems = [
    _NavItem(icon: Icons.dashboard, label: 'Tableau de bord'),
    _NavItem(icon: Icons.people, label: 'Employés'),
    _NavItem(icon: Icons.access_time, label: 'Pointage'),
    _NavItem(icon: Icons.inventory_2, label: 'Gestion Magasin'),
    _NavItem(icon: Icons.bar_chart, label: 'Rapports'),
    _NavItem(icon: Icons.settings, label: 'Paramètres'),
  ];

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      body: Row(
        children: [
          // ===== SIDEBAR =====
          Container(
            width: 220,
            color: const Color(0xFF328EEE),
            child: Column(
              children: [
                // LOGO
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: const Column(
                    children: [
                      Icon(Icons.business, color: Colors.white, size: 44),
                      SizedBox(height: 8),
                      Text('DIPS',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold)),
                      Text('Système de Gestion',
                          style: TextStyle(color: Colors.white70, fontSize: 11)),
                    ],
                  ),
                ),
                const Divider(color: Colors.white24),

                // NAV ITEMS
                Expanded(
                  child: ListView.builder(
                    itemCount: _navItems.length,
                    itemBuilder: (context, index) {
                      final item = _navItems[index];
                      final isSelected = _selectedIndex == index;
                      return Container(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Colors.white.withOpacity(0.2)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: ListTile(
                          leading: Icon(item.icon,
                              color: isSelected
                                  ? Colors.white
                                  : Colors.white70),
                          title: Text(item.label,
                              style: TextStyle(
                                color: isSelected
                                    ? Colors.white
                                    : Colors.white70,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              )),
                          onTap: () =>
                              setState(() => _selectedIndex = index),
                        ),
                      );
                    },
                  ),
                ),

                const Divider(color: Colors.white24),

                // ===== USER INFO + LOGOUT =====
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(children: [
                          // Avatar
                          CircleAvatar(
                            radius: 16,
                            backgroundColor:
                            Colors.white.withOpacity(0.2),
                            child: Text(
                              auth.currentUser?.nom[0] ?? 'U',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Nom + Role
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                              CrossAxisAlignment.start,
                              children: [
                                Text(
                                  auth.currentUser?.nom ?? '',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Container(
                                  margin: const EdgeInsets.only(top: 2),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: auth.isDirecteur
                                        ? Colors.amber.withOpacity(0.3)
                                        : Colors.green.withOpacity(0.3),
                                    borderRadius:
                                    BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    auth.isDirecteur
                                        ? 'Directeur'
                                        : 'Chef Équipe',
                                    style: TextStyle(
                                      color: auth.isDirecteur
                                          ? Colors.amber[200]
                                          : Colors.green[200],
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Logout button
                          IconButton(
                            icon: const Icon(Icons.logout,
                                color: Colors.white70, size: 18),
                            tooltip: 'Déconnexion',
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () => _confirmLogout(context),
                          ),
                        ]),
                      ),
                      const SizedBox(height: 6),
                      const Text('v1.0.0',
                          style: TextStyle(
                              color: Colors.white38, fontSize: 11)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ===== CONTENT =====
          Expanded(child: _buildPage(_selectedIndex)),
        ],
      ),
    );
  }

  // Confirmation avant logout
  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('Déconnexion'),
        content: const Text('Voulez-vous vraiment vous déconnecter ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              context.read<AuthProvider>().logout();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Déconnecter'),
          ),
        ],
      ),
    );
  }

  Widget _buildPage(int index) {
    switch (index) {
      case 0:
        return const _DashboardPage();
      case 1:
        return const EmployeesPage();
      case 2:
        return const Center(child: Text('Pointage - Bientôt'));
      case 3:
        return const GestionMagasin();
      case 4:
        return const Center(child: Text('Rapports - Bientôt'));
      default:
        return const ParametresPage();
    }
  }
}

class _NavItem {
  final IconData icon;
  final String label;
  _NavItem({required this.icon, required this.label});
}

// ===== DASHBOARD =====
class _DashboardPage extends StatelessWidget {
  const _DashboardPage();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header avec nom utilisateur
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Bonjour, ${auth.currentUser?.nom ?? ''} 👋',
                    style: const TextStyle(
                        fontSize: 26, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Bienvenue dans le système de gestion DIPS',
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              _StatCard(
                  title: 'Employés',
                  value: '24',
                  icon: Icons.people,
                  color: Colors.blue),
              const SizedBox(width: 16),
              _StatCard(
                  title: 'Présents aujourd\'hui',
                  value: '18',
                  icon: Icons.check_circle,
                  color: Colors.green),
              const SizedBox(width: 16),
              _StatCard(
                  title: 'Produits en stock',
                  value: '142',
                  icon: Icons.inventory_2,
                  color: Colors.orange),
              const SizedBox(width: 16),
              _StatCard(
                  title: 'Rapports ce mois',
                  value: '7',
                  icon: Icons.bar_chart,
                  color: Colors.purple),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(value,
                        style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: color)),
                  ),
                  Text(title,
                      style: const TextStyle(
                          color: Colors.grey, fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}