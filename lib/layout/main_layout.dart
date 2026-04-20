import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/auth/app_permissions.dart';
import '../core/auth/auth_provider.dart';
import '../core/locale/app_locale.dart';
import '../core/site/site_model.dart';
import '../core/site/site_provider.dart';
import '../core/utils/responsive.dart';
import '../core/widgets/dips_brand_logo.dart';
import '../modules/Paramètres/paramètres.dart';
import '../modules/Demandes/leave_demandes_page.dart';
import '../modules/logistique/logistique_page.dart';
import '../modules/employees/employees_page.dart';
import '../modules/employees/employees_provider.dart';
import '../modules/magasin/gestion_magasin.dart';
import '../modules/magasin/magasin_provider.dart';
import '../modules/pointage/pointage_page.dart';
import '../modules/pointage/pointage_provider.dart';
import '../modules/pointage/driver_pointage_page.dart';
import '../modules/pointage/report_page.dart';
import '../modules/Rapports_factures/rapports_factures_page.dart';
import '../modules/overtime/overtime_page.dart';
import '../modules/overtime/overtime_provider.dart';
import '../modules/groupes/groupe_pointage_page.dart';
import '../modules/distribution/distribution_pointage_page.dart';
import '../modules/shifts/shifts_page.dart';

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> with TickerProviderStateMixin {
  int _selectedIndex = 0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  String? _listeningOvertimeEquipeId;
  String? _lastUserId;
  TabController? _mobileTabController;

  // Pages pré-construites et mises en cache par pageKey+userId.
  // On les recrée uniquement quand l'utilisateur change de compte.
  final Map<String, Widget> _pageCache = {};

  @override
  void dispose() {
    _mobileTabController?.dispose();
    super.dispose();
  }

  void _syncMobileTabController(int length, int index) {
    final i = index.clamp(0, length - 1);
    if (_mobileTabController == null || _mobileTabController!.length != length) {
      _mobileTabController?.dispose();
      _mobileTabController = TabController(length: length, vsync: this, initialIndex: i);
      _mobileTabController!.addListener(() {
        if (!mounted) return;
        if (_mobileTabController!.indexIsChanging) return;
        final idx = _mobileTabController!.index;
        if (_selectedIndex != idx) {
          setState(() => _selectedIndex = idx);
        }
      });
    }
  }

  /// السائق: Pointage + Rapport فقط. الشاف: Tableau de bord، Collaborateurs، Pointage، Shifts، Paramètres.
  /// مسؤول مجموعة/Distribution: Pointage فقط.
  List<_NavItem> _navItems(
    BuildContext context,
    bool isChauffeur,
    bool isChefEquipe,
    bool isGroupe, {
    int overtimeBadgeCount = 0,
  }) {
    final auth = context.read<AuthProvider>();
    if (isChauffeur) {
      return [
        _NavItem(key: 'pointage', icon: Icons.access_time, label: tr(context, 'nav_pointage')),
        _NavItem(
            key: 'report', icon: Icons.note_add, label: tr(context, 'nav_send_report')),
      ];
    }
    if (isGroupe) {
      return [
        _NavItem(key: 'groupe_pointage', icon: Icons.access_time, label: tr(context, 'nav_pointage')),
      ];
    }
    if (isChefEquipe) {
      return [
        _NavItem(
            key: 'dashboard', icon: Icons.dashboard, label: tr(context, 'nav_dashboard')),
        _NavItem(
            key: 'pointage', icon: Icons.access_time, label: tr(context, 'nav_pointage')),
        _NavItem(
            key: 'overtime',
            icon: Icons.access_time_filled,
            label: 'Heures Sup.',
            badgeCount: overtimeBadgeCount),
        _NavItem(
            key: 'settings', icon: Icons.settings, label: tr(context, 'nav_settings')),
        _NavItem(key: 'demandes', icon: Icons.inbox, label: 'Demandes'),
      ];
    }
    return [
      _NavItem(key: 'dashboard', icon: Icons.dashboard, label: tr(context, 'nav_dashboard')),
      if (auth.hasPermission(AppPermissions.employeesView))
        _NavItem(key: 'employees', icon: Icons.people, label: tr(context, 'nav_employees')),
      if (auth.hasPermission(AppPermissions.pointageView))
        _NavItem(
            key: 'pointage', icon: Icons.access_time, label: tr(context, 'nav_pointage')),
      if (auth.isChefAtelierAdmin)
        _NavItem(
            key: 'distribution_review', icon: Icons.fact_check, label: 'Distribution (hier)'),
      if (auth.hasPermission(AppPermissions.overtimeView))
        _NavItem(
            key: 'overtime', icon: Icons.access_time_filled, label: 'Heures Sup.'),
      if (auth.hasPermission(AppPermissions.shiftsView))
        _NavItem(
            key: 'shifts', icon: Icons.rotate_right, label: tr(context, 'nav_shifts')),
      if (auth.hasPermission(AppPermissions.stockView))
        _NavItem(
            key: 'stock', icon: Icons.inventory_2, label: tr(context, 'nav_stock')),
      if (auth.hasPermission(AppPermissions.reportsView))
        _NavItem(
            key: 'reports', icon: Icons.bar_chart, label: tr(context, 'nav_rapports')),
      if (auth.hasPermission(AppPermissions.settingsView))
        _NavItem(
            key: 'settings', icon: Icons.settings, label: tr(context, 'nav_settings')),
      if (auth.hasPermission(AppPermissions.demandesView))
        _NavItem(key: 'demandes', icon: Icons.inbox, label: 'Demandes'),
      if (auth.hasPermission(AppPermissions.logistiqueView))
        _NavItem(key: 'logistique', icon: Icons.local_shipping, label: 'Logistique'),
    ];
  }

  Widget _buildSidebarContent(
      BuildContext context,
      AuthProvider auth,
      List<_NavItem> items, {
        VoidCallback? onItemTap,
        TabController? mobileTabController,
      }) {
    final locale = context.watch<LocaleProvider>();
    return Container(
      width: 220,
      color: const Color(0xFF1565C0),
      child: Column(
        children: [
          // ── Header ─────────────────────────────────────────────────────────
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: DipsBrandLogo(
                      height: 56,
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Système de Gestion',
                    style: TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                ],
              ),
            ),
          ),

          // ── Site selector (super admin only) ───────────────────────────────
          Builder(builder: (ctx) {
            final authInner = ctx.watch<AuthProvider>();
            final site = ctx.watch<SiteProvider>();
            final isSuperAdmin =
                authInner.currentUser?.isSuperAdmin ?? false;
            if (!isSuperAdmin) return const SizedBox.shrink();
            return Padding(
              padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: DropdownButton<String>(
                  value: site.selectedSiteId ?? SiteId.all,
                  isExpanded: true,
                  dropdownColor: const Color(0xFF1565C0),
                  underline: const SizedBox(),
                  style:
                  const TextStyle(color: Colors.white, fontSize: 12),
                  items: [
                    DropdownMenuItem(
                        value: SiteId.all,
                        child: Text(tr(ctx, 'site_all'))),
                    DropdownMenuItem(
                        value: SiteId.jadida,
                        child: Text(SiteId.labelFr(SiteId.jadida))),
                    DropdownMenuItem(
                        value: SiteId.safi,
                        child: Text(SiteId.labelFr(SiteId.safi))),
                  ],
                  onChanged: (v) => site.setSelectedSite(v),
                ),
              ),
            );
          }),

          const Divider(color: Colors.white24),

          // ── Nav items ──────────────────────────────────────────────────────
          Expanded(
            child: ListView.builder(
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
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
                        color:
                        isSelected ? Colors.white : Colors.white70),
                    title: Row(
                      children: [
                        Flexible(
                          child: Text(
                            item.label,
                            style: TextStyle(
                              color:
                              isSelected ? Colors.white : Colors.white70,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (item.badgeCount > 0) ...[
                          const SizedBox(width: 6),
                          Container(
                            constraints:
                                const BoxConstraints(minWidth: 16, minHeight: 16),
                            padding:
                                const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(
                              color: Colors.redAccent,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              item.badgeCount > 99
                                  ? '99+'
                                  : item.badgeCount.toString(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                height: 1.0,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    onTap: () {
                      setState(() => _selectedIndex = index);
                      if (mobileTabController != null &&
                          mobileTabController.index != index) {
                        mobileTabController.animateTo(index);
                      }
                      onItemTap?.call();
                    },
                  ),
                );
              },
            ),
          ),

          // ── Footer ─────────────────────────────────────────────────────────
          const Divider(color: Colors.white24),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundColor:
                          Colors.white.withOpacity(0.2),
                          child: Text(
                            (auth.currentUser?.nom.isNotEmpty == true)
                                ? auth.currentUser!.nom[0]
                                : 'U',
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                            CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
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
                                padding:
                                const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(
                                  color: auth.isDirecteur
                                      ? Colors.amber
                                      .withOpacity(0.3)
                                      : auth.isChauffeur
                                      ? Colors.orange
                                      .withOpacity(0.3)
                                      : auth.isDistributionResponsable
                                      ? Colors.cyan
                                      .withOpacity(0.3)
                                      : Colors.green
                                      .withOpacity(0.3),
                                  borderRadius:
                                  BorderRadius.circular(4),
                                ),
                                child: Text(
                                  auth.isDirecteur
                                      ? tr(context, 'role_directeur')
                                      : auth.isChauffeur
                                      ? tr(context,
                                      'role_chauffeur')
                                      : auth.isDistributionResponsable
                                      ? 'Responsable Distribution'
                                      : tr(context,
                                      'role_chef_equipe'),
                                  style: TextStyle(
                                    color: auth.isDirecteur
                                        ? Colors.amber[200]
                                        : auth.isChauffeur
                                        ? Colors.orange[200]
                                        : auth.isDistributionResponsable
                                        ? Colors.cyan[200]
                                        : Colors.green[200],
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.logout,
                              color: Colors.white70, size: 18),
                          tooltip: tr(context, 'logout'),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () => _confirmLogout(context),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      TextButton(
                        onPressed: () => locale.setLocale('fr'),
                        style: TextButton.styleFrom(
                          foregroundColor: locale.locale == 'fr'
                              ? Colors.white
                              : Colors.white70,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8),
                          minimumSize: Size.zero,
                        ),
                        child: Text(tr(context, 'french'),
                            style: const TextStyle(fontSize: 11)),
                      ),
                      const Text('|',
                          style: TextStyle(
                              color: Colors.white54, fontSize: 11)),
                      TextButton(
                        onPressed: () => locale.setLocale('ar'),
                        style: TextButton.styleFrom(
                          foregroundColor: locale.locale == 'ar'
                              ? Colors.white
                              : Colors.white70,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8),
                          minimumSize: Size.zero,
                        ),
                        child: Text(tr(context, 'arabic'),
                            style: const TextStyle(fontSize: 11)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text('v1.0.0',
                      style: TextStyle(
                          color: Colors.white38, fontSize: 11)),
                ],
              ),
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
    final isGroupe = auth.isGroupeResponsable;
    final isDistribution = auth.isDistributionResponsable;

    // Si l'utilisateur change (logout/login), vider le cache et réinitialiser.
    final currentUserId = auth.userId;
    if (currentUserId != _lastUserId) {
      _lastUserId = currentUserId;
      _pageCache.clear();
      _selectedIndex = 0;
      _mobileTabController?.dispose();
      _mobileTabController = null;
    }

    if (isChefEquipe) {
      final equipeId = auth.equipeId;
      if (equipeId != null &&
          equipeId.isNotEmpty &&
          _listeningOvertimeEquipeId != equipeId) {
        _listeningOvertimeEquipeId = equipeId;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          context.read<OvertimeProvider>().listenTodayForEquipe(equipeId);
        });
      }
    }
    final overtimeBadgeCount =
        isChefEquipe ? context.watch<OvertimeProvider>().todayAssignments.length : 0;
    final items = _navItems(
      context,
      isChauffeur,
      isChefEquipe,
      isGroupe,
      overtimeBadgeCount: overtimeBadgeCount,
    );
    final effectiveItems = isDistribution
        ? <_NavItem>[
            _NavItem(key: 'distribution_pointage', icon: Icons.access_time, label: tr(context, 'nav_pointage')),
          ]
        : items;
    final mobile = isMobile(context);

    // Clamp index in case item list changes between role switches
    final safeIndex = _selectedIndex.clamp(0, effectiveItems.length - 1);

    // Construire chaque page une seule fois et la mettre en cache.
    // IndexedStack préserve le State (Stream, scroll, formulaires, etc.)
    // quand l'utilisateur navigue entre les onglets.
    final pages = effectiveItems.map((item) {
      final cacheKey = '${currentUserId}_${item.key}';
      _pageCache[cacheKey] ??= _buildPage(
          context, item.key, isChauffeur, isChefEquipe, isGroupe, isDistribution);
      return _pageCache[cacheKey]!;
    }).toList();

    if (mobile) {
      _syncMobileTabController(effectiveItems.length, safeIndex);
      return Scaffold(
        key: _scaffoldKey,
        appBar: AppBar(
          title: Text(
            effectiveItems[safeIndex].label,
            style: const TextStyle(fontSize: 18),
            overflow: TextOverflow.ellipsis,
          ),
          backgroundColor: const Color(0xFF1565C0),
          foregroundColor: Colors.white,
          leading: IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => _scaffoldKey.currentState?.openDrawer(),
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(48),
            child: Align(
              alignment: Alignment.centerLeft,
              child: TabBar(
                controller: _mobileTabController!,
                isScrollable: true,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white70,
                indicatorColor: Colors.white,
                indicatorWeight: 3,
                labelPadding: const EdgeInsets.symmetric(horizontal: 12),
                tabs: effectiveItems.map((item) {
                  return Tab(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Icon(item.icon, size: 20),
                            if (item.badgeCount > 0)
                              Positioned(
                                right: -8,
                                top: -4,
                                child: Container(
                                  constraints: const BoxConstraints(
                                    minWidth: 16,
                                    minHeight: 16,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                    vertical: 1,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.redAccent,
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    item.badgeCount > 99
                                        ? '99+'
                                        : item.badgeCount.toString(),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700,
                                      height: 1.0,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(width: 8),
                        Text(
                          item.label,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ),
        drawer: Drawer(
          child: Builder(
            builder: (ctx) => _buildSidebarContent(
              context,
              auth,
              effectiveItems,
              mobileTabController: _mobileTabController,
              onItemTap: () => Navigator.of(ctx).pop(),
            ),
          ),
        ),
        body: SafeArea(
          child: IndexedStack(index: safeIndex, children: pages),
        ),
      );
    }

    // ── Desktop / Tablet layout ────────────────────────────────────────────
    return Scaffold(
      body: Row(
        children: [
          _buildSidebarContent(context, auth, effectiveItems),
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1200),
                child: IndexedStack(index: safeIndex, children: pages),
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
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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

  Widget _buildPage(BuildContext context, String pageKey, bool isChauffeur, bool isChefEquipe, bool isGroupe, bool isDistribution) {
    if (isChauffeur) {
      if (pageKey == 'pointage') return const DriverPointagePage();
      if (pageKey == 'report') return const ReportPage();
      return const DriverPointagePage();
    }
    if (isGroupe) {
      return const GroupePointagePage();
    }
    if (isDistribution) {
      return const DistributionPointagePage();
    }
    if (isChefEquipe) {
      switch (pageKey) {
        case 'dashboard':
          return const _ChefDashboardPage();
        case 'pointage':
          return const PointagePage();
        case 'overtime':
          return const OvertimePage();
        case 'settings':
          return const ParametresPage();
        case 'demandes':
          return const DemandesPage(role: UserRole.demandeur);
        default:
          return const _ChefDashboardPage();
      }
    }

    switch (pageKey) {
      case 'dashboard':
        return const _DashboardPage();
      case 'employees':
        return const EmployeesPage();
      case 'pointage':
        return const PointagePage();
      case 'distribution_review':
        return const DistributionPointagePage(reviewOnly: true);
      case 'overtime':
        return const OvertimePage();
      case 'shifts':
        return const ShiftsPage();
      case 'stock':
        return GestionMagasinPage();
      case 'reports':
        return const RapportsFacturesPage();
      case 'settings':
        return const ParametresPage();
      case 'demandes':
        final auth = context.read<AuthProvider>();
        return DemandesPage(
          role: auth.isDirecteur ? UserRole.administrateur : UserRole.demandeur,
        );
      case 'logistique':
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

// ─────────────────────────────────────────────────────────────────────────────
// NavItem
// ─────────────────────────────────────────────────────────────────────────────
class _NavItem {
  final String key;
  final IconData icon;
  final String label;
  final int badgeCount;
  _NavItem({
    required this.key,
    required this.icon,
    required this.label,
    this.badgeCount = 0,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Placeholder page
// ─────────────────────────────────────────────────────────────────────────────
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
              style: TextStyle(
                  fontSize: mobile ? 13 : 14,
                  color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Dashboard
// ─────────────────────────────────────────────────────────────────────────────
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
      auth.currentUser?.isSuperAdmin == true
          ? site.selectedSiteId
          : null,
          (e) => e.siteId,
    );
    final filteredProduits = SiteId.filterBySite(
      magasin.produits,
      auth.currentUser?.allowedSiteIds,
      auth.currentUser?.isSuperAdmin == true
          ? site.selectedSiteId
          : null,
          (p) => p.siteId,
    );

    final employesCount = filteredEmployes.length;
    final stockTotal =
    filteredProduits.fold<int>(0, (s, p) => s + p.total);
    final presentLabel = '${pointage.todayPresentCount}';
    final stockLabel = '$stockTotal';
    final rapportsLabel = '${pointage.monthlyReportsCount}';

    final cards = [
      _StatCard(
          title: 'Collaborateurs',
          value: '$employesCount',
          icon: Icons.people,
          color: Colors.blue),
      _StatCard(
          title: "Présents aujourd'hui",
          value: presentLabel,
          icon: Icons.check_circle,
          color: Colors.green),
      _StatCard(
          title: 'Produits en stock',
          value: stockLabel,
          icon: Icons.inventory_2,
          color: Colors.orange),
      _StatCard(
          title: 'Rapports ce mois',
          value: rapportsLabel,
          icon: Icons.bar_chart,
          color: Colors.purple),
    ];

    return SingleChildScrollView(
      padding: EdgeInsets.all(padding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Greeting — never overflows
          Text(
            'Bonjour, ${auth.currentUser?.nom ?? ''} 👋',
            style: TextStyle(
              fontSize: mobile ? 20 : 26,
              fontWeight: FontWeight.bold,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            'Bienvenue dans le système de gestion DIPS',
            style: TextStyle(
                fontSize: mobile ? 12 : 14, color: Colors.grey[600]),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 20),

          // Stat cards — wrap on narrow screens, row on wide
          LayoutBuilder(builder: (ctx, constraints) {
            // Below 520 px: 2 × 2 grid
            if (constraints.maxWidth < 520) {
              return Column(
                children: [
                  Row(children: [
                    Expanded(child: cards[0]),
                    const SizedBox(width: 12),
                    Expanded(child: cards[1]),
                  ]),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(child: cards[2]),
                    const SizedBox(width: 12),
                    Expanded(child: cards[3]),
                  ]),
                ],
              );
            }
            // 520 – 900 px: 2 × 2 with larger gap
            if (constraints.maxWidth < 900) {
              return Wrap(
                spacing: 16,
                runSpacing: 16,
                children: cards
                    .map((c) => SizedBox(
                    width:
                    (constraints.maxWidth - 16) / 2,
                    child: c))
                    .toList(),
              );
            }
            // Wide: single row
            return Row(
              children: [
                for (int i = 0; i < cards.length; i++) ...[
                  if (i > 0) const SizedBox(width: 16),
                  Expanded(child: cards[i]),
                ],
              ],
            );
          }),
        ],
      ),
    );
  }
}

class _ChefDashboardPage extends StatelessWidget {
  const _ChefDashboardPage();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final mobile = isMobile(context);
    final padding = pagePadding(context);
    final user = auth.currentUser;
    final hasPhoto = (user?.photoUrl ?? '').trim().isNotEmpty;
    final displayName = user?.nom.isNotEmpty == true ? user!.nom : 'Chef d\'équipe';

    return SingleChildScrollView(
      padding: EdgeInsets.all(padding),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: mobile ? 38 : 48,
                    backgroundColor: const Color(0xFF1565C0).withOpacity(0.12),
                    backgroundImage: hasPhoto ? NetworkImage(user!.photoUrl!) : null,
                    child: hasPhoto
                        ? null
                        : Text(
                            displayName[0].toUpperCase(),
                            style: TextStyle(
                              fontSize: mobile ? 26 : 32,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF1565C0),
                            ),
                          ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Bonjour, $displayName',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: mobile ? 22 : 26,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Bienvenue dans votre espace Chef d\'équipe',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: mobile ? 13 : 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// StatCard — overflow-safe
// ─────────────────────────────────────────────────────────────────────────────
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
          // Icon badge — fixed size, never shrinks
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 12),
          // Text column — takes remaining space, clips gracefully
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: color),
                  ),
                ),
                Text(
                  title,
                  style: const TextStyle(
                      color: Colors.grey, fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}