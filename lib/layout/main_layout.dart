import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/auth/app_permissions.dart';
import '../core/auth/auth_provider.dart';
import '../core/locale/app_locale.dart';
import '../core/site/site_model.dart';
import '../core/site/site_provider.dart';
import '../core/utils/responsive.dart';
import '../core/theme/app_theme.dart';
import '../core/widgets/dips_brand_logo.dart';
import '../core/notifications/push_notifications_service.dart';
import '../modules/Paramètres/paramètres.dart';
import '../modules/Demandes/leave_demandes_page.dart';
import '../modules/logistique/logistique_page.dart';
import '../modules/employees/employees_page.dart';
import '../modules/magasin/gestion_magasin.dart';
import '../modules/pointage/pointage_page.dart';
import '../modules/pointage/pointage_provider.dart';
import '../modules/pointage/driver_pointage_page.dart';
import '../modules/pointage/report_page.dart';
import '../modules/Rapports_factures/rapports_factures_page.dart';
import '../modules/overtime/overtime_page.dart';
import '../modules/overtime/overtime_provider.dart';
import '../modules/overtime/models/overtime_model.dart';
import '../modules/groupes/groupe_pointage_page.dart';
import '../modules/distribution/distribution_pointage_page.dart';
import '../modules/distribution/distribution_groups_provider.dart';
import '../modules/distribution/distribution_shifts_provider.dart';
import '../modules/distribution/distribution_shifts_page.dart';
import '../modules/employees/employees_provider.dart';
import '../modules/shifts/shifts_page.dart';
import '../modules/shifts/models/shift_models.dart';
import 'director_dashboard_page.dart';

