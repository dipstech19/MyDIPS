import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/auth/auth_provider.dart';
import '../core/locale/app_locale.dart';
import '../core/site/site_model.dart';
import '../core/site/site_provider.dart';
import '../core/utils/responsive.dart';
import '../modules/Paramètres/paramètres.dart';
import '../modules/Demandes/demandes_page.dart';
import '../modules/logistique/logistique_page.dart';
import '../modules/employees/employees_page.dart';
import '../modules/employees/employees_provider.dart';
import '../modules/magasin/gestion_magasin_firebase.dart';
import '../modules/magasin/magasin_provider.dart';
import '../modules/pointage/pointage_page.dart';
import '../modules/pointage/pointage_provider.dart';
import '../modules/pointage/driver_pointage_page.dart';
import '../modules/pointage/report_page.dart';
import '../modules/shifts/shifts_page.dart';

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _selectedIndex = 0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  /// السائق: Pointage + Rapport فقط. الشاف: Tableau de bord، Employés (اسم/صورة/CIN)، Pointage، Shifts، Paramètres (معلوماته فقط). الأدمن: كل القائمة.
  List<_NavItem> _navItems(BuildContext context, bool isChauffeur, bool isChefEquipe) {
    if (isChauffeur) {
      return [
        _NavItem(icon: Icons.access_time, label: tr(context, 'nav_pointage')),
        _NavItem(icon: Icons.note_add, label: tr(context, 'nav_send_report')),
      ];
    }
    if (isChefEquipe) {
      return [
        _NavItem(icon: Icons.dashboard, label: tr(context, 'nav_dashboard')),
        _NavItem(icon: Icons.people, label: tr(context, 'nav_employees')),
        _NavItem(icon: Icons.access_time, label: tr(context, 'nav_pointage')),
        _NavItem(icon: Icons.rotate_right, label: tr(context, 'nav_shifts')),
        _NavItem(icon: Icons.settings, label: tr(context, 'nav_settings')),
      ];
    }
    return [
      _NavItem(icon: Icons.dashboard, label: tr(context, 'nav_dashboard')),
      _NavItem(icon: Icons.people, label: tr(context, 'nav_employees')),
      _NavItem(icon: Icons.access_time, label: tr(context, 'nav_pointage')),
      _NavItem(icon: Icons.rotate_right, label: tr(context, 'nav_shifts')),
      _NavItem(icon: Icons.inventory_2, label: tr(context, 'nav_stock')),
      _NavItem(icon: Icons.bar_chart, label: tr(context, 'nav_rapports')),
      _NavItem(icon: Icons.settings, label: tr(context, 'nav_settings')),
      _NavItem(icon: Icons.inbox, label: 'Demandes'),
      _NavItem(icon: Icons.local_shipping, label: 'Logistique'),
    ];
  }

  Widget _buildSidebar(BuildContext context, AuthProvider auth, List<_NavItem> items, {VoidCallback? onItemTap}) {
    final locale = context.watch<LocaleProvider>();
    return Container(
      width: 220,
      color: const Color(0xFF1565C0),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: const Column(
              children: [
                Icon(Icons.business, color: Colors.white, size: 44),
                SizedBox(height: 8),
                Text('DIPS', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                Text('Système de Gestion', style: TextStyle(color: Colors.white70, fontSize: 11)),
              ],
            ),
          ),
          Builder(
            builder: (ctx) {
              final auth = ctx.watch<AuthProvider>();
              final site = ctx.watch<SiteProvider>();
              final isSuperAdmin = auth.currentUser?.isSuperAdmin ?? false;
              if (!isSuperAdmin) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: DropdownButton<String>(
                    value: site.selectedSiteId ?? SiteId.all,
                    isExpanded: true,
                    dropdownColor: const Color(0xFF1565C0),
                    underline: const SizedBox(),
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                    items: [
                      DropdownMenuItem(value: SiteId.all, child: Text(tr(ctx, 'site_all'))),
                      DropdownMenuItem(value: SiteId.jadida, child: Text(SiteId.labelFr(SiteId.jadida))),
                      DropdownMenuItem(value: SiteId.safi, child: Text(SiteId.labelFr(SiteId.safi))),
                    ],
                    onChanged: (v) => site.setSelectedSite(v),
                  ),
                ),
              );
            },
          ),
          const Divider(color: Colors.white24),
          Expanded(
            child: ListView.builder(
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                final isSelected = _selectedIndex == index;
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.white.withOpacity(0.2) : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: ListTile(
                    leading: Icon(item.icon, color: isSelected ? Colors.white : Colors.white70),
                    title: Text(item.label, style: TextStyle(color: isSelected ? Colors.white : Colors.white70, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                    onTap: () {
                      setState(() => _selectedIndex = index);
                      onItemTap?.call();
                    },
                  ),
                );
              },
            ),
          ),
          const Divider(color: Colors.white24),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                  child: Row(children: [
                    CircleAvatar(radius: 16, backgroundColor: Colors.white.withOpacity(0.2), child: Text((auth.currentUser?.nom.isNotEmpty == true) ? auth.currentUser!.nom[0] : 'U', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14))),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(auth.currentUser?.nom ?? '', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                        Container(
                          margin: const EdgeInsets.only(top: 2),
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: auth.isDirecteur ? Colors.amber.withOpacity(0.3) : auth.isChauffeur ? Colors.orange.withOpacity(0.3) : Colors.green.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            auth.isDirecteur ? tr(context, 'role_directeur') : auth.isChauffeur ? tr(context, 'role_chauffeur') : tr(context, 'role_chef_equipe'),
                            style: TextStyle(color: auth.isDirecteur ? Colors.amber[200] : auth.isChauffeur ? Colors.orange[200] : Colors.green[200], fontSize: 10, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ]),
                    ),
                    IconButton(icon: const Icon(Icons.logout, color: Colors.white70, size: 18), tooltip: tr(context, 'logout'), padding: EdgeInsets.zero, constraints: const BoxConstraints(), onPressed: () => _confirmLogout(context)),
                  ]),
                ),
                const SizedBox(height: 6),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  TextButton(onPressed: () => locale.setLocale('fr'), style: TextButton.styleFrom(foregroundColor: locale.locale == 'fr' ? Colors.white : Colors.white70, padding: const EdgeInsets.symmetric(horizontal: 8), minimumSize: Size.zero), child: Text(tr(context, 'french'), style: const TextStyle(fontSize: 11))),
                  Text('|', style: TextStyle(color: Colors.white54, fontSize: 11)),
                  TextButton(onPressed: () => locale.setLocale('ar'), style: TextButton.styleFrom(foregroundColor: locale.locale == 'ar' ? Colors.white : Colors.white70, padding: const EdgeInsets.symmetric(horizontal: 8), minimumSize: Size.zero), child: Text(tr(context, 'arabic'), style: const TextStyle(fontSize: 11))),
                ]),
                const SizedBox(height: 4),
                const Text('v1.0.0', style: TextStyle(color: Colors.white38, fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final isChauffeur = auth.isChauffeur;
    final isChefEquipe = auth.isChefEquipe && !auth.isDirecteur;
    final items = _navItems(context, isChauffeur, isChefEquipe);
    final mobile = isMobile(context);

    if (mobile) {
      return Scaffold(
        key: _scaffoldKey,
        appBar: AppBar(
          title: Text(items[_selectedIndex.clamp(0, items.length - 1)].label, style: const TextStyle(fontSize: 18)),
          backgroundColor: const Color(0xFF1565C0),
          foregroundColor: Colors.white,
          leading: IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => _scaffoldKey.currentState?.openDrawer(),
          ),
        ),
        drawer: Drawer(
          child: Builder(
            builder: (ctx) => _buildSidebar(context, auth, items, onItemTap: () => Navigator.of(ctx).pop()),
          ),
        ),
        body: SafeArea(child: _buildPage(context, _selectedIndex, isChauffeur, isChefEquipe)),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _selectedIndex.clamp(0, items.length - 1),
          onTap: (i) => setState(() => _selectedIndex = i),
          selectedItemColor: const Color(0xFF1565C0),
          unselectedItemColor: Colors.grey,
          type: BottomNavigationBarType.fixed,
          items: items.map((item) => BottomNavigationBarItem(icon: Icon(item.icon), label: item.label)).toList(),
        ),
      );
    }

    return Scaffold(
      body: Row(
        children: [
          _buildSidebar(context, auth, items),
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: 1200),
                child: _buildPage(context, _selectedIndex, isChauffeur, isChefEquipe),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(tr(context, 'logout')),
        content: Text(tr(context, 'logout_confirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(tr(context, 'cancel')),
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
            child: Text(tr(context, 'disconnect')),
          ),
        ],
      ),
    );
  }

  Widget _buildPage(BuildContext context, int index, bool isChauffeur, bool isChefEquipe) {
    if (isChauffeur) {
      if (index == 0) return const DriverPointagePage();
      if (index == 1) return const ReportPage();
      return const DriverPointagePage();
    }
    if (isChefEquipe) {
      switch (index) {
        case 0: return const _DashboardPage();
        case 1: return const EmployeesPage();
        case 2: return const PointagePage();
        case 3: return const ShiftsPage();
        case 4: return const ParametresPage();
        default: return const _DashboardPage();
      }
    }
    switch (index) {
      case 0:
        return const _DashboardPage();
      case 1:
        return const EmployeesPage();
      case 2:
        return const PointagePage();
      case 3:
        return const ShiftsPage();
      case 4:
        return const GestionMagasinFirebase();
      case 5:
        return const _PlaceholderPage(
          icon: Icons.bar_chart,
          title: 'Rapports',
          subtitle: 'Bientôt disponible',
        );
      case 6:
        return const ParametresPage();
      case 7:
        return const DemandesPage();
      case 8:
        return const LogistiquePage();
      default:
        return const _PlaceholderPage(
          icon: Icons.settings,
          title: 'Paramètres',
          subtitle: 'Bientôt disponible',
        );
    }
  }
}

