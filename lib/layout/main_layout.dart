import 'package:flutter/material.dart';

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
    _NavItem(icon: Icons.inventory_2, label: 'Stock'),
    _NavItem(icon: Icons.bar_chart, label: 'Rapports'),
    _NavItem(icon: Icons.settings, label: 'Paramètres'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // ===== SIDEBAR =====
          Container(
            width: 220,
            color: const Color(0xFF1565C0),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 30),
                  child: const Column(
                    children: [
                      Icon(Icons.business, color: Colors.white, size: 48),
                      SizedBox(height: 8),
                      Text(
                        'DIPS',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Système de Gestion',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const Divider(color: Colors.white24),
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
                              color: isSelected ? Colors.white : Colors.white70),
                          title: Text(
                            item.label,
                            style: TextStyle(
                              color: isSelected ? Colors.white : Colors.white70,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                          onTap: () =>
                              setState(() => _selectedIndex = index),
                        ),
                      );
                    },
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'v1.0.0',
                    style: TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          // ===== CONTENT =====
          Expanded(
            child: _buildPage(_selectedIndex),
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
        return const Center(child: Text('Gestion des Employés - Bientôt'));
      case 2:
        return const Center(child: Text('Pointage - Bientôt'));
      case 3:
        return const Center(child: Text('Gestion du Stock - Bientôt'));
      case 4:
        return const Center(child: Text('Rapports - Bientôt'));
      default:
        return const Center(child: Text('Paramètres - Bientôt'));
    }
  }
}

class _NavItem {
  final IconData icon;
  final String label;
  _NavItem({required this.icon, required this.label});
}

// ===== DASHBOARD PAGE =====
class _DashboardPage extends StatelessWidget {
  const _DashboardPage();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Tableau de bord',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Bienvenue dans le système de gestion DIPS',
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
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

  const _StatCard(
      {required this.title,
        required this.value,
        required this.icon,
        required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value,
                    style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: color)),
                Text(title, style: const TextStyle(color: Colors.grey)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}