const Color _kNavBlue = AppColors.brand;
const double _kSidebarWidth = 220;
const double _kSidebarRailWidth = 72;
const Duration _kSidebarAnim = Duration(milliseconds: 280);

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> with TickerProviderStateMixin {
  int _selectedIndex = 0;
  bool _sidebarOpen = true;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  String? _listeningOvertimeEquipeId;
  String? _lastUserId;
  TabController? _mobileTabController;

  // Pages pré-construites et mises en cache par pageKey+userId.
  // On les recrée uniquement quand l'utilisateur change de compte.
  final Map<String, Widget> _pageCache = {};
  List<_NavItem> _effectiveItemsCurrent = const [];
  late final VoidCallback _leaveBadgeListener;

  @override
  void initState() {
    super.initState();
    _leaveBadgeListener = () {
      if (!mounted) return;
      setState(() {});
    };
    PushNotificationsService.instance.leaveUnreadCount.addListener(_leaveBadgeListener);
  }

  @override
  void dispose() {
    PushNotificationsService.instance.leaveUnreadCount.removeListener(_leaveBadgeListener);
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
    int demandesBadgeCount = 0,
  }) {
    final auth = context.read<AuthProvider>();
    final isZoneAdmin = auth.isChefZoneAdmin;
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
        _NavItem(key: 'demandes', icon: Icons.inbox, label: 'Demandes', badgeCount: demandesBadgeCount),
      ];
    }
    if (isZoneAdmin) {
      return [
        _NavItem(key: 'dashboard', icon: Icons.dashboard, label: tr(context, 'nav_dashboard')),
        if (auth.hasPermission(AppPermissions.pointageView))
          _NavItem(
              key: 'pointage', icon: Icons.access_time, label: tr(context, 'nav_pointage')),
        if (auth.hasPermission(AppPermissions.employeesView))
          _NavItem(key: 'employees', icon: Icons.people, label: tr(context, 'nav_employees')),
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
          _NavItem(key: 'demandes', icon: Icons.inbox, label: 'Demandes', badgeCount: demandesBadgeCount),
        if (auth.hasPermission(AppPermissions.logistiqueView))
          _NavItem(key: 'logistique', icon: Icons.local_shipping, label: 'Logistique'),
      ];
    }
    return [
      _NavItem(key: 'dashboard', icon: Icons.dashboard, label: tr(context, 'nav_dashboard')),
      if (auth.hasPermission(AppPermissions.employeesView))
        _NavItem(key: 'employees', icon: Icons.people, label: tr(context, 'nav_employees')),
      if (auth.hasPermission(AppPermissions.pointageView))
        _NavItem(
            key: 'pointage', icon: Icons.access_time, label: tr(context, 'nav_pointage')),
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
        _NavItem(key: 'demandes', icon: Icons.inbox, label: 'Demandes', badgeCount: demandesBadgeCount),
      if (auth.hasPermission(AppPermissions.logistiqueView))
        _NavItem(key: 'logistique', icon: Icons.local_shipping, label: 'Logistique'),
    ];
  }

  Future<void> _handleNavIndexChange(
    BuildContext context,
    int newIndex,
    List<_NavItem> effectiveItems, {
    required bool isChefEquipe,
    required bool isGroupe,
    required bool isDistribution,
    TabController? mobileTabController,
  }) async {
    if (isGroupe || isDistribution) {
      _applyNavIndex(newIndex, mobileTabController);
      final targetKey = effectiveItems[newIndex.clamp(0, effectiveItems.length - 1)].key;
      if (targetKey == 'demandes' || targetKey == 'distribution_demandes') {
        PushNotificationsService.instance.markLeaveNotificationsRead();
      }
      return;
    }
    final safeIndex = _selectedIndex.clamp(0, effectiveItems.length - 1);
    if (newIndex == safeIndex) return;
    if (!isChefEquipe || effectiveItems[safeIndex].key != 'pointage') {
      _applyNavIndex(newIndex, mobileTabController);
      final targetKey = effectiveItems[newIndex.clamp(0, effectiveItems.length - 1)].key;
      if (targetKey == 'demandes' || targetKey == 'distribution_demandes') {
        PushNotificationsService.instance.markLeaveNotificationsRead();
      }
      return;
    }
    final equipeId = context.read<AuthProvider>().equipeId ?? '';
    final pointage = context.read<PointageProvider>();
    final reportSubmitted =
        equipeId.isNotEmpty && pointage.hasEquipeDailyReportSubmittedToday(equipeId);

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(tr(ctx, 'pointage_leave_nav_title')),
        content: Text(
          reportSubmitted ? tr(ctx, 'pointage_leave_nav_body_sent') : tr(ctx, 'pointage_leave_nav_body_unsent'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(tr(ctx, 'pointage_leave_nav_stay')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(tr(ctx, 'pointage_leave_nav_leave')),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      _applyNavIndex(newIndex, mobileTabController);
      final targetKey = effectiveItems[newIndex.clamp(0, effectiveItems.length - 1)].key;
      if (targetKey == 'demandes' || targetKey == 'distribution_demandes') {
        PushNotificationsService.instance.markLeaveNotificationsRead();
      }
    }
  }

  void _applyNavIndex(int newIndex, TabController? mobileTabController) {
    if (mobileTabController != null) {
      mobileTabController.animateTo(newIndex);
    } else {
      setState(() => _selectedIndex = newIndex);
    }
  }

  void _openPageByKeyFromDashboard(String pageKey) {
    if (_effectiveItemsCurrent.isEmpty) return;
    final index = _effectiveItemsCurrent.indexWhere((i) => i.key == pageKey);
    if (index < 0) return;
    _applyNavIndex(index, _mobileTabController);
    if (pageKey == 'demandes' || pageKey == 'distribution_demandes') {
      PushNotificationsService.instance.markLeaveNotificationsRead();
    }
  }

  Widget _buildNavEntry(
    BuildContext context, {
    required _NavItem item,
    required int index,
    required bool isSelected,
    required bool expanded,
    required Future<void> Function(int index) onNavTap,
    VoidCallback? onItemTap,
  }) {
    Future<void> handleTap() async {
      await onNavTap(index);
      onItemTap?.call();
    }

    Widget badgeDot() {
      if (item.badgeCount <= 0) return const SizedBox.shrink();
      return Container(
        constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
        padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
        decoration: BoxDecoration(
          color: Colors.redAccent,
          borderRadius: BorderRadius.circular(999),
        ),
        alignment: Alignment.center,
        child: Text(
          item.badgeCount > 99 ? '99+' : item.badgeCount.toString(),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 8,
            fontWeight: FontWeight.w700,
            height: 1.0,
          ),
        ),
      );
    }

    final tileDecoration = BoxDecoration(
      color: isSelected ? Colors.white.withOpacity(0.2) : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
    );

    if (!expanded) {
      return Tooltip(
        message: item.label,
        waitDuration: const Duration(milliseconds: 400),
        child: InkWell(
          onTap: handleTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
            padding: const EdgeInsets.symmetric(vertical: 11),
            decoration: tileDecoration,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                Icon(
                  item.icon,
                  size: 22,
                  color: isSelected ? Colors.white : Colors.white70,
                ),
                if (item.badgeCount > 0)
                  Positioned(right: 10, top: 4, child: badgeDot()),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: tileDecoration,
      child: ListTile(
        dense: true,
        leading: Icon(
          item.icon,
          color: isSelected ? Colors.white : Colors.white70,
        ),
        title: Row(
          children: [
            Flexible(
              child: Text(
                item.label,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.white70,
                  fontWeight:
                      isSelected ? FontWeight.bold : FontWeight.normal,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (item.badgeCount > 0) ...[
              const SizedBox(width: 6),
              badgeDot(),
            ],
          ],
        ),
        onTap: handleTap,
      ),
    );
  }

  Widget _buildSidebarContent(
      BuildContext context,
      AuthProvider auth,
      List<_NavItem> items, {
        VoidCallback? onItemTap,
        TabController? mobileTabController,
        required Future<void> Function(int index) onNavTap,
        bool expanded = true,
        bool showCollapseButton = false,
        VoidCallback? onToggleSidebar,
      }) {
    final locale = context.watch<LocaleProvider>();
    final compactHeight = MediaQuery.sizeOf(context).height < 640;
    final sidebarWidth = expanded ? _kSidebarWidth : _kSidebarRailWidth;
    return Container(
      width: sidebarWidth,
      color: _kNavBlue,
      child: Column(
        children: [
          // ── Header ─────────────────────────────────────────────────────────
          SafeArea(
            bottom: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                expanded ? 8 : 4,
                16,
                expanded ? 8 : 4,
                expanded ? 20 : 12,
              ),
              child: Column(
                children: [
                  if (showCollapseButton && onToggleSidebar != null)
                    Align(
                      alignment: expanded
                          ? Alignment.centerRight
                          : Alignment.center,
                      child: IconButton(
                        icon: Icon(
                          expanded ? Icons.menu_open : Icons.menu,
                          color: Colors.white70,
                          size: 22,
                        ),
                        tooltip: expanded
                            ? tr(context, 'nav_hide_menu')
                            : tr(context, 'nav_show_menu'),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 36,
                          minHeight: 36,
                        ),
                        onPressed: onToggleSidebar,
                      ),
                    ),
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: expanded ? 12 : 6,
                    ),
                    child: DipsBrandLogo(
                      height: expanded ? 56 : 36,
                      fit: BoxFit.contain,
                    ),
                  ),
                  if (expanded) ...[
                    const SizedBox(height: 6),
                    Text(
                      tr(context, 'app_title'),
                      style: const TextStyle(color: Colors.white70, fontSize: 11),
                    ),
                  ],
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
            if (!expanded || !isSuperAdmin) return const SizedBox.shrink();
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
                  dropdownColor: _kNavBlue,
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
                return _buildNavEntry(
                  context,
                  item: item,
                  index: index,
                  isSelected: _selectedIndex == index,
                  expanded: expanded,
                  onNavTap: onNavTap,
                  onItemTap: onItemTap,
                );
              },
            ),
          ),

          // ── Footer ─────────────────────────────────────────────────────────
          if (!compactHeight) ...[
            const Divider(color: Colors.white24),
            SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.all(expanded ? 12 : 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                  if (!expanded) ...[
                    Tooltip(
                      message: auth.currentUser?.nom ?? '',
                      child: CircleAvatar(
                        radius: 18,
                        backgroundColor: Colors.white.withOpacity(0.2),
                        child: Text(
                          (auth.currentUser?.nom.isNotEmpty == true)
                              ? auth.currentUser!.nom[0]
                              : 'U',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.logout,
                          color: Colors.white70, size: 20),
                      tooltip: tr(context, 'logout'),
                      onPressed: () => _confirmLogout(context),
                    ),
                  ] else
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
                                  auth.isChefZoneAdmin
                                      ? 'Chef de zone'
                                      : auth.isChefAtelierAdmin
                                      ? 'Chef d\'atelier'
                                      : auth.isDirecteur
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
                  if (expanded) ...[
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
                  ],
                ),
              ),
            ),
          ],
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
    final demandesBadgeCount = PushNotificationsService.instance.leaveUnreadCount.value;
    final items = _navItems(
      context,
      isChauffeur,
      isChefEquipe,
      isGroupe,
      overtimeBadgeCount: overtimeBadgeCount,
      demandesBadgeCount: demandesBadgeCount,
    );
    final effectiveItems = isDistribution
        ? <_NavItem>[
            _NavItem(key: 'distribution_dashboard', icon: Icons.dashboard, label: tr(context, 'nav_dashboard')),
            _NavItem(key: 'distribution_pointage', icon: Icons.access_time, label: tr(context, 'nav_pointage')),
            _NavItem(key: 'distribution_shifts', icon: Icons.rotate_right, label: tr(context, 'nav_shifts')),
            _NavItem(key: 'distribution_demandes', icon: Icons.inbox, label: 'Demandes', badgeCount: demandesBadgeCount),
          ]
        : items;
    final mobile = isMobile(context);
    _effectiveItemsCurrent = effectiveItems;

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
          backgroundColor: _kNavBlue,
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
                onTap: (index) {
                  unawaited(
                    _handleNavIndexChange(
                      context,
                      index,
                      effectiveItems,
                      isChefEquipe: isChefEquipe,
                      isGroupe: isGroupe,
                      isDistribution: isDistribution,
                      mobileTabController: _mobileTabController,
                    ),
                  );
                },
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
              onNavTap: (index) => _handleNavIndexChange(
                context,
                index,
                effectiveItems,
                isChefEquipe: isChefEquipe,
                isGroupe: isGroupe,
                isDistribution: isDistribution,
                mobileTabController: _mobileTabController,
              ),
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
    Widget buildMainContent() {
      final currentKey = effectiveItems[safeIndex].key;
      final fullWidthPages = {'shifts'};
      final useFullWidth = fullWidthPages.contains(currentKey);
      if (useFullWidth) {
        return IndexedStack(index: safeIndex, children: pages);
      }
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: IndexedStack(index: safeIndex, children: pages),
        ),
      );
    }

    return Scaffold(
      body: Row(
        children: [
          AnimatedContainer(
            duration: _kSidebarAnim,
            curve: Curves.easeInOutCubic,
            width: _sidebarOpen ? _kSidebarWidth : _kSidebarRailWidth,
            child: _buildSidebarContent(
              context,
              auth,
              effectiveItems,
              expanded: _sidebarOpen,
              showCollapseButton: true,
              onToggleSidebar: () =>
                  setState(() => _sidebarOpen = !_sidebarOpen),
              onNavTap: (index) => _handleNavIndexChange(
                context,
                index,
                effectiveItems,
                isChefEquipe: isChefEquipe,
                isGroupe: isGroupe,
                isDistribution: isDistribution,
                mobileTabController: null,
              ),
            ),
          ),
          Expanded(child: buildMainContent()),
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
      switch (pageKey) {
        case 'distribution_dashboard':
          return const _DistributionDashboardPage();
        case 'distribution_demandes':
          return const DemandesPage(role: UserRole.demandeur);
        case 'distribution_shifts':
          return const DistributionShiftsPage();
        case 'distribution_pointage':
        default:
          return const DistributionPointagePage();
      }
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
      case 'distribution_pointage':
        return const DistributionPointagePage();
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
  Widget build(BuildContext context) => const DirectorDashboardPage();
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
                    backgroundColor: _kNavBlue.withOpacity(0.12),
                    backgroundImage: hasPhoto ? NetworkImage(user!.photoUrl!) : null,
                    child: hasPhoto
                        ? null
                        : Text(
                            displayName[0].toUpperCase(),
                            style: TextStyle(
                              fontSize: mobile ? 26 : 32,
                              fontWeight: FontWeight.bold,
                              color: _kNavBlue,
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

class _DistributionDashboardPage extends StatelessWidget {
  const _DistributionDashboardPage();

  String _shiftLabel(ShiftType shift) {
    switch (shift) {
      case ShiftType.morning:
        return 'P1 (${shift.timeRange.replaceAll('–', '-')})';
      case ShiftType.evening:
        return 'P2 (${shift.timeRange.replaceAll('–', '-')})';
      case ShiftType.night:
        return 'P3 (${shift.timeRange.replaceAll('–', '-')})';
      case ShiftType.rest:
        return 'RH';
    }
  }

  @override
  Widget build(BuildContext context) {
    final layoutState = context.findAncestorStateOfType<_MainLayoutState>();
    final auth = context.watch<AuthProvider>();
    final mobile = isMobile(context);
    final padding = pagePadding(context);
    final groupsProv = context.watch<DistributionGroupsProvider>();
    final shiftsProv = context.watch<DistributionShiftsProvider>();
    final employeesProv = context.watch<EmployeesProvider>();
    final today = DateTime.now();
    final day = DateTime(today.year, today.month, today.day);

    final allowedIds = auth.distributionGroupIds;
    final availableGroups = allowedIds.isEmpty
        ? groupsProv.groups
        : groupsProv.groups.where((g) => allowedIds.contains(g.id)).toList();
    final group = availableGroups.isEmpty ? null : availableGroups.first;
    final shift = (group != null && shiftsProv.hasRotationSlotForGroup(group.id))
        ? shiftsProv.getShiftForGroup(group.id, day)
        : ShiftType.rest;
    final shiftText = _shiftLabel(shift);
    final memberIds = group?.membreIds.toSet() ?? <String>{};
    final membersById = {
      for (final e in employeesProv.employes) e.id: e,
    };

    return FutureBuilder(
      future: context.read<OvertimeProvider>().getForDateRange(day, day),
      builder: (context, snap) {
        final assignments = (snap.data ?? const [])
            .where((a) => memberIds.contains(a.employeId))
            .toList()
          ..sort((a, b) => a.employeNom.compareTo(b.employeNom));

        return SingleChildScrollView(
          padding: EdgeInsets.all(padding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Dashboard Distribution',
                        style: TextStyle(
                          fontSize: mobile ? 18 : 21,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text('Responsable: ${auth.currentUser?.nom ?? '-'}'),
                      Text('Groupe: ${group?.nom ?? '-'}'),
                      Text('Shift aujourd\'hui: $shiftText'),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ElevatedButton.icon(
                            onPressed: () {
                              layoutState?._openPageByKeyFromDashboard('distribution_demandes');
                            },
                            icon: const Icon(Icons.event_note),
                            label: const Text('Envoyer demande congé'),
                          ),
                          OutlinedButton.icon(
                            onPressed: () {
                              layoutState?._openPageByKeyFromDashboard('distribution_pointage');
                            },
                            icon: const Icon(Icons.access_time),
                            label: const Text('Ouvrir pointage'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Salariés programmés en heures supplémentaires',
                        style: TextStyle(
                          fontSize: mobile ? 15 : 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (group == null)
                        Text('Aucun groupe Distribution lié.', style: TextStyle(color: Colors.grey[700]))
                      else if (assignments.isEmpty)
                        Text('Aucun salarié HS pour aujourd\'hui.', style: TextStyle(color: Colors.grey[700]))
                      else
                        ...assignments.map((a) {
                          final emp = membersById[a.employeId];
                          return ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.person_outline),
                            title: Text(a.employeNom),
                            subtitle: Text(
                              'CIN: ${emp?.cin ?? '-'}  •  Équipe cible: ${a.targetEquipeName}',
                            ),
                            trailing: Text(
                              a.attendanceStatus == OvertimeAttendanceStatus.absent
                                  ? 'Absent'
                                  : a.finished
                                      ? 'Terminé'
                                      : 'Prévu',
                            ),
                          );
                        }),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