class _NavItem {
  final IconData icon;
  final String label;
  _NavItem({required this.icon, required this.label});
}

/// صفحة مؤقتة (Rapports, etc.)
class _PlaceholderPage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _PlaceholderPage({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final mobile = isMobile(context);
    final padding = pagePadding(context);
    return SingleChildScrollView(
      padding: EdgeInsets.all(padding),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 48),
            Icon(icon, size: mobile ? 64 : 80, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              title,
              style: TextStyle(
                fontSize: mobile ? 20 : 24,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: TextStyle(fontSize: mobile ? 13 : 14, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ===== DASHBOARD =====
class _DashboardPage extends StatelessWidget {
  const _DashboardPage();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final site = context.watch<SiteProvider>();
    final emp = context.watch<EmployeesProvider>();
    final pointage = context.watch<PointageProvider>();
    final magasin = context.watch<MagasinProvider>();
    final mobile = isMobile(context);
    final padding = pagePadding(context);
    final filteredEmployes = SiteId.filterBySite(
      emp.employes,
      auth.currentUser?.allowedSiteIds,
      auth.currentUser?.isSuperAdmin == true ? site.selectedSiteId : null,
      (e) => e.siteId,
    );
    final employesCount = filteredEmployes.length;
    final filteredProduits = SiteId.filterBySite(
      magasin.produits,
      auth.currentUser?.allowedSiteIds,
      auth.currentUser?.isSuperAdmin == true ? site.selectedSiteId : null,
      (p) => p.siteId,
    );
    final stockTotal = filteredProduits.fold<int>(0, (s, p) => s + p.total);
    final presentLabel = '${pointage.todayPresentCount}';
    final stockLabel = '$stockTotal';
    final rapportsLabel = '${pointage.monthlyReportsCount}';

    return SingleChildScrollView(
      padding: EdgeInsets.all(padding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Bonjour, ${auth.currentUser?.nom ?? ''} 👋',
            style: TextStyle(
              fontSize: mobile ? 20 : 26,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Bienvenue dans le système de gestion DIPS',
            style: TextStyle(fontSize: mobile ? 12 : 14, color: Colors.grey[600]),
          ),
          const SizedBox(height: 20),
          if (mobile)
            Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        title: 'Employés',
                        value: '$employesCount',
                        icon: Icons.people,
                        color: Colors.blue,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatCard(
                        title: 'Présents aujourd\'hui',
                        value: presentLabel,
                        icon: Icons.check_circle,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        title: 'Produits en stock',
                        value: stockLabel,
                        icon: Icons.inventory_2,
                        color: Colors.orange,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatCard(
                        title: 'Rapports ce mois',
                        value: rapportsLabel,
                        icon: Icons.bar_chart,
                        color: Colors.purple,
                      ),
                    ),
                  ],
                ),
              ],
            )
          else
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    title: 'Employés',
                    value: '$employesCount',
                    icon: Icons.people,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _StatCard(
                    title: 'Présents aujourd\'hui',
                    value: presentLabel,
                    icon: Icons.check_circle,
                    color: Colors.green,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _StatCard(
                    title: 'Produits en stock',
                    value: stockLabel,
                    icon: Icons.inventory_2,
                    color: Colors.orange,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _StatCard(
                    title: 'Rapports ce mois',
                    value: rapportsLabel,
                    icon: Icons.bar_chart,
                    color: Colors.purple,
                  ),
                ),
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
    return Container(
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
    );
  }
}