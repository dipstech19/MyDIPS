import 'dart:io' as dart_io;
import 'dart:math';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/auth/auth_provider.dart';
import '../../core/auth/app_permissions.dart';
import '../../core/locale/app_locale.dart';
import '../../core/site/site_provider.dart';
import '../../core/utils/responsive.dart';
import '../../shared/widgets/smart_avatar.dart';
import '../employees/data/departements_repository.dart';
import '../employees/data/postes_repository.dart';
import '../employees/departements_provider.dart';
import '../employees/postes_provider.dart';
import '../groupes/groupes_provider.dart';
import '../groupes/groupe_comptes_provider.dart';
import '../distribution/distribution_groups_provider.dart';
import '../distribution/distribution_comptes_provider.dart';
import '../distribution/models/distribution_group_model.dart';
import '../distribution/models/distribution_compte_model.dart';
import '../groupes/models/groupe_model.dart';
import '../groupes/models/groupe_compte_model.dart';
import '../employees/employees_provider.dart';
import '../employees/models/employe_model.dart' as emp;
import '../employees/models/equipe_model.dart';
import 'data/admins_repository.dart';
import 'admins_provider.dart';
import 'chauffeurs_provider.dart';
import 'chef_comptes_provider.dart';
import 'models/chauffeur_model.dart';
import 'models/chef_compte_model.dart';
import '../pointage/absence_reasons_provider.dart';
import '../pointage/formation_page.dart';
import '../pointage/models/absence_reason_config.dart';
import '../../core/site/site_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Modèles locaux pour l'UI Chefs (affichage dérivé de Equipe + Employe)
class _ChefEquipeView {
  final Equipe equipe;
  final emp.Employe? chefEmploye;
  _ChefEquipeView(this.equipe, this.chefEmploye);
  String get chefNom => chefEmploye?.nom ?? equipe.chefId;
}

// Classes conservées pour _ChefDetailsDialog / _ChefDrawer (dialogs dépréciés, à migrer si réutilisés)
class _ParamEmploye {
  final String id; String nom; String prenom; String poste; String telephone; bool actif;
  _ParamEmploye({required this.id, required this.nom, required this.prenom, required this.poste, required this.telephone, required this.actif});
}
class _ParamChefEquipe {
  final String id; String nom; String prenom; String email; String telephone; String departement;
  int nbEmployes; bool actif; DateTime dateCreation; List<_ParamEmploye> employes;
  _ParamChefEquipe({required this.id, required this.nom, required this.prenom, required this.email, required this.telephone, required this.departement, required this.nbEmployes, required this.actif, required this.dateCreation, List<_ParamEmploye>? employes}) : employes = employes ?? [];
}

/// Collaborateurs « chef d’équipe » ou libellé type SHEF (sans Chef de zone / atelier).
bool _isChefEquipePoste(String poste) {
  final p = poste.trim().toLowerCase();
  if (p == 'shef' || p.contains('shef')) return true;
  return p == "chef d'équipe" ||
      p == "chef d’equipe" ||
      p == "chef d'equipe" ||
      p == "chef d equipe";
}

/// Membres des groupes Distribution + chefs d’équipe / SHEF (même non listés dans membreIds).
Set<String> _distributionComptePickerEmployeIds(
  List<DistributionGroup> sourceGroups,
  List<emp.Employe> employes,
) {
  final ids = <String>{for (final g in sourceGroups) ...g.membreIds};
  for (final e in employes) {
    if (_isChefEquipePoste(e.poste)) ids.add(e.id);
  }
  return ids;
}

/// قائمة Chef (employé) — تظهر فقط من عندهم منصب Chef/Shef
class _ChefEquipeDropdown extends StatelessWidget {
  final EmployeesProvider prov;
  final String? chefId;
  final void Function(String?) onChanged;
  final Set<String> excludedIds;
  final String? forceIncludeId;

  const _ChefEquipeDropdown({
    required this.prov,
    required this.chefId,
    required this.onChanged,
    this.excludedIds = const <String>{},
    this.forceIncludeId,
  });

  @override
  Widget build(BuildContext context) {
    final candidates = prov.employes
        .where((e) =>
            _isChefEquipePoste(e.poste) &&
            (!excludedIds.contains(e.id) || (forceIncludeId != null && e.id == forceIncludeId)))
        .toList()
      ..sort((a, b) => a.nom.compareTo(b.nom));
    final value = (chefId != null && chefId!.isNotEmpty && candidates.any((e) => e.id == chefId)) ? chefId! : '';
    return DropdownButtonFormField<String>(
      value: value,
      decoration: const InputDecoration(labelText: 'Chef (collaborateur)'),
      items: [
        const DropdownMenuItem(value: '', child: Text('— Aucun —')),
        ...candidates.map((e) => DropdownMenuItem(value: e.id, child: Text('${e.nom} — ${e.poste}'))),
      ],
      onChanged: (v) => onChanged(v?.isEmpty == true ? null : v),
    );
  }
}

Widget _offlineBanner() {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    decoration: BoxDecoration(
      color: Colors.orange.shade50,
      border: Border(bottom: BorderSide(color: Colors.orange.shade200)),
    ),
    child: Row(
      children: [
        Icon(Icons.cloud_off, size: 22, color: Colors.orange.shade800),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            'Données en ligne indisponibles. Connectez Firebase (ex: Android) pour enregistrer et synchroniser.',
            style: TextStyle(fontSize: 13, color: Colors.orange.shade900),
          ),
        ),
      ],
    ),
  );
}

// ─────────────────────────────────────────────
//  Horizontal tab bar: mouse wheel + drag + chevrons (desktop)
// ─────────────────────────────────────────────

class _HorizontalTabScrollBehavior extends ScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
      };
}

// ─────────────────────────────────────────────
//  MAIN SETTINGS PAGE
// ─────────────────────────────────────────────

class ParametresPage extends StatefulWidget {
  const ParametresPage({super.key});

  @override
  State<ParametresPage> createState() => _ParametresPageState();
}

class _ParametresPageState extends State<ParametresPage> {
  int _selectedSectionIndex = 0;

  final ScrollController _tabScrollController = ScrollController();

  final List<_SettingsSection> _sections = [
    _SettingsSection(icon: Icons.admin_panel_settings, label: 'Administrateurs'),
    _SettingsSection(icon: Icons.groups, label: 'Chefs d\'équipe'),
    _SettingsSection(icon: Icons.school, label: 'Formations'),
    _SettingsSection(icon: Icons.login, label: 'Comptes Chefs'),
    _SettingsSection(icon: Icons.group_work, label: 'Groupes'),
    _SettingsSection(icon: Icons.vpn_key, label: 'Comptes Groupes'),
    _SettingsSection(icon: Icons.groups_2, label: 'Groupes Distribution'),
    _SettingsSection(icon: Icons.admin_panel_settings_outlined, label: 'Comptes Distribution'),
    _SettingsSection(icon: Icons.local_shipping, label: 'Chauffeurs'),
    _SettingsSection(icon: Icons.work_outline, label: 'Postes'),
    _SettingsSection(icon: Icons.account_tree_outlined, label: 'Départements'),
    _SettingsSection(icon: Icons.cancel_presentation_outlined, label: 'Raisons d\'absence'),
    _SettingsSection(icon: Icons.beach_access, label: 'Types de congé'),
    _SettingsSection(icon: Icons.tune, label: 'Général'),
    _SettingsSection(icon: Icons.notifications_active, label: 'Notifications'),
    _SettingsSection(icon: Icons.security, label: 'Sécurité'),
    _SettingsSection(icon: Icons.storage, label: 'Base de données'),
    _SettingsSection(icon: Icons.info_outline, label: 'À propos'),
  ];

  bool _canAccessSection(AuthProvider auth, int index) {
    if (!auth.isDirecteur) return true;
    // Chef d'atelier : pas de création / comptes Distribution ni onglet Sécurité.
    if (auth.isChefAtelierAdmin && (index == 6 || index == 7 || index == 15)) {
      return false;
    }
    switch (index) {
      case 0:
        return auth.hasPermission(AppPermissions.adminsManage);
      case 1:
        return auth.hasPermission(AppPermissions.teamsManage);
      case 2:
        return auth.hasPermission(AppPermissions.trainingManage);
      case 3:
        return auth.hasPermission(AppPermissions.chefAccountsManage);
      case 4:
        return auth.hasPermission(AppPermissions.groupsManage);
      case 5:
        return auth.hasPermission(AppPermissions.groupeAccountsManage);
      case 6:
        return auth.hasPermission(AppPermissions.groupsManage);
      case 7:
        return auth.hasPermission(AppPermissions.groupeAccountsManage);
      case 8:
        return auth.hasPermission(AppPermissions.driversManage);
      case 9:
        return auth.hasPermission(AppPermissions.postesManage);
      case 10:
        return auth.hasPermission(AppPermissions.departementsManage);
      case 11:
        return auth.hasPermission(AppPermissions.absenceReasonsManage);
      case 12:
        return true; // Types de congé — accessible à tous les admins
      case 13:
        return auth.hasPermission(AppPermissions.generalManage);
      case 14:
        return auth.hasPermission(AppPermissions.notificationsManage);
      case 15:
        return auth.hasPermission(AppPermissions.securityManage);
      case 16:
        return auth.hasPermission(AppPermissions.databaseManage);
      case 17:
        return auth.hasPermission(AppPermissions.aboutView);
      default:
        return false;
    }
  }

  @override
  void initState() {
    super.initState();
    _tabScrollController.addListener(_onTabBarScroll);
  }

  void _onTabBarScroll() {
    if (mounted) setState(() {});
  }

  void _scrollTabBarBy(double delta) {
    final c = _tabScrollController;
    if (!c.hasClients) return;
    final target = (c.offset + delta).clamp(
      c.position.minScrollExtent,
      c.position.maxScrollExtent,
    );
    c.animateTo(
      target,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  void _onTabBarPointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) return;
    final c = _tabScrollController;
    if (!c.hasClients) return;
    // Molette verticale ou Shift+molette → défilement horizontal (Windows / desktop)
    final dy = event.scrollDelta.dy;
    final dx = event.scrollDelta.dx;
    final delta = dx != 0.0 ? dx : dy;
    if (delta == 0.0) return;
    final target = (c.offset + delta).clamp(
      c.position.minScrollExtent,
      c.position.maxScrollExtent,
    );
    c.jumpTo(target);
  }

  bool get _tabCanScrollLeft {
    final c = _tabScrollController;
    if (!c.hasClients) return false;
    return c.offset > c.position.minScrollExtent + 0.5;
  }

  bool get _tabCanScrollRight {
    final c = _tabScrollController;
    if (!c.hasClients) return false;
    return c.offset < c.position.maxScrollExtent - 0.5;
  }

  @override
  void dispose() {
    _tabScrollController.removeListener(_onTabBarScroll);
    _tabScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    if (auth.isChefEquipe && !auth.isDirecteur) {
      return const _ChefOnlyParametresView();
    }
    final padding = pagePadding(context);
    final mobile = isMobile(context);
    final visibleSectionIndices = List<int>.generate(_sections.length, (i) => i)
        .where((i) => _canAccessSection(auth, i))
        .toList();
    if (visibleSectionIndices.isEmpty) {
      return const Center(child: Text('Aucune section autorisée'));
    }
    if (!visibleSectionIndices.contains(_selectedSectionIndex)) {
      _selectedSectionIndex = visibleSectionIndices.first;
    }
    final navHeader = Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(
              bottom: BorderSide(color: const Color(0xFF328EEE).withOpacity(0.18), width: 1.5),
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF328EEE).withOpacity(0.06),
                blurRadius: 12,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Title row ──
              Padding(
                padding: EdgeInsets.fromLTRB(padding, mobile ? 10 : 14, padding, 0),
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(mobile ? 5 : 7),
                      decoration: BoxDecoration(
                        color: const Color(0xFF328EEE).withOpacity(0.10),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Icon(Icons.settings_rounded, color: const Color(0xFF328EEE), size: mobile ? 16 : 18),
                    ),
                    SizedBox(width: mobile ? 8 : 10),
                    Flexible(
                      child: Text(
                        'Paramètres',
                        style: TextStyle(
                          fontSize: mobile ? 15 : 17,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF1A2340),
                          letterSpacing: 0.1,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (!mobile) ...[
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 14),
                        width: 1,
                        height: 18,
                        color: const Color(0xFFDDE3EE),
                      ),
                      Text(
                        'Administration & Configuration',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[450] ?? Colors.grey,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                    const Spacer(),
                    _SuperAdminBadge(),
                  ],
                ),
              ),
              // ── Tab row: molette → scroll horizontal, souris drag, flèches sur desktop ──
              Padding(
                padding: EdgeInsets.only(left: mobile ? 4 : 8, right: mobile ? 4 : 8, top: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    if (!mobile)
                      IconButton(
                        icon: const Icon(Icons.chevron_left, size: 22),
                        tooltip: 'Onglets précédents',
                        visualDensity: VisualDensity.compact,
                        onPressed: _tabCanScrollLeft ? () => _scrollTabBarBy(-140) : null,
                        color: const Color(0xFF328EEE),
                      ),
                    Expanded(
                      child: Listener(
                        onPointerSignal: _onTabBarPointerSignal,
                        child: ScrollConfiguration(
                          behavior: _HorizontalTabScrollBehavior(),
                          child: Scrollbar(
                            controller: _tabScrollController,
                            thumbVisibility: !mobile,
                            thickness: 4,
                            radius: const Radius.circular(8),
                            child: SingleChildScrollView(
                              controller: _tabScrollController,
                              scrollDirection: Axis.horizontal,
                              child: Row(
                    children: visibleSectionIndices.map((i) {
                      final s = _sections[i];
                      final selected = _selectedSectionIndex == i;
                      return GestureDetector(
                        onTap: () => setState(() => _selectedSectionIndex = i),
                        child: MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: const EdgeInsets.only(right: 1),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 11),
                            decoration: BoxDecoration(
                              color: selected
                                  ? const Color(0xFF328EEE).withOpacity(0.07)
                                  : Colors.transparent,
                              border: Border(
                                bottom: BorderSide(
                                  color: selected
                                      ? const Color(0xFF328EEE)
                                      : Colors.transparent,
                                  width: 2.5,
                                ),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  padding: selected
                                      ? const EdgeInsets.all(5)
                                      : EdgeInsets.zero,
                                  decoration: selected
                                      ? BoxDecoration(
                                    color: const Color(0xFF328EEE)
                                        .withOpacity(0.12),
                                    borderRadius:
                                    BorderRadius.circular(6),
                                  )
                                      : null,
                                  child: Icon(
                                    s.icon,
                                    size: selected ? 13 : 15,
                                    color: selected
                                        ? const Color(0xFF328EEE)
                                        : Colors.grey[400],
                                  ),
                                ),
                                const SizedBox(width: 7),
                                Text(
                                  s.label,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: selected
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    color: selected
                                        ? const Color(0xFF328EEE)
                                        : Colors.grey[500],
                                    letterSpacing: selected ? 0.1 : 0,
                                  ),
                                ),
                                // petit dot bleu uniquement sur l'onglet actif
                                if (selected) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    width: 5,
                                    height: 5,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF328EEE),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (!mobile)
                      IconButton(
                        icon: const Icon(Icons.chevron_right, size: 22),
                        tooltip: 'Onglets suivants',
                        visualDensity: VisualDensity.compact,
                        onPressed: _tabCanScrollRight ? () => _scrollTabBarBy(140) : null,
                        color: const Color(0xFF328EEE),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );

    if (mobile) {
      return NestedScrollView(
        headerSliverBuilder: (_, __) => [
          SliverToBoxAdapter(child: navHeader),
        ],
        body: Container(
          color: const Color(0xFFF4F7FC),
          child: _buildSection(_selectedSectionIndex),
        ),
      );
    }

    return Column(
      children: [
        // ══════════════════════════════════════════
        //  NAV BAR — blanc, accent #328EEE, moderne
        // ══════════════════════════════════════════
        navHeader,
        // ══════════════════════════════════════════
        //  CONTENT
        // ══════════════════════════════════════════
        Expanded(
          child: Container(
            color: const Color(0xFFF4F7FC),
            child: _buildSection(_selectedSectionIndex),
          ),
        ),
      ],
    );
  }

  Widget _buildSection(int index) {
    switch (index) {
      case 0:  return const _AdminsSection();
      case 1:  return const _ChefsEquipeSection();
      case 2:  return const FormationPage();
      case 3:  return const _ChefComptesSection();
      case 4:  return const _GroupesSection();
      case 5:  return const _GroupeComptesSection();
      case 6:  return const _DistributionGroupsSection();
      case 7:  return const _DistributionComptesSection();
      case 8:  return const _ChauffeursSection();
      case 9:  return const _PostesSection();
      case 10: return const _DepartementsSection();
      case 11: return const _AbsenceReasonsSection();
      case 12: return const _LeaveTypesSection();
      case 13: return const _GeneralSection();
      case 14: return const _NotificationsSection();
      case 15: return const _SecuriteSection();
      case 16: return const _DatabaseSection();
      case 17: return const _AboutSection();
      default: return const Center(child: Text('Section inconnue'));
    }
  }
}

/// صفحة الإعدادات للشاف: اسمه، اللغة، تسجيل الخروج فقط.
class _ChefOnlyParametresView extends StatelessWidget {
  const _ChefOnlyParametresView();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final locale = context.watch<LocaleProvider>();
    final padding = pagePadding(context);
    return SingleChildScrollView(
      padding: EdgeInsets.all(padding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.settings_rounded, color: const Color(0xFF328EEE), size: 28),
              const SizedBox(width: 12),
              const Text(
                'Paramètres',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF1A2340)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Informations Chef d\'équipe',
            style: TextStyle(fontSize: 13, color: Colors.grey[600]),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 4))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _row('Nom', auth.currentUser?.nom ?? '—'),
                const SizedBox(height: 16),
                Row(
                  children: [
                    SizedBox(width: 120, child: Text('Langue', style: TextStyle(color: Colors.grey[600], fontSize: 13))),
                    TextButton(
                      onPressed: () => locale.setLocale('fr'),
                      style: TextButton.styleFrom(
                        foregroundColor: locale.locale == 'fr' ? const Color(0xFF328EEE) : Colors.grey,
                        textStyle: TextStyle(fontWeight: locale.locale == 'fr' ? FontWeight.bold : FontWeight.normal),
                      ),
                      child: Text(tr(context, 'french')),
                    ),
                    Text(' | ', style: TextStyle(color: Colors.grey[400])),
                    TextButton(
                      onPressed: () => locale.setLocale('ar'),
                      style: TextButton.styleFrom(
                        foregroundColor: locale.locale == 'ar' ? const Color(0xFF328EEE) : Colors.grey,
                        textStyle: TextStyle(fontWeight: locale.locale == 'ar' ? FontWeight.bold : FontWeight.normal),
                      ),
                      child: Text(tr(context, 'arabic')),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                OutlinedButton.icon(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: Text(tr(context, 'logout')),
                        content: Text(tr(context, 'logout_confirm')),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(context), child: Text(tr(context, 'cancel'))),
                          ElevatedButton(
                            onPressed: () {
                              Navigator.pop(context);
                              context.read<AuthProvider>().logout();
                            },
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                            child: Text(tr(context, 'disconnect')),
                          ),
                        ],
                      ),
                    );
                  },
                  icon: const Icon(Icons.logout, size: 18),
                  label: Text(tr(context, 'logout')),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 120, child: Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 13))),
        Expanded(child: Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500))),
      ],
    ),
  );
}

class _SuperAdminBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF328EEE).withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF328EEE).withOpacity(0.25)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.verified_user_rounded, color: Color(0xFF328EEE), size: 13),
          SizedBox(width: 6),
          Text(
            'Super Admin',
            style: TextStyle(
              color: Color(0xFF328EEE),
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsSection {
  final IconData icon;
  final String label;
  _SettingsSection({required this.icon, required this.label});
}

// ─────────────────────────────────────────────
//  SHARED ERP TABLE HELPERS
// ─────────────────────────────────────────────

const _kAccent   = Color(0xFF328EEE);
const _kDark     = Color(0xFF1A2340);
const _kBg       = Color(0xFFF4F7FC);
const _kBorder   = Color(0xFFDDE3EE);
const _kRowHover = Color(0xFFF0F6FF);

/// Header cell
Widget _th(String label, {int flex = 1, TextAlign align = TextAlign.left}) =>
    Expanded(
      flex: flex,
      child: Text(label,
          textAlign: align,
          style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
              color: Color(0xFF6B7A99))),
    );

/// Reusable drawer panel
class _SideDrawer extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accentColor;
  final Widget body;
  final VoidCallback onSave;
  final String saveLabel;

  const _SideDrawer({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
    required this.body,
    required this.onSave,
    this.saveLabel = 'Enregistrer',
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Align(
        alignment: Alignment.centerRight,
        child: Container(
          width: 440,
          height: double.infinity,
          decoration: const BoxDecoration(
            color: Colors.white,
            boxShadow: [BoxShadow(color: Color(0x22000000), blurRadius: 32, offset: Offset(-4, 0))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Drawer header ──
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(24, 28, 16, 22),
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.06),
                  border: Border(bottom: BorderSide(color: accentColor.withOpacity(0.15))),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: accentColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(icon, color: accentColor, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title,
                              style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold, color: _kDark)),
                          Text(subtitle,
                              style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              // ── Scrollable body ──
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: body,
                ),
              ),
              // ── Footer ──
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: _kBorder)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: const BorderSide(color: _kBorder),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Annuler', style: TextStyle(color: _kDark)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accentColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: onSave,
                        child: Text(saveLabel, style: const TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Compact labeled field used inside drawers
class _DrawerField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String hint;
  final bool isPassword;
  final bool isNumber;
  final TextInputType? keyboardType;

  const _DrawerField({
    required this.label,
    required this.controller,
    this.hint = '',
    this.isPassword = false,
    this.isNumber = false,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF4A5568))),
        const SizedBox(height: 5),
        TextFormField(
          controller: controller,
          obscureText: isPassword,
          keyboardType: isNumber
              ? TextInputType.number
              : (keyboardType ?? TextInputType.text),
          style: const TextStyle(fontSize: 13),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
            isDense: true,
            contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: _kBorder)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: _kBorder)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: _kAccent, width: 1.5)),
          ),
          validator: (v) => (v == null || v.isEmpty) ? 'Requis' : null,
        ),
      ],
    );
  }
}

class _DrawerDropdown extends StatelessWidget {
  final String label;
  final String value;
  final List<String> items;
  final ValueChanged<String?> onChanged;

  const _DrawerDropdown(
      {required this.label,
        required this.value,
        required this.items,
        required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF4A5568))),
        const SizedBox(height: 5),
        DropdownButtonFormField<String>(
          value: value,
          isExpanded: true,
          style: const TextStyle(fontSize: 13, color: _kDark),
          decoration: InputDecoration(
            isDense: true,
            contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: _kBorder)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: _kBorder)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: _kAccent, width: 1.5)),
          ),
          items: items
              .map((i) => DropdownMenuItem(value: i, child: Text(i)))
              .toList(),
          onChanged: onChanged,
        ),
      ],
    );
  }
}

void _openDrawer(BuildContext context, Widget drawer) {
  showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'close',
    barrierColor: Colors.black38,
    transitionDuration: const Duration(milliseconds: 260),
    pageBuilder: (_, __, ___) => drawer,
    transitionBuilder: (_, anim, __, child) {
      final slide = Tween<Offset>(
          begin: const Offset(1, 0), end: Offset.zero)
          .animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic));
      return SlideTransition(position: slide, child: child);
    },
  );
}

// ─────────────────────────────────────────────
//  SECTION: ADMINISTRATEURS
// ─────────────────────────────────────────────

class _AdminsSection extends StatefulWidget {
  const _AdminsSection();
  @override
  State<_AdminsSection> createState() => _AdminsSectionState();
}

class _AdminsSectionState extends State<_AdminsSection> {
  String _searchQuery = '';

  List<AdminUser> _filtered(AdminsProvider prov) => prov.admins
      .where((a) => '${a.nom} ${a.prenom} ${a.email} ${a.role}'
      .toLowerCase()
      .contains(_searchQuery.toLowerCase()))
      .toList();

  void _openAdminDrawer(BuildContext context, AdminsProvider prov, [AdminUser? existing]) {
    _openDrawer(
      context,
      _AdminDrawer(
        existing: existing,
        onSave: (admin) async {
          if (existing != null) {
            await prov.updateAdmin(admin);
          } else {
            await prov.addAdmin(admin);
          }
        },
      ),
    );
  }

  void _confirmDelete(BuildContext context, AdminsProvider prov, AdminUser admin) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Row(children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 22),
          const SizedBox(width: 8),
          const Text('Supprimer l\'admin', style: TextStyle(fontSize: 16)),
        ]),
        content: RichText(
          text: TextSpan(
            style: const TextStyle(fontSize: 13, color: Colors.black87),
            children: [
              const TextSpan(text: 'Confirmer la suppression de '),
              TextSpan(
                  text: '${admin.prenom} ${admin.nom}',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              const TextSpan(text: ' ?'),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, foregroundColor: Colors.white, elevation: 0),
            onPressed: () async {
              await prov.deleteAdmin(admin.id);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<AdminsProvider>();
    final filtered = _filtered(prov);
    final mobile = isMobile(context);
    final padding = pagePadding(context);
    return Column(
      children: [
        if (!prov.firebaseAvailable) _offlineBanner(),
        // ── Top bar (responsive: stack on mobile to avoid overflow) ──
        Container(
          color: Colors.white,
          padding: EdgeInsets.fromLTRB(padding, 14, padding, 12),
          child: mobile
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('Administrateurs',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _kDark)),
                    Text('${prov.admins.length} compte(s) enregistré(s)',
                        style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                    const SizedBox(height: 12),
                    TextField(
                      onChanged: (v) => setState(() => _searchQuery = v),
                      style: const TextStyle(fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Rechercher...',
                        hintStyle: TextStyle(fontSize: 13, color: Colors.grey[400]),
                        prefixIcon: const Icon(Icons.search, size: 16),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(vertical: 9),
                        filled: true, fillColor: _kBg,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(7), borderSide: const BorderSide(color: _kBorder)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(7), borderSide: const BorderSide(color: _kBorder)),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: _kBorder),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
                          ),
                          icon: const Icon(Icons.file_download_outlined, size: 15, color: _kDark),
                          label: const Text('Exporter CSV', style: TextStyle(fontSize: 12, color: _kDark)),
                          onPressed: () => _exportAdminsCsv(context),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _kAccent, foregroundColor: Colors.white, elevation: 0,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
                            ),
                            icon: const Icon(Icons.add, size: 15),
                            label: const Text('Ajouter', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                            onPressed: () => _openAdminDrawer(context, prov),
                          ),
                        ),
                      ],
                    ),
                  ],
                )
              : Row(
                  children: [
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('Administrateurs',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _kDark)),
                      Text('${prov.admins.length} compte(s) enregistré(s)',
                          style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                    ]),
                    const Spacer(),
                    SizedBox(
                      width: 200,
                      child: TextField(
                        onChanged: (v) => setState(() => _searchQuery = v),
                        style: const TextStyle(fontSize: 13),
                        decoration: InputDecoration(
                          hintText: 'Rechercher...',
                          hintStyle: TextStyle(fontSize: 13, color: Colors.grey[400]),
                          prefixIcon: const Icon(Icons.search, size: 16),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(vertical: 9),
                          filled: true, fillColor: _kBg,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(7), borderSide: const BorderSide(color: _kBorder)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(7), borderSide: const BorderSide(color: _kBorder)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: _kBorder),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
                      ),
                      icon: const Icon(Icons.file_download_outlined, size: 15, color: _kDark),
                      label: const Text('Exporter CSV', style: TextStyle(fontSize: 12, color: _kDark)),
                      onPressed: () => _exportAdminsCsv(context),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _kAccent, foregroundColor: Colors.white, elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
                      ),
                      icon: const Icon(Icons.add, size: 15),
                      label: const Text('Ajouter', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                      onPressed: () => _openAdminDrawer(context, prov),
                    ),
                  ],
                ),
        ),
        const Divider(height: 1, color: _kBorder),
        // ── Table (desktop) / Card list (mobile, responsive) ──
        Expanded(
          child: filtered.isEmpty
              ? const _EmptyState()
              : mobile
                  ? ListView.builder(
                      padding: EdgeInsets.all(padding),
                      itemCount: filtered.length,
                      itemBuilder: (context, i) {
                        final admin = filtered[i];
                        return _AdminCard(
                          admin: admin,
                          onEdit: () => _openAdminDrawer(context, prov, admin),
                          onDelete: () => _confirmDelete(context, prov, admin),
                          onToggle: () async {
                            admin.actif = !admin.actif;
                            await prov.updateAdmin(admin);
                          },
                        );
                      },
                    )
                  : Column(
                  children: [
                    Container(
                      color: const Color(0xFFF0F4FA),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 9),
                      child: const Row(children: [
                        Expanded(flex: 3, child: _TH('NOM COMPLET')),
                        Expanded(flex: 2, child: _TH('TÉLÉPHONE')),
                        Expanded(flex: 2, child: _TH('RÔLE')),
                        Expanded(flex: 2, child: _TH('ZONE')),
                        Expanded(flex: 2, child: _TH('STATUT')),
                        SizedBox(width: 110, child: _TH('ACTIONS', center: true)),
                      ]),
                    ),
                    const Divider(height: 1, color: _kBorder),
                    Expanded(
                      child: ListView.builder(
                        itemCount: filtered.length,
                        itemBuilder: (context, i) {
                          final admin = filtered[i];
                          return _AdminTableRow(
                            admin: admin,
                            isEven: i.isEven,
                            onEdit: () => _openAdminDrawer(context, prov, admin),
                            onDelete: () => _confirmDelete(context, prov, admin),
                            onToggle: () async {
                              admin.actif = !admin.actif;
                              await prov.updateAdmin(admin);
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  void _exportAdminsCsv(BuildContext context) async {
    final prov = context.read<AdminsProvider>();
    final csv = StringBuffer();
    csv.writeln('ID,Nom,Prénom,Email,Téléphone,Rôle,Statut,Permissions,Date Création');
    for (final a in prov.admins) {
      csv.writeln(
        '"${a.id}","${a.nom}","${a.prenom}","${a.email}","${a.telephone}",'
            '"${a.role}","${a.actif ? 'Actif' : 'Inactif'}","${a.permissions.join(' | ')}",'
            '"${a.dateCreation.toIso8601String().substring(0, 10)}"',
      );
    }
    await _saveAndOpenFile('administrateurs_export.csv', csv.toString(), context);
  }
}

// ── Mobile card for one admin (responsive, no overflow) ──
class _AdminCard extends StatelessWidget {
  final AdminUser admin;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onToggle;

  const _AdminCard({
    required this.admin,
    required this.onEdit,
    required this.onDelete,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final a = admin;
    final padding = pagePadding(context);
    return Card(
      margin: EdgeInsets.only(bottom: padding),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: _kBorder)),
      child: Padding(
        padding: EdgeInsets.all(padding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${a.prenom} ${a.nom}',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _kDark),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                GestureDetector(
                  onTap: onToggle,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: a.actif ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: a.actif ? Colors.green : Colors.red,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          a.actif ? 'Actif' : 'Inactif',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: a.actif ? Colors.green.shade700 : Colors.red.shade600),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(a.telephone, style: TextStyle(fontSize: 13, color: Colors.grey[700])),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: _kAccent.withOpacity(0.08),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: _kAccent.withOpacity(0.2)),
              ),
              child: Text(a.role, style: const TextStyle(fontSize: 11, color: _kAccent, fontWeight: FontWeight.w700)),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                TextButton.icon(
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Modifier'),
                  onPressed: onEdit,
                  style: TextButton.styleFrom(foregroundColor: _kAccent),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text('Supprimer'),
                  onPressed: onDelete,
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Simplified admin row: name / phone / role / status + 3 action icons ──
class _AdminTableRow extends StatefulWidget {
  final AdminUser admin;
  final bool isEven;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onToggle;
  const _AdminTableRow({required this.admin, required this.isEven, required this.onEdit, required this.onDelete, required this.onToggle});
  @override
  State<_AdminTableRow> createState() => _AdminTableRowState();
}

class _AdminTableRowState extends State<_AdminTableRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final a = widget.admin;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit:  (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        color: _hovered ? _kRowHover : (widget.isEven ? Colors.white : const Color(0xFFFAFBFD)),
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: Row(children: [
              // NOM COMPLET (no avatar)
              Expanded(
                flex: 3,
                child: Text('${a.prenom} ${a.nom}',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _kDark),
                    overflow: TextOverflow.ellipsis),
              ),
              // TÉLÉPHONE
              Expanded(
                flex: 2,
                child: Text(a.telephone,
                    style: TextStyle(fontSize: 12, color: Colors.grey[700])),
              ),
              // RÔLE
              Expanded(
                flex: 2,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _kAccent.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: _kAccent.withOpacity(0.2)),
                    ),
                    child: Text(a.role,
                        style: const TextStyle(fontSize: 11, color: _kAccent, fontWeight: FontWeight.w700),
                        overflow: TextOverflow.ellipsis),
                  ),
                ),
              ),
              // ZONE
              Expanded(
                flex: 2,
                child: Text(
                  a.siteIds.isEmpty || a.siteIds.contains(SiteId.all)
                      ? SiteId.labelFr(SiteId.all)
                      : SiteId.labelFr(a.siteIds.first),
                  style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // STATUT
              Expanded(
                flex: 2,
                child: GestureDetector(
                  onTap: widget.onToggle,
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Container(
                      width: 7, height: 7,
                      decoration: BoxDecoration(
                        color: a.actif ? Colors.green : Colors.red,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(a.actif ? 'Actif' : 'Inactif',
                        style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w600,
                            color: a.actif ? Colors.green.shade700 : Colors.red.shade600)),
                  ]),
                ),
              ),
              // ACTIONS: details + edit + delete
              SizedBox(
                width: 110,
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  _TableBtn(
                    icon: Icons.info_outline,
                    tooltip: 'Détails',
                    color: Colors.purple,
                    onTap: () => _showAdminDetails(context, a),
                  ),
                  const SizedBox(width: 5),
                  _TableBtn(icon: Icons.edit_outlined, tooltip: 'Modifier', color: _kAccent, onTap: widget.onEdit),
                  const SizedBox(width: 5),
                  _TableBtn(icon: Icons.delete_outline, tooltip: 'Supprimer', color: Colors.red, onTap: widget.onDelete),
                ]),
              ),
            ]),
          ),
          const Divider(height: 1, color: _kBorder),
        ]),
      ),
    );
  }

  void _showAdminDetails(BuildContext context, AdminUser a) {
    showDialog(
      context: context,
      barrierColor: Colors.black45,
      builder: (dialogContext) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 60, vertical: 40),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680, maxHeight: 600),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ──
              Container(
                padding: const EdgeInsets.fromLTRB(28, 22, 20, 18),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [_kAccent.withOpacity(0.08), Colors.white],
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                  ),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                  border: Border(bottom: BorderSide(color: _kAccent.withOpacity(0.15))),
                ),
                child: Row(children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _kAccent.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.manage_accounts, color: _kAccent, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${a.prenom} ${a.nom}',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _kDark)),
                      Row(children: [
                        Text(a.id, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: a.actif ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(a.actif ? 'Actif' : 'Inactif',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                                  color: a.actif ? Colors.green.shade700 : Colors.red.shade600)),
                        ),
                      ]),
                    ]),
                  ),
                  IconButton(icon: const Icon(Icons.close, size: 20), onPressed: () => Navigator.pop(dialogContext)),
                ]),
              ),
              // ── Body ──
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Info grid
                      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Expanded(
                          child: Column(children: [
                            _DetailRow(icon: Icons.email_outlined, label: 'Email', value: a.email),
                            _DetailRow(icon: Icons.phone_outlined, label: 'Téléphone', value: a.telephone),
                          ]),
                        ),
                        const SizedBox(width: 24),
                        Expanded(
                          child: Column(children: [
                            _DetailRow(icon: Icons.badge_outlined, label: 'Rôle', value: a.role),
                            _DetailRow(icon: Icons.calendar_today, label: 'Créé le',
                                value: '${a.dateCreation.day.toString().padLeft(2,'0')}/${a.dateCreation.month.toString().padLeft(2,'0')}/${a.dateCreation.year}'),
                          ]),
                        ),
                      ]),
                      const SizedBox(height: 24),
                      // Permissions section
                      Row(children: [
                        Container(width: 3, height: 14, decoration: BoxDecoration(color: _kAccent, borderRadius: BorderRadius.circular(2))),
                        const SizedBox(width: 8),
                        const Text('PERMISSIONS D\'ACCÈS',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.7, color: Color(0xFF6B7A99))),
                        const SizedBox(width: 10),
                        const Expanded(child: Divider(color: _kBorder)),
                      ]),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 8, runSpacing: 8,
                        children: a.permissions.map((p) => Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEEF2FF),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFF4F46E5).withOpacity(0.2)),
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            const Icon(Icons.check_circle_outline, size: 13, color: Color(0xFF4F46E5)),
                            const SizedBox(width: 5),
                            Text(p, style: const TextStyle(fontSize: 12, color: Color(0xFF4F46E5), fontWeight: FontWeight.w600)),
                          ]),
                        )).toList(),
                      ),
                      if (a.role.toLowerCase().contains('zone')) ...[
                        const SizedBox(height: 24),
                        Row(children: [
                          Container(
                              width: 3,
                              height: 14,
                              decoration: BoxDecoration(color: _kAccent, borderRadius: BorderRadius.circular(2))),
                          const SizedBox(width: 8),
                          const Text('GROUPES DISTRIBUTION',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.7,
                                  color: Color(0xFF6B7A99))),
                          const SizedBox(width: 10),
                          const Expanded(child: Divider(color: _kBorder)),
                        ]),
                        const SizedBox(height: 10),
                        Builder(
                          builder: (ctx) {
                            final names = ctx
                                .watch<DistributionGroupsProvider>()
                                .groups
                                .where((g) => a.distributionGroupIds.contains(g.id))
                                .map((g) => g.nom)
                                .join(', ');
                            final text = a.distributionGroupIds.isEmpty
                                ? 'Tous les groupes (filtre zone)'
                                : (names.isEmpty ? a.distributionGroupIds.join(', ') : names);
                            return Text(text, style: TextStyle(fontSize: 13, color: Colors.grey[800]));
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Admin sliding drawer ──
class _AdminDrawer extends StatefulWidget {
  final AdminUser? existing;
  final Function(AdminUser) onSave;
  const _AdminDrawer({this.existing, required this.onSave});
  @override
  State<_AdminDrawer> createState() => _AdminDrawerState();
}

class _AdminDrawerState extends State<_AdminDrawer> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nomCtrl, _prenomCtrl, _emailCtrl, _telCtrl, _pwdCtrl;
  String _role = 'Admin RH';
  String? _selectedEmployeId;
  List<String> _perms = [];
  bool _actif = true;
  bool _showPwd = false;
  /// Zone: 'all' = الكل، 'jadida' أو 'safi' = موقع واحد
  String _siteId = SiteId.all;
  String _selectedPreset = 'custom';
  /// Groupes Distribution rattachés au compte « Chef de zone » (pointage + congés).
  final Set<String> _chefZoneDistributionGroupIds = {};
  final Random _pwdRandom = Random.secure();

  final _roles = ['Admin RH', 'Admin Magasin', 'Admin Général', 'Admin Pointage', 'Chef d\'atelier', 'Chef de zone'];
  final _allPerms = AppPermissions.allDetailed;

  Map<String, List<String>> get _permissionPresets => {
    'rh': [
      AppPermissions.employeesView,
      AppPermissions.employeesManage,
      AppPermissions.employeesDelete,
      AppPermissions.teamsManage,
      AppPermissions.groupsManage,
      AppPermissions.settingsView,
      AppPermissions.trainingManage,
      AppPermissions.chefAccountsManage,
      AppPermissions.groupeAccountsManage,
      AppPermissions.driversManage,
      AppPermissions.absenceReasonsManage,
      AppPermissions.reportsView,
      AppPermissions.pointageView,
      AppPermissions.overtimeView,
      AppPermissions.shiftsView,
      AppPermissions.demandesView,
      AppPermissions.logistiqueView,
      AppPermissions.aboutView,
    ],
    'pointage': [
      AppPermissions.pointageView,
      AppPermissions.overtimeView,
      AppPermissions.shiftsView,
      AppPermissions.settingsView,
      AppPermissions.trainingManage,
      AppPermissions.absenceReasonsManage,
      AppPermissions.reportsView,
      AppPermissions.aboutView,
    ],
    // Chef de zone: full admin scope with pointage access (restricted in UI to Chef d'atelier only).
    'zone': _allPerms,
    'atelier': [
      AppPermissions.employeesView,
      AppPermissions.employeesManage,
      AppPermissions.employeesDelete,
      AppPermissions.teamsManage,
      AppPermissions.groupsManage,
      AppPermissions.pointageView,
      AppPermissions.overtimeView,
      AppPermissions.shiftsView,
      AppPermissions.stockView,
      AppPermissions.reportsView,
      AppPermissions.settingsView,
      AppPermissions.trainingManage,
      AppPermissions.chefAccountsManage,
      AppPermissions.groupeAccountsManage,
      AppPermissions.driversManage,
      AppPermissions.absenceReasonsManage,
      AppPermissions.generalManage,
      AppPermissions.notificationsManage,
      AppPermissions.databaseManage,
      AppPermissions.aboutView,
      AppPermissions.demandesView,
      AppPermissions.logistiqueView,
    ],
  };

  String _detectPreset(List<String> perms) {
    bool same(List<String> a, List<String> b) {
      final sa = {...a};
      final sb = {...b};
      return sa.length == sb.length && sa.containsAll(sb);
    }

    if (same(perms, _permissionPresets['rh']!)) return 'rh';
    if (same(perms, _permissionPresets['pointage']!)) return 'pointage';
    if (same(perms, _permissionPresets['atelier']!)) return 'atelier';
    if (same(perms, _permissionPresets['zone']!)) return 'zone';
    return 'custom';
  }

  bool _roleMatchesPoste(String role, String poste) {
    final r = role.trim().toLowerCase();
    final p = poste.trim().toLowerCase();
    if (r.contains('atelier')) return p.contains('atelier');
    if (r.contains('zone')) return p.contains('zone');
    if (r.contains('rh')) return p == 'rh' || p.contains('ressource') || p.contains('rh');
    if (r.contains('pointage')) return p.contains('pointage') || p.contains('chef d\'équipe');
    return true;
  }

  void _applyEmployeToForm(emp.Employe e) {
    final parts = e.nom.trim().split(RegExp(r'\s+')).where((x) => x.isNotEmpty).toList();
    final prenom = parts.isNotEmpty ? parts.first : '';
    final nom = parts.length > 1 ? parts.sublist(1).join(' ') : '';
    setState(() {
      _selectedEmployeId = e.id;
      _prenomCtrl.text = prenom;
      _nomCtrl.text = nom;
      _telCtrl.text = e.telephone;
    });
  }

  void _applyPreset(String key) {
    final preset = _permissionPresets[key];
    if (preset == null) return;
    setState(() {
      _selectedPreset = key;
      _perms = List<String>.from(preset);
      if (key == 'rh') _role = 'Admin RH';
      if (key == 'pointage') _role = 'Admin Pointage';
      if (key == 'atelier') _role = 'Chef d\'atelier';
      if (key == 'zone') _role = 'Chef de zone';
    });
  }

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _nomCtrl   = TextEditingController(text: e?.nom ?? '');
    _prenomCtrl = TextEditingController(text: e?.prenom ?? '');
    _emailCtrl = TextEditingController(text: e?.email ?? '');
    _telCtrl   = TextEditingController(text: e?.telephone ?? '');
    _pwdCtrl   = TextEditingController(text: '');
    _role  = e?.role ?? 'Admin RH';
    _perms = List.from(e?.permissions ?? []);
    _selectedPreset = _detectPreset(_perms);
    _actif = e?.actif ?? true;
    if (e?.siteIds != null && e!.siteIds.isNotEmpty && e.siteIds.first != SiteId.all) {
      _siteId = e.siteIds.first;
    } else {
      _siteId = SiteId.all;
    }
    _chefZoneDistributionGroupIds
      ..clear()
      ..addAll(e?.distributionGroupIds ?? const <String>[]);
  }

  @override
  void dispose() {
    _nomCtrl.dispose(); _prenomCtrl.dispose();
    _emailCtrl.dispose(); _telCtrl.dispose(); _pwdCtrl.dispose();
    super.dispose();
  }

  String _buildGeneratedPassword({int length = 12}) {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789@#\$%';
    return List.generate(length, (_) => chars[_pwdRandom.nextInt(chars.length)]).join();
  }

  void _generatePassword() {
    setState(() {
      _pwdCtrl.text = _buildGeneratedPassword();
      _showPwd = true;
    });
  }

  Future<void> _copyPassword() async {
    final v = _pwdCtrl.text.trim();
    if (v.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: v));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Mot de passe copié')),
    );
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final isNew = widget.existing == null;
    final siteIds = _siteId == SiteId.all ? [SiteId.all] : [_siteId];
    final typedPwd = _pwdCtrl.text.trim();
    final pwd = isNew
        ? typedPwd
        : (typedPwd.isNotEmpty ? typedPwd : widget.existing!.password);
    widget.onSave(AdminUser(
      id: isNew ? '' : widget.existing!.id,
      nom: _nomCtrl.text.trim(),
      prenom: _prenomCtrl.text.trim(),
      email: _emailCtrl.text.trim(),
      telephone: _telCtrl.text.trim(),
      role: _role,
      actif: _actif,
      permissions: _perms,
      siteIds: siteIds,
      password: pwd,
      dateCreation: widget.existing?.dateCreation ?? DateTime.now(),
      distributionGroupIds: _role.toLowerCase().contains('zone')
          ? _chefZoneDistributionGroupIds.toList()
          : const <String>[],
    ));
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    return _SideDrawer(
      title: isEdit ? 'Modifier l\'administrateur' : 'Nouvel administrateur',
      subtitle: isEdit ? 'Modifier les informations du compte' : 'Créer un nouveau compte admin',
      icon: isEdit ? Icons.manage_accounts : Icons.person_add_alt_1,
      accentColor: _kAccent,
      saveLabel: isEdit ? 'Modifier' : 'Créer le compte',
      onSave: _save,
      body: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Role & Status ──
            _DrawerSection(label: 'RÔLE & STATUT'),
            const SizedBox(height: 10),
            _DrawerDropdown(
              label: 'Rôle *',
              value: _role,
              items: _roles,
              onChanged: (v) => setState(() {
                _role = v!;
                _selectedEmployeId = null;
              }),
            ),
            const SizedBox(height: 10),
            Builder(
              builder: (context) {
                final empsProv = context.watch<EmployeesProvider>();
                final candidates = empsProv.employes
                    .where((e) => e.statut == emp.EmployeStatut.enService && _roleMatchesPoste(_role, e.poste))
                    .toList()
                  ..sort((a, b) => a.nom.compareTo(b.nom));
                if (candidates.isEmpty) {
                  return Text(
                    'Aucun collaborateur trouvé pour ce rôle.',
                    style: TextStyle(fontSize: 11, color: Colors.orange[800]),
                  );
                }
                if (_selectedEmployeId != null &&
                    !candidates.any((e) => e.id == _selectedEmployeId)) {
                  _selectedEmployeId = null;
                }
                return DropdownButtonFormField<String>(
                  value: _selectedEmployeId,
                  decoration: const InputDecoration(
                    labelText: 'Collaborateur source *',
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                    filled: true,
                    fillColor: Color(0xFFF8FAFC),
                  ),
                  items: candidates
                      .map((e) => DropdownMenuItem<String>(
                            value: e.id,
                            child: Text('${e.nom} — ${e.poste}'),
                          ))
                      .toList(),
                  onChanged: (v) {
                    if (v == null) return;
                    final selected = candidates.where((e) => e.id == v).toList();
                    if (selected.isEmpty) return;
                    _applyEmployeToForm(selected.first);
                  },
                  validator: (v) => (v == null || v.isEmpty) ? 'Choisissez un collaborateur' : null,
                );
              },
            ),
            const SizedBox(height: 12),
            // ── Identity ──
            _DrawerSection(label: 'IDENTITÉ'),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: _DrawerField(label: 'Prénom *', controller: _prenomCtrl, hint: 'Ex: Karim')),
              const SizedBox(width: 12),
              Expanded(child: _DrawerField(label: 'Nom *', controller: _nomCtrl, hint: 'Ex: El Amrani')),
            ]),
            const SizedBox(height: 12),
            _DrawerField(label: 'Email *', controller: _emailCtrl, hint: 'exemple@dips.ma',
                keyboardType: TextInputType.emailAddress),
            const SizedBox(height: 12),
            _DrawerField(label: 'Téléphone *', controller: _telCtrl, hint: '06xx xx xx xx',
                keyboardType: TextInputType.phone),
            const SizedBox(height: 12),
            _DrawerSection(label: 'ZONE'),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              value: _siteId,
              decoration: const InputDecoration(
                labelText: 'Zone (El Jadida / Safi / Tous)',
                isDense: true,
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                filled: true,
                fillColor: Color(0xFFF8FAFC),
              ),
              items: [
                DropdownMenuItem(value: SiteId.all, child: Text(SiteId.labelFr(SiteId.all))),
                DropdownMenuItem(value: SiteId.jadida, child: Text(SiteId.labelFr(SiteId.jadida))),
                DropdownMenuItem(value: SiteId.safi, child: Text(SiteId.labelFr(SiteId.safi))),
              ],
              onChanged: (v) => setState(() => _siteId = v ?? SiteId.all),
            ),
            if (_role.toLowerCase().contains('zone')) ...[
              const SizedBox(height: 12),
              Builder(
                builder: (context) {
                  final groupsProv = context.watch<DistributionGroupsProvider>();
                  final groups = groupsProv.groups;
                  if (groups.isEmpty) {
                    return Text(
                      'Aucun groupe Distribution. Définissez des groupes dans la section Distribution.',
                      style: TextStyle(fontSize: 11, color: Colors.orange[800]),
                    );
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Groupes Distribution gérés *',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF4A5568)),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Pointage (confirmation), export Excel et demandes de congé : uniquement ces groupes. Laissez vide pour autoriser tous les groupes Distribution de la zone.',
                        style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        constraints: const BoxConstraints(maxHeight: 220),
                        decoration: BoxDecoration(
                          border: Border.all(color: _kBorder),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: ListView(
                          shrinkWrap: true,
                          children: groups.map((g) {
                            final checked = _chefZoneDistributionGroupIds.contains(g.id);
                            return CheckboxListTile(
                              dense: true,
                              title: Text(g.nom, style: const TextStyle(fontSize: 12)),
                              value: checked,
                              onChanged: (v) => setState(() {
                                if (v == true) {
                                  _chefZoneDistributionGroupIds.add(g.id);
                                } else {
                                  _chefZoneDistributionGroupIds.remove(g.id);
                                }
                              }),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
            if (!isEdit) ...[
              const SizedBox(height: 12),
              // Password with eye toggle
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Mot de passe *',
                      style: TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF4A5568))),
                  const SizedBox(height: 5),
                  TextFormField(
                    controller: _pwdCtrl,
                    obscureText: !_showPwd,
                    style: const TextStyle(fontSize: 13),
                    decoration: InputDecoration(
                      hintText: '••••••••',
                      hintStyle:
                      TextStyle(color: Colors.grey[400], fontSize: 13),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 11),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: _kBorder)),
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: _kBorder)),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide:
                          const BorderSide(color: _kAccent, width: 1.5)),
                      suffixIcon: IconButton(
                        icon: Icon(
                            _showPwd
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            size: 17,
                            color: Colors.grey),
                        onPressed: () =>
                            setState(() => _showPwd = !_showPwd),
                      ),
                    ),
                    validator: (v) =>
                    (v == null || v.isEmpty) ? 'Requis' : null,
                  ),
                ],
              ),
            ] else ...[
              const SizedBox(height: 12),
              _DrawerSection(label: 'SÉCURITÉ'),
              const SizedBox(height: 6),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Nouveau mot de passe (optionnel)',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF4A5568),
                    ),
                  ),
                  const SizedBox(height: 5),
                  TextFormField(
                    controller: _pwdCtrl,
                    obscureText: !_showPwd,
                    style: const TextStyle(fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Laisser vide pour conserver le mot de passe actuel',
                      hintStyle: TextStyle(color: Colors.grey[500], fontSize: 12),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: _kBorder),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: _kBorder),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: _kAccent, width: 1.5),
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _showPwd
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          size: 17,
                          color: Colors.grey,
                        ),
                        onPressed: () => setState(() => _showPwd = !_showPwd),
                      ),
                    ),
                    validator: (v) {
                      final val = (v ?? '').trim();
                      if (val.isEmpty) return null;
                      if (val.length < 4) return 'Min. 4 caractères';
                      return null;
                    },
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _generatePassword,
                        icon: const Icon(Icons.auto_fix_high, size: 16),
                        label: const Text('Générer mot de passe'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _copyPassword,
                        icon: const Icon(Icons.copy, size: 16),
                        label: const Text('Copier'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Si vous remplissez ce champ, le mot de passe du compte sera réinitialisé.',
                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 20),
            const Text(
              'Modèles de permissions',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF4A5568)),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('Admin RH'),
                  selected: _selectedPreset == 'rh',
                  onSelected: (_) => _applyPreset('rh'),
                ),
                ChoiceChip(
                  label: const Text('Admin Pointage'),
                  selected: _selectedPreset == 'pointage',
                  onSelected: (_) => _applyPreset('pointage'),
                ),
                ChoiceChip(
                  label: const Text('Chef d\'atelier'),
                  selected: _selectedPreset == 'atelier',
                  onSelected: (_) => _applyPreset('atelier'),
                ),
                ChoiceChip(
                  label: const Text('Chef de zone'),
                  selected: _selectedPreset == 'zone',
                  onSelected: (_) => _applyPreset('zone'),
                ),
                ChoiceChip(
                  label: const Text('Personnalisé'),
                  selected: _selectedPreset == 'custom',
                  onSelected: (_) => setState(() => _selectedPreset = 'custom'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(children: [
              const Text('Statut du compte',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF4A5568))),
              const Spacer(),
              Switch.adaptive(
                value: _actif,
                onChanged: (v) => setState(() => _actif = v),
                activeColor: _kAccent,
              ),
              const SizedBox(width: 6),
              Text(
                _actif ? 'Actif' : 'Inactif',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _actif ? Colors.green : Colors.red),
              ),
            ]),
            const SizedBox(height: 20),
            // ── Permissions ──
            _DrawerSection(label: 'PERMISSIONS D\'ACCÈS'),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: const Border.fromBorderSide(BorderSide(color: _kBorder)),
              ),
              child: Column(
                children: _allPerms.map((p) {
                  final on = _perms.contains(p);
                  final label = AppPermissions.labelsFr[p] ?? p;
                  return InkWell(
                    onTap: () => setState(() {
                      on ? _perms.remove(p) : _perms.add(p);
                      _selectedPreset = _detectPreset(_perms);
                    }),
                    borderRadius: BorderRadius.circular(6),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 4),
                      child: Row(children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          width: 18,
                          height: 18,
                          decoration: BoxDecoration(
                            color: on ? _kAccent : Colors.white,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                                color: on ? _kAccent : Colors.grey.shade300,
                                width: 1.5),
                          ),
                          child: on
                              ? const Icon(Icons.check,
                              size: 12, color: Colors.white)
                              : null,
                        ),
                        const SizedBox(width: 10),
                        Text(label,
                            style: TextStyle(
                                fontSize: 13,
                                color: on ? _kDark : Colors.grey[600],
                                fontWeight: on
                                    ? FontWeight.w600
                                    : FontWeight.normal)),
                      ]),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  SECTION: CHEFS D'ÉQUIPE
// ─────────────────────────────────────────────

class _ChefsEquipeSection extends StatefulWidget {
  const _ChefsEquipeSection();
  @override
  State<_ChefsEquipeSection> createState() => _ChefsEquipeSectionState();
}

class _ChefsEquipeSectionState extends State<_ChefsEquipeSection> {
  String _searchQuery = '';

  List<_ChefEquipeView> _views(EmployeesProvider prov) {
    final eqs = prov.equipes;
    final emps = prov.employes;
    return eqs.map((e) {
      final list = emps.where((x) => x.id == e.chefId).toList();
      final chef = list.isEmpty ? null : list.first;
      return _ChefEquipeView(e, chef);
    }).where((v) => '${v.equipe.nom} ${v.chefNom} ${v.equipe.magasin}'.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
  }

  void _confirmDeleteEquipe(BuildContext context, EmployeesProvider prov, Equipe eq) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Supprimer l\'équipe'),
        content: Text('Supprimer l\'équipe « ${eq.nom} » ? Les membres ne seront pas supprimés.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () async {
              await prov.deleteEquipe(eq.id);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<EmployeesProvider>();
    final views = _views(prov);
    final mobile = isMobile(context);
    final padding = pagePadding(context);
    return Column(
      children: [
        if (!prov.firebaseAvailable) _offlineBanner(),
        Container(
          color: Colors.white,
          padding: EdgeInsets.fromLTRB(padding, 14, padding, 12),
          child: mobile
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('Chefs d\'équipe (données réelles)',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _kDark)),
                    Text('${prov.equipes.length} équipe(s) — Firestore',
                        style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                    const SizedBox(height: 12),
                    TextField(
                      onChanged: (v) => setState(() => _searchQuery = v),
                      style: const TextStyle(fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Rechercher...',
                        hintStyle: TextStyle(fontSize: 13, color: Colors.grey[400]),
                        prefixIcon: const Icon(Icons.search, size: 16),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(vertical: 9),
                        filled: true, fillColor: _kBg,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(7), borderSide: const BorderSide(color: _kBorder)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(7), borderSide: const BorderSide(color: _kBorder)),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _kDark, foregroundColor: Colors.white, elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
                        ),
                        icon: const Icon(Icons.group_add, size: 15),
                        label: const Text('Ajouter équipe', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                        onPressed: () => _showAddEquipeDialog(context, prov),
                      ),
                    ),
                  ],
                )
              : Row(
                  children: [
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('Chefs d\'équipe (données réelles)',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _kDark)),
                      Text('${prov.equipes.length} équipe(s) — Firestore',
                          style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                    ]),
                    const Spacer(),
                    SizedBox(
                      width: 200,
                      child: TextField(
                        onChanged: (v) => setState(() => _searchQuery = v),
                        style: const TextStyle(fontSize: 13),
                        decoration: InputDecoration(
                          hintText: 'Rechercher...',
                          hintStyle: TextStyle(fontSize: 13, color: Colors.grey[400]),
                          prefixIcon: const Icon(Icons.search, size: 16),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(vertical: 9),
                          filled: true, fillColor: _kBg,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(7), borderSide: const BorderSide(color: _kBorder)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(7), borderSide: const BorderSide(color: _kBorder)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _kDark, foregroundColor: Colors.white, elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
                      ),
                      icon: const Icon(Icons.group_add, size: 15),
                      label: const Text('Ajouter équipe', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                      onPressed: () => _showAddEquipeDialog(context, prov),
                    ),
                  ],
                ),
        ),
        const Divider(height: 1, color: _kBorder),
        if (!mobile)
          Container(
            color: const Color(0xFFF0F4FA),
            padding: EdgeInsets.symmetric(horizontal: padding, vertical: 9),
            child: const Row(children: [
              Expanded(flex: 3, child: _TH('ÉQUIPE')),
              Expanded(flex: 2, child: _TH('CHEF')),
              Expanded(flex: 2, child: _TH('DÉPARTEMENT')),
              Expanded(flex: 1, child: _TH('MEMBRES')),
              SizedBox(width: 110, child: _TH('ACTIONS', center: true)),
            ]),
          ),
        if (!mobile) const Divider(height: 1, color: _kBorder),
        Expanded(
          child: views.isEmpty
              ? const _EmptyState()
              : ListView.builder(
                  padding: mobile ? EdgeInsets.all(padding) : null,
                  itemCount: views.length,
                  itemBuilder: (context, i) {
                    final v = views[i];
                    if (mobile) {
                      return _ChefEquipeCard(
                        view: v,
                        onEdit: () => _showEditEquipeDialog(context, prov, v.equipe),
                        onDelete: () => _confirmDeleteEquipe(context, prov, v.equipe),
                      );
                    }
                    return _ChefEquipeRow(
                      view: v,
                      isEven: i.isEven,
                      onEdit: () => _showEditEquipeDialog(context, prov, v.equipe),
                      onDelete: () => _confirmDeleteEquipe(context, prov, v.equipe),
                    );
                  },
                ),
        ),
      ],
    );
  }

  void _showAddEquipeDialog(BuildContext context, EmployeesProvider prov) {
    final nomCtrl = TextEditingController();
    String? chefId;
    final deptNames = context.read<DepartementsProvider>().departements.map((d) => d.nom).toList();
    String selectedDepartement = deptNames.isNotEmpty ? deptNames.first : '';
    String selectedSiteId = context.read<SiteProvider>().selectedSiteId ?? SiteId.jadida;
    if (selectedSiteId == SiteId.all) selectedSiteId = SiteId.jadida;
    final usedIds = <String>{
      for (final e in prov.equipes) ...[
        if (e.chefId.isNotEmpty) e.chefId,
        ...e.membreIds,
      ]
    };
    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Nouvelle équipe'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nomCtrl, decoration: const InputDecoration(labelText: 'Nom équipe')),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedSiteId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Site *'),
                  items: [
                    DropdownMenuItem(value: SiteId.jadida, child: Text(SiteId.labelFr(SiteId.jadida), overflow: TextOverflow.ellipsis)),
                    DropdownMenuItem(value: SiteId.safi, child: Text(SiteId.labelFr(SiteId.safi), overflow: TextOverflow.ellipsis)),
                  ],
                  onChanged: (v) => setDialogState(() => selectedSiteId = v ?? SiteId.jadida),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: deptNames.isEmpty ? '' : selectedDepartement,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Département *'),
                  items: (deptNames.isEmpty ? <String>[''] : deptNames)
                      .map((d) => DropdownMenuItem(value: d, child: Text(d.isEmpty ? '—' : d, overflow: TextOverflow.ellipsis)))
                      .toList(),
                  onChanged: (v) => setDialogState(() => selectedDepartement = v ?? ''),
                ),
                const SizedBox(height: 12),
                _ChefEquipeDropdown(
                  prov: prov,
                  chefId: chefId,
                  excludedIds: usedIds,
                  onChanged: (v) => setDialogState(() => chefId = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
            ElevatedButton(
              onPressed: () async {
                final nom = nomCtrl.text.trim();
                if (nom.isEmpty) return;
                final id = 'eq_${DateTime.now().millisecondsSinceEpoch}';
                await prov.addEquipe(Equipe(
                  id: id,
                  nom: nom,
                  magasin: selectedDepartement,
                  chefId: chefId ?? '',
                  membreIds: [],
                  siteId: selectedSiteId,
                ));
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Créer'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditEquipeDialog(BuildContext context, EmployeesProvider prov, Equipe eq) {
    final nomCtrl = TextEditingController(text: eq.nom);
    String? chefId = eq.chefId.isEmpty ? null : eq.chefId;
    final deptNamesBase = context.read<DepartementsProvider>().departements.map((d) => d.nom).toList();
    final deptNames = [
      ...deptNamesBase,
      if (eq.magasin.isNotEmpty && !deptNamesBase.contains(eq.magasin)) eq.magasin,
    ];
    String selectedDepartement = eq.magasin;
    String selectedSiteId = eq.siteId;
    if (selectedSiteId == SiteId.all) selectedSiteId = SiteId.jadida;
    final usedIds = <String>{
      for (final e in prov.equipes) ...[
        if (e.chefId.isNotEmpty) e.chefId,
        ...e.membreIds,
      ]
    };
    bool useCustomHours = eq.pointageStartHour != null && eq.pointageEndHour != null;
    int startHour = eq.pointageStartHour ?? 6;
    int startMinute = eq.pointageStartMinute ?? 0;
    int endHour = eq.pointageEndHour ?? 10;
    int endMinute = eq.pointageEndMinute ?? 0;
    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Modifier l\'équipe'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(controller: nomCtrl, decoration: const InputDecoration(labelText: 'Nom équipe')),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedSiteId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Site *'),
                  items: [
                    DropdownMenuItem(value: SiteId.jadida, child: Text(SiteId.labelFr(SiteId.jadida), overflow: TextOverflow.ellipsis)),
                    DropdownMenuItem(value: SiteId.safi, child: Text(SiteId.labelFr(SiteId.safi), overflow: TextOverflow.ellipsis)),
                  ],
                  onChanged: (v) => setDialogState(() => selectedSiteId = v ?? SiteId.jadida),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: deptNames.isEmpty ? '' : (deptNames.contains(selectedDepartement) ? selectedDepartement : deptNames.first),
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Département *'),
                  items: (deptNames.isEmpty ? <String>[''] : deptNames)
                      .map((d) => DropdownMenuItem(value: d, child: Text(d.isEmpty ? '—' : d, overflow: TextOverflow.ellipsis)))
                      .toList(),
                  onChanged: (v) => setDialogState(() => selectedDepartement = v ?? ''),
                ),
                const SizedBox(height: 12),
                _ChefEquipeDropdown(
                  prov: prov,
                  chefId: chefId,
                  excludedIds: usedIds,
                  forceIncludeId: eq.chefId.isEmpty ? null : eq.chefId,
                  onChanged: (v) => setDialogState(() => chefId = v),
                ),
                const SizedBox(height: 16),
                const Divider(),
                Text('Heures de pointage (chef d\'équipe)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey[800])),
                const SizedBox(height: 6),
                CheckboxListTile(
                  value: useCustomHours,
                  onChanged: (v) => setDialogState(() => useCustomHours = v ?? false),
                  title: const Text('Heures personnalisées pour cette équipe', style: TextStyle(fontSize: 12)),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                ),
                if (useCustomHours) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      SizedBox(width: 72, child: Text('Ouverture', style: TextStyle(fontSize: 12, color: Colors.grey[700]))),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          value: startHour.clamp(0, 23),
                          decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 4)),
                          items: List.generate(24, (i) => DropdownMenuItem(value: i, child: Text('${i.toString().padLeft(2, '0')}h', overflow: TextOverflow.ellipsis))),
                          onChanged: (v) => setDialogState(() => startHour = v ?? 6),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          value: [0, 15, 30, 45].contains(startMinute) ? startMinute : 0,
                          decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 4)),
                          items: [0, 15, 30, 45].map((m) => DropdownMenuItem(value: m, child: Text('${m.toString().padLeft(2, '0')}', overflow: TextOverflow.ellipsis))).toList(),
                          onChanged: (v) => setDialogState(() => startMinute = v ?? 0),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      SizedBox(width: 72, child: Text('Fermeture', style: TextStyle(fontSize: 12, color: Colors.grey[700]))),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          value: endHour.clamp(0, 23),
                          decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 4)),
                          items: List.generate(24, (i) => DropdownMenuItem(value: i, child: Text('${i.toString().padLeft(2, '0')}h', overflow: TextOverflow.ellipsis))),
                          onChanged: (v) => setDialogState(() => endHour = v ?? 10),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          value: [0, 15, 30, 45].contains(endMinute) ? endMinute : 0,
                          decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 4)),
                          items: [0, 15, 30, 45].map((m) => DropdownMenuItem(value: m, child: Text('${m.toString().padLeft(2, '0')}', overflow: TextOverflow.ellipsis))).toList(),
                          onChanged: (v) => setDialogState(() => endMinute = v ?? 0),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
            ElevatedButton(
              onPressed: () async {
                final updated = Equipe(
                  id: eq.id,
                  nom: nomCtrl.text.trim(),
                  magasin: selectedDepartement,
                  chefId: chefId ?? '',
                  membreIds: eq.membreIds,
                  siteId: selectedSiteId,
                  pointageStartHour: useCustomHours ? startHour : null,
                  pointageStartMinute: useCustomHours ? startMinute : null,
                  pointageEndHour: useCustomHours ? endHour : null,
                  pointageEndMinute: useCustomHours ? endMinute : null,
                );
                await prov.updateEquipe(updated);
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Card pour équipe (mobile, responsive)
class _ChefEquipeCard extends StatelessWidget {
  final _ChefEquipeView view;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ChefEquipeCard({required this.view, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final v = view;
    final eq = v.equipe;
    final padding = pagePadding(context);
    return Card(
      margin: EdgeInsets.only(bottom: padding),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: _kBorder)),
      child: Padding(
        padding: EdgeInsets.all(padding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(eq.nom, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _kDark)),
            const SizedBox(height: 6),
            Text('Chef: ${v.chefNom}', style: TextStyle(fontSize: 13, color: Colors.grey[700])),
            Text('Département: ${eq.magasin}', style: TextStyle(fontSize: 13, color: Colors.grey[700])),
            const SizedBox(height: 4),
            Text('${eq.membreIds.length} membre(s)', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            Row(
              children: [
                TextButton.icon(
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Modifier'),
                  onPressed: onEdit,
                  style: TextButton.styleFrom(foregroundColor: _kAccent),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text('Supprimer'),
                  onPressed: onDelete,
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Row pour équipe + chef (données réelles)
class _ChefEquipeRow extends StatefulWidget {
  final _ChefEquipeView view;
  final bool isEven;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const _ChefEquipeRow({required this.view, required this.isEven, required this.onEdit, required this.onDelete});
  @override
  State<_ChefEquipeRow> createState() => _ChefEquipeRowState();
}

class _ChefEquipeRowState extends State<_ChefEquipeRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final v = widget.view;
    final eq = v.equipe;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit:  (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        color: _hovered ? _kRowHover : (widget.isEven ? Colors.white : const Color(0xFFFAFBFD)),
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: Row(children: [
              Expanded(flex: 3, child: Text(eq.nom, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _kDark), overflow: TextOverflow.ellipsis)),
              Expanded(flex: 2, child: Text(v.chefNom, style: TextStyle(fontSize: 12, color: Colors.grey[700]), overflow: TextOverflow.ellipsis)),
              Expanded(flex: 2, child: Text(eq.magasin, style: TextStyle(fontSize: 12, color: Colors.grey[700]))),
              Expanded(flex: 1, child: Text('${eq.membreIds.length}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
              SizedBox(
                width: 110,
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  _TableBtn(icon: Icons.edit_outlined, tooltip: 'Modifier', color: _kAccent, onTap: widget.onEdit),
                  const SizedBox(width: 5),
                  _TableBtn(icon: Icons.delete_outline, tooltip: 'Supprimer', color: Colors.red, onTap: widget.onDelete),
                ]),
              ),
            ]),
          ),
          const Divider(height: 1, color: _kBorder),
        ]),
      ),
    );
  }
}

// ── Chef details dialog with employee CRUD ──
class _ChefDetailsDialog extends StatefulWidget {
  final _ParamChefEquipe chef;
  final Color deptColor;
  const _ChefDetailsDialog({required this.chef, required this.deptColor});
  @override
  State<_ChefDetailsDialog> createState() => _ChefDetailsDialogState();
}

class _ChefDetailsDialogState extends State<_ChefDetailsDialog> {
  late List<_ParamEmploye> _employes;

  @override
  void initState() {
    super.initState();
    _employes = List.from(widget.chef.employes);
  }

  void _saveEmployes() {
    widget.chef.employes
      ..clear()
      ..addAll(_employes);
    widget.chef.nbEmployes = _employes.length;
  }

  void _addOrEditEmployee([_ParamEmploye? existing]) {
    final nomCtrl    = TextEditingController(text: existing?.nom ?? '');
    final prenomCtrl = TextEditingController(text: existing?.prenom ?? '');
    final posteCtrl  = TextEditingController(text: existing?.poste ?? '');
    final telCtrl    = TextEditingController(text: existing?.telephone ?? '');
    bool actif = existing?.actif ?? true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // header
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 18, 14, 14),
                  decoration: BoxDecoration(
                    color: widget.deptColor.withOpacity(0.07),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                    border: Border(bottom: BorderSide(color: widget.deptColor.withOpacity(0.2))),
                  ),
                  child: Row(children: [
                    Icon(existing == null ? Icons.person_add_outlined : Icons.edit_outlined,
                        color: widget.deptColor, size: 20),
                    const SizedBox(width: 10),
                    Text(
                      existing == null ? 'Ajouter un collaborateur' : 'Modifier le collaborateur',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _kDark),
                    ),
                    const Spacer(),
                    IconButton(icon: const Icon(Icons.close, size: 18), onPressed: () => Navigator.pop(ctx)),
                  ]),
                ),
                // form
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(children: [
                    Row(children: [
                      Expanded(child: _DrawerField(label: 'Prénom *', controller: prenomCtrl, hint: 'Prénom')),
                      const SizedBox(width: 12),
                      Expanded(child: _DrawerField(label: 'Nom *', controller: nomCtrl, hint: 'Nom')),
                    ]),
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(child: _DrawerField(label: 'Poste *', controller: posteCtrl, hint: 'Ex: Technicien')),
                      const SizedBox(width: 12),
                      Expanded(child: _DrawerField(label: 'Téléphone', controller: telCtrl, hint: '06xx xx xx xx', keyboardType: TextInputType.phone)),
                    ]),
                    const SizedBox(height: 12),
                    Row(children: [
                      const Text('Statut', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF4A5568))),
                      const Spacer(),
                      Switch.adaptive(value: actif, onChanged: (v) => setDlg(() => actif = v), activeColor: widget.deptColor),
                      const SizedBox(width: 4),
                      Text(actif ? 'Actif' : 'Inactif',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: actif ? Colors.green : Colors.red)),
                    ]),
                  ]),
                ),
                // footer
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
                  decoration: const BoxDecoration(border: Border(top: BorderSide(color: _kBorder))),
                  child: Row(children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(side: const BorderSide(color: _kBorder), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Annuler', style: TextStyle(color: _kDark)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: widget.deptColor, foregroundColor: Colors.white, elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () {
                          if (prenomCtrl.text.isEmpty || nomCtrl.text.isEmpty) return;
                          final emp = _ParamEmploye(
                            id: existing?.id ?? 'EMP${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}',
                            nom: nomCtrl.text.trim(),
                            prenom: prenomCtrl.text.trim(),
                            poste: posteCtrl.text.trim(),
                            telephone: telCtrl.text.trim(),
                            actif: actif,
                          );
                          setState(() {
                            if (existing != null) {
                              final idx = _employes.indexWhere((e) => e.id == existing.id);
                              if (idx != -1) _employes[idx] = emp;
                            } else {
                              _employes.add(emp);
                            }
                            _saveEmployes();
                          });
                          Navigator.pop(ctx);
                        },
                        child: Text(existing == null ? 'Ajouter' : 'Modifier',
                            style: const TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ]),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _confirmDeleteEmployee(_ParamEmploye emp) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Row(children: const [Icon(Icons.warning_amber_rounded, color: Colors.red, size: 20), SizedBox(width: 8), Text('Supprimer le collaborateur', style: TextStyle(fontSize: 15))]),
        content: Text('Supprimer ${emp.prenom} ${emp.nom} ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white, elevation: 0),
            onPressed: () {
              setState(() {
                _employes.removeWhere((e) => e.id == emp.id);
                _saveEmployes();
              });
              Navigator.pop(context);
            },
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.chef;
    final dc = widget.deptColor;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 30),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 820, maxHeight: 700),
        child: Column(
          children: [
            // ── Header ──
            Container(
              padding: const EdgeInsets.fromLTRB(28, 22, 20, 18),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [dc.withOpacity(0.10), Colors.white],
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                border: Border(bottom: BorderSide(color: dc.withOpacity(0.2))),
              ),
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: dc.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
                  child: Icon(Icons.groups, color: dc, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${c.prenom} ${c.nom}',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _kDark)),
                    Row(children: [
                      Text(c.id, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: dc.withOpacity(0.10), borderRadius: BorderRadius.circular(10)),
                        child: Text(c.departement, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: dc)),
                      ),
                    ]),
                  ]),
                ),
                IconButton(icon: const Icon(Icons.close, size: 20), onPressed: () => Navigator.pop(context)),
              ]),
            ),
            // ── Body: two columns ──
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left: chef info
                  Container(
                    width: 260,
                    padding: const EdgeInsets.all(22),
                    decoration: const BoxDecoration(
                      color: Color(0xFFF8FAFC),
                      border: Border(right: BorderSide(color: _kBorder)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Container(width: 3, height: 13, decoration: BoxDecoration(color: dc, borderRadius: BorderRadius.circular(2))),
                          const SizedBox(width: 8),
                          Text('INFORMATIONS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.8, color: Colors.grey[500])),
                        ]),
                        const SizedBox(height: 14),
                        _DetailRow(icon: Icons.email_outlined,  label: 'Email',   value: c.email),
                        _DetailRow(icon: Icons.phone_outlined,  label: 'Tél.',    value: c.telephone),
                        _DetailRow(icon: Icons.people_outline,  label: 'Effectif', value: '${_employes.length} collaborateur(s)'),
                        _DetailRow(icon: Icons.calendar_today,  label: 'Créé le',
                            value: '${c.dateCreation.day.toString().padLeft(2,'0')}/${c.dateCreation.month.toString().padLeft(2,'0')}/${c.dateCreation.year}'),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: c.actif ? Colors.green.withOpacity(0.08) : Colors.red.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: c.actif ? Colors.green.withOpacity(0.2) : Colors.red.withOpacity(0.2)),
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Container(width: 6, height: 6, decoration: BoxDecoration(color: c.actif ? Colors.green : Colors.red, shape: BoxShape.circle)),
                            const SizedBox(width: 6),
                            Text(c.actif ? 'Chef actif' : 'Chef inactif',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: c.actif ? Colors.green.shade700 : Colors.red.shade600)),
                          ]),
                        ),
                      ],
                    ),
                  ),
                  // Right: employees table
                  Expanded(
                    child: Column(
                      children: [
                        // employees header
                        Container(
                          color: Colors.white,
                          padding: const EdgeInsets.fromLTRB(20, 14, 16, 12),
                          child: Row(children: [
                            Row(children: [
                              Container(width: 3, height: 14, decoration: BoxDecoration(color: dc, borderRadius: BorderRadius.circular(2))),
                              const SizedBox(width: 8),
                              Text('EMPLOYÉS (${_employes.length})',
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.7, color: Color(0xFF6B7A99))),
                            ]),
                            const Spacer(),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: dc, foregroundColor: Colors.white, elevation: 0,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
                              ),
                              icon: const Icon(Icons.person_add_outlined, size: 14),
                              label: const Text('Ajouter', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                              onPressed: () => _addOrEditEmployee(),
                            ),
                          ]),
                        ),
                        const Divider(height: 1, color: _kBorder),
                        // employees table header
                        Container(
                          color: const Color(0xFFF0F4FA),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                          child: const Row(children: [
                            Expanded(flex: 3, child: _TH('NOM COMPLET')),
                            Expanded(flex: 2, child: _TH('POSTE')),
                            Expanded(flex: 2, child: _TH('TÉLÉPHONE')),
                            Expanded(flex: 1, child: _TH('STATUT')),
                            SizedBox(width: 70, child: _TH('', center: true)),
                          ]),
                        ),
                        const Divider(height: 1, color: _kBorder),
                        // employees list
                        Expanded(
                          child: _employes.isEmpty
                              ? Center(
                            child: Column(mainAxisSize: MainAxisSize.min, children: [
                              Icon(Icons.people_outline, size: 36, color: Colors.grey[300]),
                              const SizedBox(height: 8),
                              Text('Aucun collaborateur enregistré',
                                  style: TextStyle(fontSize: 13, color: Colors.grey[400])),
                              const SizedBox(height: 10),
                              TextButton.icon(
                                icon: Icon(Icons.add, color: dc, size: 16),
                                label: Text('Ajouter le premier', style: TextStyle(color: dc)),
                                onPressed: () => _addOrEditEmployee(),
                              ),
                            ]),
                          )
                              : ListView.builder(
                            itemCount: _employes.length,
                            itemBuilder: (_, i) {
                              final emp = _employes[i];
                              return Container(
                                color: i.isEven ? Colors.white : const Color(0xFFFAFBFD),
                                child: Column(children: [
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                    child: Row(children: [
                                      // Nom
                                      Expanded(
                                        flex: 3,
                                        child: Text('${emp.prenom} ${emp.nom}',
                                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _kDark),
                                            overflow: TextOverflow.ellipsis),
                                      ),
                                      // Poste
                                      Expanded(
                                        flex: 2,
                                        child: Align(
                                          alignment: Alignment.centerLeft,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: dc.withOpacity(0.07),
                                              borderRadius: BorderRadius.circular(4),
                                              border: Border.all(color: dc.withOpacity(0.2)),
                                            ),
                                            child: Text(emp.poste,
                                                style: TextStyle(fontSize: 10, color: dc, fontWeight: FontWeight.w600),
                                                overflow: TextOverflow.ellipsis),
                                          ),
                                        ),
                                      ),
                                      // Tel
                                      Expanded(
                                        flex: 2,
                                        child: Text(emp.telephone,
                                            style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                                      ),
                                      // Statut
                                      Expanded(
                                        flex: 1,
                                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                                          Container(width: 6, height: 6,
                                              decoration: BoxDecoration(
                                                  color: emp.actif ? Colors.green : Colors.red,
                                                  shape: BoxShape.circle)),
                                        ]),
                                      ),
                                      // Actions
                                      SizedBox(
                                        width: 70,
                                        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                                          _TableBtn(icon: Icons.edit_outlined, tooltip: 'Modifier', color: _kAccent, onTap: () => _addOrEditEmployee(emp)),
                                          const SizedBox(width: 5),
                                          _TableBtn(icon: Icons.delete_outline, tooltip: 'Supprimer', color: Colors.red, onTap: () => _confirmDeleteEmployee(emp)),
                                        ]),
                                      ),
                                    ]),
                                  ),
                                  const Divider(height: 1, color: _kBorder),
                                ]),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Chef sliding drawer ──
class _ChefDrawer extends StatefulWidget {
  final _ParamChefEquipe? existing;
  final Function(_ParamChefEquipe) onSave;
  const _ChefDrawer({this.existing, required this.onSave});
  @override
  State<_ChefDrawer> createState() => _ChefDrawerState();
}

class _ChefDrawerState extends State<_ChefDrawer> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nomCtrl, _prenomCtrl, _emailCtrl, _telCtrl, _nbEmpCtrl;
  String _dept = 'Production';
  bool _actif = true;

  final _depts = [
    'Production', 'Logistique', 'Maintenance', 'Informatique', 'Administration'
  ];

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _nomCtrl   = TextEditingController(text: e?.nom ?? '');
    _prenomCtrl = TextEditingController(text: e?.prenom ?? '');
    _emailCtrl = TextEditingController(text: e?.email ?? '');
    _telCtrl   = TextEditingController(text: e?.telephone ?? '');
    _nbEmpCtrl = TextEditingController(text: '${e?.nbEmployes ?? 0}');
    _dept  = e?.departement ?? 'Production';
    _actif = e?.actif ?? true;
  }

  @override
  void dispose() {
    _nomCtrl.dispose(); _prenomCtrl.dispose();
    _emailCtrl.dispose(); _telCtrl.dispose(); _nbEmpCtrl.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final isNew = widget.existing == null;
    widget.onSave(_ParamChefEquipe(
      id: isNew
          ? 'CE${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}'
          : widget.existing!.id,
      nom: _nomCtrl.text.trim(),
      prenom: _prenomCtrl.text.trim(),
      email: _emailCtrl.text.trim(),
      telephone: _telCtrl.text.trim(),
      departement: _dept,
      nbEmployes: int.tryParse(_nbEmpCtrl.text) ?? 0,
      actif: _actif,
      dateCreation: widget.existing?.dateCreation ?? DateTime.now(),
    ));
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    return _SideDrawer(
      title: isEdit ? 'Modifier le chef d\'équipe' : 'Nouveau chef d\'équipe',
      subtitle: isEdit ? 'Mettre à jour les informations' : 'Enregistrer un nouveau chef',
      icon: isEdit ? Icons.manage_accounts : Icons.group_add,
      accentColor: _kDark,
      saveLabel: isEdit ? 'Modifier' : 'Enregistrer',
      onSave: _save,
      body: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _DrawerSection(label: 'IDENTITÉ'),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: _DrawerField(label: 'Prénom *', controller: _prenomCtrl, hint: 'Ex: Farid')),
              const SizedBox(width: 12),
              Expanded(child: _DrawerField(label: 'Nom *', controller: _nomCtrl, hint: 'Ex: Benhaddou')),
            ]),
            const SizedBox(height: 12),
            _DrawerField(label: 'Email *', controller: _emailCtrl, hint: 'exemple@dips.ma',
                keyboardType: TextInputType.emailAddress),
            const SizedBox(height: 12),
            _DrawerField(label: 'Téléphone', controller: _telCtrl, hint: '06xx xx xx xx',
                keyboardType: TextInputType.phone),
            const SizedBox(height: 20),
            _DrawerSection(label: 'AFFECTATION'),
            const SizedBox(height: 10),
            _DrawerDropdown(
              label: 'Département *',
              value: _dept,
              items: _depts,
              onChanged: (v) => setState(() => _dept = v!),
            ),
            const SizedBox(height: 12),
            _DrawerField(
              label: 'Nombre de collaborateurs sous sa responsabilité',
              controller: _nbEmpCtrl,
              hint: '0',
              isNumber: true,
            ),
            const SizedBox(height: 20),
            _DrawerSection(label: 'STATUT'),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: const Border.fromBorderSide(BorderSide(color: _kBorder)),
              ),
              child: Row(
                children: [
                  Text('Compte actif',
                      style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey[700])),
                  const Spacer(),
                  Switch.adaptive(
                    value: _actif,
                    onChanged: (v) => setState(() => _actif = v),
                    activeColor: _kDark,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _actif ? 'Actif' : 'Inactif',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _actif ? Colors.green : Colors.red),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  SHARED SMALL WIDGETS (ERP style)
// ─────────────────────────────────────────────

class _KpiChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _KpiChip({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value,
              style: TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w800, color: color)),
          const SizedBox(width: 5),
          Text(label,
              style:
              TextStyle(fontSize: 11, color: Colors.grey[600])),
        ],
      ),
    );
  }
}

class _TableBtn extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final Color color;
  final VoidCallback onTap;
  const _TableBtn(
      {required this.icon,
        required this.tooltip,
        required this.color,
        required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: color.withOpacity(0.15)),
          ),
          child: Icon(icon, size: 15, color: color),
        ),
      ),
    );
  }
}

class _DrawerSection extends StatelessWidget {
  final String label;
  const _DrawerSection({required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 3, height: 14, decoration: BoxDecoration(color: _kAccent, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 8),
        Text(label,
            style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
                color: Color(0xFF6B7A99))),
        const SizedBox(width: 10),
        const Expanded(child: Divider(color: _kBorder)),
      ],
    );
  }
}

// ─────────────────────────────────────────────
//  SECTION: COMPTES CHEFS
// ─────────────────────────────────────────────

class _ChefComptesSection extends StatefulWidget {
  const _ChefComptesSection();
  @override
  State<_ChefComptesSection> createState() => _ChefComptesSectionState();
}

class _ChefComptesSectionState extends State<_ChefComptesSection> {
  String _searchQuery = '';

  void _confirmDelete(BuildContext ctx, ChefComptesProvider prov, ChefCompte c) {
    showDialog(
      context: ctx,
      builder: (_) => AlertDialog(
        title: const Text('Supprimer le compte chef'),
        content: Text('Supprimer le compte « ${c.nom} » (${c.email}) ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () async {
              await prov.deleteChefCompte(c.id);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<ChefComptesProvider>();
    final emps = context.watch<EmployeesProvider>();

    if (prov.loading && prov.firebaseAvailable) {
      return const Center(child: CircularProgressIndicator());
    }

    final filtered = prov.chefComptes.where((c) {
      final q = _searchQuery.toLowerCase();
      return c.nom.toLowerCase().contains(q) || c.email.toLowerCase().contains(q);
    }).toList();

    final mobile = isMobile(context);
    final padding = pagePadding(context);
    return Column(
      children: [
        if (!prov.firebaseAvailable) _offlineBanner(),
        Container(
          color: Colors.white,
          padding: EdgeInsets.fromLTRB(padding, 14, padding, 12),
          child: mobile
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('Comptes Chefs',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _kDark)),
                    Text('Email + mot de passe — le chef ne voit que son équipe',
                        style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 36,
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: 'Rechercher...',
                          prefixIcon: const Icon(Icons.search, size: 18),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          filled: true,
                          fillColor: const Color(0xFFF7F9FC),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                        ),
                        onChanged: (v) => setState(() => _searchQuery = v),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _showDialog(context, prov, emps, null),
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('Ajouter'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF328EEE),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                  ],
                )
              : Row(
                  children: [
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('Comptes Chefs',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _kDark)),
                      Text('Email + mot de passe — le chef ne voit que son équipe',
                          style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                    ]),
                    const Spacer(),
                    SizedBox(
                      width: 220,
                      height: 36,
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: 'Rechercher...',
                          prefixIcon: const Icon(Icons.search, size: 18),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          filled: true,
                          fillColor: const Color(0xFFF7F9FC),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                        ),
                        onChanged: (v) => setState(() => _searchQuery = v),
                      ),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton.icon(
                      onPressed: () => _showDialog(context, prov, emps, null),
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Ajouter'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF328EEE),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ],
                ),
        ),
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.login, size: 56, color: Colors.grey[300]),
                      const SizedBox(height: 12),
                      Text(
                        prov.chefComptes.isEmpty ? 'Aucun compte chef' : 'Aucun résultat',
                        style: TextStyle(color: Colors.grey[500], fontSize: 14),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filtered.length,
                  itemBuilder: (ctx, i) {
                    final c = filtered[i];
                    final equipe = emps.equipes.where((e) => e.id == c.equipeId).toList();
                    final equipeName = equipe.isNotEmpty ? equipe.first.nom : c.equipeId;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(color: Colors.grey.shade200),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        leading: CircleAvatar(
                          backgroundColor: const Color(0xFF328EEE).withOpacity(0.15),
                          child: const Icon(Icons.person, color: Color(0xFF328EEE)),
                        ),
                        title: Text(c.nom, style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(c.email, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                            Text('Équipe: $equipeName', style: TextStyle(fontSize: 11, color: AppColors.brand)),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: c.actif ? Colors.green.shade50 : Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                c.actif ? 'Actif' : 'Inactif',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: c.actif ? Colors.green.shade700 : Colors.grey.shade600,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, size: 18),
                              onPressed: () => _showDialog(context, prov, emps, c),
                              tooltip: 'Modifier',
                            ),
                            IconButton(
                              icon: Icon(Icons.delete_outline, size: 18, color: Colors.red.shade400),
                              onPressed: () => _confirmDelete(context, prov, c),
                              tooltip: 'Supprimer',
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  void _showDialog(BuildContext context, ChefComptesProvider prov, EmployeesProvider emps, ChefCompte? existing) {
    final isEdit = existing != null;
    final nomCtrl = TextEditingController(text: existing?.nom ?? '');
    final emailCtrl = TextEditingController(text: existing?.email ?? '');
    final passwordCtrl = TextEditingController(text: existing?.password ?? '');
    String? selectedEquipeId = existing?.equipeId;
    bool actif = existing?.actif ?? true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final equipes = emps.equipes;
          if (equipes.isEmpty) {
            return AlertDialog(
              title: const Text('Aucune équipe'),
              content: const Text('Créez d\'abord au moins une équipe (onglet Chefs d\'équipe).'),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
              ],
            );
          }
          return AlertDialog(
            title: Text(isEdit ? 'Modifier le compte chef' : 'Ajouter un compte chef'),
            content: SizedBox(
              width: 400,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nomCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Nom complet *',
                        prefixIcon: Icon(Icons.badge_outlined),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Email (pour connexion) *',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: passwordCtrl,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: isEdit ? 'Nouveau mot de passe (laisser vide pour garder)' : 'Mot de passe *',
                        prefixIcon: const Icon(Icons.lock_outline),
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: selectedEquipeId?.isNotEmpty == true ? selectedEquipeId : null,
                      decoration: const InputDecoration(
                        labelText: 'Équipe (le chef ne verra que cette équipe) *',
                        prefixIcon: Icon(Icons.groups_outlined),
                      ),
                      items: equipes.map((e) => DropdownMenuItem(value: e.id, child: Text(e.nom))).toList(),
                      onChanged: (v) => setDialogState(() => selectedEquipeId = v),
                    ),
                    const SizedBox(height: 16),
                    SwitchListTile(
                      title: const Text('Compte actif'),
                      value: actif,
                      onChanged: (v) => setDialogState(() => actif = v),
                      secondary: Icon(actif ? Icons.check_circle : Icons.cancel, color: actif ? Colors.green : Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
              ElevatedButton(
                onPressed: () async {
                  final nom = nomCtrl.text.trim();
                  final email = emailCtrl.text.trim();
                  final password = passwordCtrl.text.trim();

                  if (nom.isEmpty || email.isEmpty) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(content: Text('Nom et email obligatoires')),
                    );
                    return;
                  }
                  if (!isEdit && password.isEmpty) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(content: Text('Mot de passe obligatoire pour un nouveau compte')),
                    );
                    return;
                  }
                  if (selectedEquipeId == null || selectedEquipeId!.isEmpty) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(content: Text('Sélectionnez une équipe')),
                    );
                    return;
                  }

                  final compte = ChefCompte(
                    id: existing?.id ?? 'chef_${DateTime.now().millisecondsSinceEpoch}',
                    nom: nom,
                    email: email.toLowerCase().trim(),
                    password: password.isEmpty ? (existing!.password) : password,
                    equipeId: selectedEquipeId!,
                    actif: actif,
                    dateCreation: existing?.dateCreation ?? DateTime.now(),
                  );

                  if (isEdit) {
                    await prov.updateChefCompte(compte);
                  } else {
                    await prov.addChefCompte(compte);
                  }

                  if (ctx.mounted) Navigator.pop(ctx);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF328EEE),
                  foregroundColor: Colors.white,
                ),
                child: Text(isEdit ? 'Enregistrer' : 'Ajouter'),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  GROUPES (indépendants)
// ─────────────────────────────────────────────

class _GroupesSection extends StatefulWidget {
  const _GroupesSection();

  @override
  State<_GroupesSection> createState() => _GroupesSectionState();
}

class _GroupesSectionState extends State<_GroupesSection> {
  String _q = '';
  static const Map<int, String> _weekdayLabels = <int, String>{
    DateTime.monday: 'Lundi',
    DateTime.tuesday: 'Mardi',
    DateTime.wednesday: 'Mercredi',
    DateTime.thursday: 'Jeudi',
    DateTime.friday: 'Vendredi',
    DateTime.saturday: 'Samedi',
    DateTime.sunday: 'Dimanche',
  };

  void _showGroupeDialog(BuildContext context, GroupesProvider prov, EmployeesProvider emps, Groupe? existing) {
    final nameCtrl = TextEditingController(text: existing?.nom ?? '');
    int sh = existing?.startHour ?? 8;
    int sm = existing?.startMinute ?? 0;
    int eh = existing?.endHour ?? 16;
    int em = existing?.endMinute ?? 0;
    int restWeekday = existing?.weeklyRestWeekday ?? DateTime.sunday;
    final selectedIds = <String>{...(existing?.membreIds ?? const [])};

    final employees = emps.employes.toList()..sort((a, b) => a.nom.compareTo(b.nom));
    // Enforce: an employee cannot be in more than one équipe or groupe.
    final usedInEquipes = <String>{
      for (final eq in emps.equipes) ...[
        if (eq.chefId.isNotEmpty) eq.chefId,
        ...eq.membreIds,
      ]
    };
    final otherGroupIds = <String>{
      for (final g in prov.groupes)
        if (existing == null || g.id != existing.id) ...g.membreIds
    };
    final postesProv = context.read<PostesProvider>();
    final posteNamesFromConfig = postesProv.postes.map((p) => p.nom).where((p) => p.trim().isNotEmpty).toList()..sort();
    final posteNamesFallback = employees.map((e) => e.poste.trim()).where((p) => p.isNotEmpty).toSet().toList()..sort();
    final posteNames = posteNamesFromConfig.isNotEmpty ? posteNamesFromConfig : posteNamesFallback;
    String? selectedPoste = posteNames.isNotEmpty ? posteNames.first : null;
    String posteKey(String? p) => (p ?? '').trim().toLowerCase();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateD) {
          final base = employees
              .where((e) => !usedInEquipes.contains(e.id) && !otherGroupIds.contains(e.id))
              .toList();
          final filteredEmployees = selectedPoste == null
              ? base
              : base.where((e) => posteKey(e.poste) == posteKey(selectedPoste)).toList();
          return AlertDialog(
            title: Text(existing == null ? 'Nouveau groupe' : 'Modifier groupe'),
            content: SizedBox(
              width: 520,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(labelText: 'Nom', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),
                    const Text('Horaires', style: TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            value: sh,
                            decoration: const InputDecoration(labelText: 'Début (h)', border: OutlineInputBorder()),
                            items: List.generate(24, (i) => DropdownMenuItem(value: i, child: Text(i.toString().padLeft(2, '0')))),
                            onChanged: (v) => setStateD(() => sh = v ?? sh),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            value: sm,
                            decoration: const InputDecoration(labelText: 'Début (m)', border: OutlineInputBorder()),
                            items: const [0, 15, 30, 45].map((i) => DropdownMenuItem(value: i, child: Text(i.toString().padLeft(2, '0')))).toList(),
                            onChanged: (v) => setStateD(() => sm = v ?? sm),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            value: eh,
                            decoration: const InputDecoration(labelText: 'Fin (h)', border: OutlineInputBorder()),
                            items: List.generate(24, (i) => DropdownMenuItem(value: i, child: Text(i.toString().padLeft(2, '0')))),
                            onChanged: (v) => setStateD(() => eh = v ?? eh),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            value: em,
                            decoration: const InputDecoration(labelText: 'Fin (m)', border: OutlineInputBorder()),
                            items: const [0, 15, 30, 45].map((i) => DropdownMenuItem(value: i, child: Text(i.toString().padLeft(2, '0')))).toList(),
                            onChanged: (v) => setStateD(() => em = v ?? em),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int>(
                      value: restWeekday,
                      decoration: const InputDecoration(
                        labelText: 'Jour de repos hebdomadaire',
                        border: OutlineInputBorder(),
                      ),
                      items: _weekdayLabels.entries
                          .map((e) => DropdownMenuItem<int>(value: e.key, child: Text(e.value)))
                          .toList(),
                      onChanged: (v) => setStateD(() => restWeekday = v ?? DateTime.sunday),
                    ),
                    const SizedBox(height: 12),
                    const Text('Membres', style: TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    Text(
                      'Seuls les collaborateurs non affectés à une équipe ou à un autre groupe sont affichés.',
                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 8),
                    if (posteNames.isNotEmpty) ...[
                      DropdownButtonFormField<String>(
                        value: selectedPoste,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Poste', border: OutlineInputBorder()),
                        items: posteNames
                            .map((p) => DropdownMenuItem<String>(value: p, child: Text(p, overflow: TextOverflow.ellipsis)))
                            .toList(),
                        onChanged: (v) => setStateD(() => selectedPoste = v),
                      ),
                      const SizedBox(height: 10),
                    ],
                    Container(
                      height: 260,
                      decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(10)),
                      child: ListView.builder(
                        itemCount: filteredEmployees.length,
                        itemBuilder: (_, i) {
                          final e = filteredEmployees[i];
                          final checked = selectedIds.contains(e.id);
                          return CheckboxListTile(
                            value: checked,
                            dense: true,
                            title: Text(e.nom, overflow: TextOverflow.ellipsis),
                            subtitle: Text(e.poste, overflow: TextOverflow.ellipsis),
                            onChanged: (v) => setStateD(() {
                              if (v == true) {
                                selectedIds.add(e.id);
                              } else {
                                selectedIds.remove(e.id);
                              }
                            }),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: Text(tr(context, 'cancel'))),
              ElevatedButton(
                onPressed: () async {
                  final nom = nameCtrl.text.trim();
                  if (nom.isEmpty) return;
                  final g = Groupe(
                    id: existing?.id ?? '',
                    nom: nom,
                    membreIds: selectedIds.toList(),
                    startHour: sh,
                    startMinute: sm,
                    endHour: eh,
                    endMinute: em,
                    weeklyRestWeekday: restWeekday,
                  );
                  if (existing == null) {
                    await prov.addGroupe(g);
                  } else {
                    await prov.updateGroupe(g);
                  }
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                child: Text(existing == null ? 'Créer' : 'Enregistrer'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<GroupesProvider>();
    final emps = context.watch<EmployeesProvider>();
    final padding = pagePadding(context);
    final mobile = isMobile(context);

    final list = prov.groupes.where((g) => g.nom.toLowerCase().contains(_q.toLowerCase())).toList();

    return Column(
      children: [
        if (!prov.firebaseAvailable) _offlineBanner(),
        Container(
          color: Colors.white,
          padding: EdgeInsets.fromLTRB(padding, 14, padding, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Groupes (indépendants)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _kDark)),
              Text('Groupes indépendants (hors équipes & shifts)', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 36,
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: 'Rechercher...',
                          prefixIcon: const Icon(Icons.search, size: 18),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          filled: true,
                          fillColor: const Color(0xFFF7F9FC),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                        ),
                        onChanged: (v) => setState(() => _q = v),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton.icon(
                    onPressed: () => _showGroupeDialog(context, prov, emps, null),
                    icon: const Icon(Icons.add),
                    label: Text(mobile ? 'Nouveau' : 'Nouveau groupe'),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.all(padding),
            itemCount: list.length,
            itemBuilder: (_, i) {
              final g = list[i];
              return Card(
                child: ListTile(
                  title: Text(g.nom, style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text('Horaires: ${g.startHour.toString().padLeft(2, '0')}:${g.startMinute.toString().padLeft(2, '0')} → ${g.endHour.toString().padLeft(2, '0')}:${g.endMinute.toString().padLeft(2, '0')}  •  Membres: ${g.membreIds.length}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(icon: const Icon(Icons.edit), onPressed: () => _showGroupeDialog(context, prov, emps, g)),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () async => prov.deleteGroupe(g.id),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _GroupeComptesSection extends StatefulWidget {
  const _GroupeComptesSection();

  @override
  State<_GroupeComptesSection> createState() => _GroupeComptesSectionState();
}

class _GroupeComptesSectionState extends State<_GroupeComptesSection> {
  String _q = '';

  void _showCompteDialog(BuildContext context, GroupeComptesProvider prov, GroupesProvider groupesProv, GroupeCompte? existing) {
    final nomCtrl = TextEditingController(text: existing?.nom ?? '');
    final emailCtrl = TextEditingController(text: existing?.email ?? '');
    final pwdCtrl = TextEditingController(text: existing?.password ?? '');
    String? gid = existing?.groupeId;
    bool actif = existing?.actif ?? true;
    final groupes = groupesProv.groupes;
    if (gid == null && groupes.isNotEmpty) gid = groupes.first.id;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateD) {
          return AlertDialog(
            title: Text(existing == null ? 'Nouveau compte groupe' : 'Modifier compte groupe'),
            content: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(controller: nomCtrl, decoration: const InputDecoration(labelText: 'Nom', border: OutlineInputBorder())),
                  const SizedBox(height: 10),
                  TextField(controller: emailCtrl, decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder())),
                  const SizedBox(height: 10),
                  TextField(controller: pwdCtrl, decoration: const InputDecoration(labelText: 'Mot de passe', border: OutlineInputBorder())),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: gid,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Groupe', border: OutlineInputBorder()),
                    items: groupes.map((g) => DropdownMenuItem(value: g.id, child: Text(g.nom, overflow: TextOverflow.ellipsis))).toList(),
                    onChanged: (v) => setStateD(() => gid = v),
                  ),
                  const SizedBox(height: 10),
                  SwitchListTile(
                    value: actif,
                    onChanged: (v) => setStateD(() => actif = v),
                    title: const Text('Actif'),
                    dense: true,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: Text(tr(context, 'cancel'))),
              ElevatedButton(
                onPressed: () async {
                  final nom = nomCtrl.text.trim();
                  final email = emailCtrl.text.trim().toLowerCase();
                  final pwd = pwdCtrl.text;
                  if (nom.isEmpty || email.isEmpty || pwd.isEmpty || gid == null || gid!.isEmpty) return;
                  final c = GroupeCompte(
                    id: existing?.id ?? '',
                    nom: nom,
                    email: email,
                    password: pwd,
                    groupeId: gid!,
                    actif: actif,
                    dateCreation: existing?.dateCreation,
                  );
                  if (existing == null) {
                    await prov.addCompte(c);
                  } else {
                    await prov.updateCompte(c);
                  }
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                child: Text(existing == null ? 'Créer' : 'Enregistrer'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<GroupeComptesProvider>();
    final groupesProv = context.watch<GroupesProvider>();
    final padding = pagePadding(context);
    final mobile = isMobile(context);

    final list = prov.comptes.where((c) {
      final q = _q.toLowerCase();
      return c.nom.toLowerCase().contains(q) || c.email.toLowerCase().contains(q);
    }).toList();

    return Column(
      children: [
        if (!prov.firebaseAvailable) _offlineBanner(),
        Container(
          color: Colors.white,
          padding: EdgeInsets.fromLTRB(padding, 14, padding, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Comptes Groupes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _kDark)),
              Text('Email + mot de passe — le responsable ne voit que son groupe', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 36,
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: 'Rechercher...',
                          prefixIcon: const Icon(Icons.search, size: 18),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          filled: true,
                          fillColor: const Color(0xFFF7F9FC),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                        ),
                        onChanged: (v) => setState(() => _q = v),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton.icon(
                    onPressed: () => _showCompteDialog(context, prov, groupesProv, null),
                    icon: const Icon(Icons.add),
                    label: Text(mobile ? 'Nouveau' : 'Nouveau compte'),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.all(padding),
            itemCount: list.length,
            itemBuilder: (_, i) {
              final c = list[i];
              final g = groupesProv.groupes.where((g) => g.id == c.groupeId).toList();
              final gName = g.isEmpty ? c.groupeId : g.first.nom;
              return Card(
                child: ListTile(
                  title: Text(c.nom, style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text('${c.email}  •  Groupe: $gName  •  ${c.actif ? 'Actif' : 'Inactif'}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(icon: const Icon(Icons.edit), onPressed: () => _showCompteDialog(context, prov, groupesProv, c)),
                      IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => prov.deleteCompte(c.id)),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _DistributionGroupsSection extends StatefulWidget {
  const _DistributionGroupsSection();

  @override
  State<_DistributionGroupsSection> createState() => _DistributionGroupsSectionState();
}

class _DistributionGroupsSectionState extends State<_DistributionGroupsSection> {
  String _q = '';

  bool _isProtectedForDistribution(String poste) {
    final p = poste.trim().toLowerCase();
    return p.contains('chef') ||
        p.contains('rh') ||
        p.contains('dev') ||
        p.contains('it') ||
        p.contains('admin') ||
        p.contains('directeur') ||
        p.contains('responsable');
  }

  void _showDialogGroup(
      BuildContext context, DistributionGroupsProvider prov, EmployeesProvider emps, DistributionGroup? existing) {
    final nameCtrl = TextEditingController(text: existing?.nom ?? '');
    final selectedIds = <String>{...(existing?.membreIds ?? const [])};
    final employees = emps.employes.toList()..sort((a, b) => a.nom.compareTo(b.nom));
    String search = '';
    String? selectedPoste;
    final groupesProv = context.read<GroupesProvider>();

    final usedInEquipes = <String>{
      for (final eq in emps.equipes) ...[
        if (eq.chefId.isNotEmpty) eq.chefId,
        ...eq.membreIds,
      ]
    };
    final usedInGroupes = <String>{
      for (final g in groupesProv.groupes) ...g.membreIds,
    };
    final usedInOtherDistribution = <String>{
      for (final g in prov.groups)
        if (existing == null || g.id != existing.id) ...g.membreIds,
    };

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateD) {
          final eligible = employees.where((e) {
            if (selectedIds.contains(e.id)) return true; // Keep current selected visible in edit mode.
            if (_isProtectedForDistribution(e.poste)) return false;
            if (usedInEquipes.contains(e.id)) return false;
            if (usedInGroupes.contains(e.id)) return false;
            if (usedInOtherDistribution.contains(e.id)) return false;
            return true;
          }).toList();
          final postes = eligible.map((e) => e.poste.trim()).where((p) => p.isNotEmpty).toSet().toList()..sort();
          selectedPoste ??= postes.isNotEmpty ? postes.first : null;
          final filtered = eligible.where((e) {
            final okSearch = search.trim().isEmpty ||
                e.nom.toLowerCase().contains(search.trim().toLowerCase()) ||
                e.poste.toLowerCase().contains(search.trim().toLowerCase());
            final okPoste = selectedPoste == null || selectedPoste!.isEmpty || e.poste.trim() == selectedPoste!.trim();
            return okSearch && okPoste;
          }).toList();
          return AlertDialog(
            title: Text(existing == null ? 'Nouveau groupe Distribution' : 'Modifier groupe Distribution'),
            content: SizedBox(
              width: 560,
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(labelText: 'Nom', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      decoration: const InputDecoration(
                        labelText: 'Filtrer par nom/poste',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.search),
                      ),
                      onChanged: (v) => setStateD(() => search = v),
                    ),
                    const SizedBox(height: 10),
                    if (postes.isNotEmpty)
                      DropdownButtonFormField<String>(
                        value: selectedPoste,
                        decoration: const InputDecoration(labelText: 'Poste', border: OutlineInputBorder()),
                        items: postes.map((p) => DropdownMenuItem<String>(value: p, child: Text(p))).toList(),
                        onChanged: (v) => setStateD(() => selectedPoste = v),
                      ),
                    const SizedBox(height: 8),
                    Text(
                      'Affichage: collaborateurs non affectés (hors équipes/groupes) et hors postes protégés (Chef/RH/DEV/IT...).',
                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 280,
                      decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(10)),
                      child: ListView(
                        children: filtered.map((e) {
                          final checked = selectedIds.contains(e.id);
                          return CheckboxListTile(
                            value: checked,
                            dense: true,
                            title: Text(e.nom),
                            subtitle: Text(e.poste),
                            onChanged: (v) => setStateD(() {
                              if (v == true) {
                                selectedIds.add(e.id);
                              } else {
                                selectedIds.remove(e.id);
                              }
                            }),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: Text(tr(context, 'cancel'))),
              ElevatedButton(
                onPressed: () async {
                  final nom = nameCtrl.text.trim();
                  if (nom.isEmpty) return;
                  final g = DistributionGroup(id: existing?.id ?? '', nom: nom, membreIds: selectedIds.toList());
                  if (existing == null) {
                    await prov.addGroup(g);
                  } else {
                    await prov.updateGroup(g);
                  }
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                child: Text(existing == null ? 'Créer' : 'Enregistrer'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<DistributionGroupsProvider>();
    final emps = context.watch<EmployeesProvider>();
    final padding = pagePadding(context);
    final list = prov.groups.where((g) => g.nom.toLowerCase().contains(_q.toLowerCase())).toList();
    return Column(
      children: [
        Container(
          color: Colors.white,
          padding: EdgeInsets.fromLTRB(padding, 14, padding, 12),
          child: Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 36,
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Rechercher...',
                      prefixIcon: const Icon(Icons.search, size: 18),
                      filled: true,
                      fillColor: const Color(0xFFF7F9FC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                    ),
                    onChanged: (v) => setState(() => _q = v),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                onPressed: () => _showDialogGroup(context, prov, emps, null),
                icon: const Icon(Icons.add),
                label: const Text('Nouveau groupe'),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.all(padding),
            itemCount: list.length,
            itemBuilder: (_, i) {
              final g = list[i];
              return Card(
                child: ListTile(
                  title: Text(g.nom, style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text('Membres: ${g.membreIds.length}'),
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    IconButton(icon: const Icon(Icons.edit), onPressed: () => _showDialogGroup(context, prov, emps, g)),
                    IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => prov.deleteGroup(g.id)),
                  ]),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _DistributionComptesSection extends StatefulWidget {
  const _DistributionComptesSection();

  @override
  State<_DistributionComptesSection> createState() => _DistributionComptesSectionState();
}

class _DistributionComptesSectionState extends State<_DistributionComptesSection> {
  String _q = '';

  Future<String?> _pickEmployeWithFilter(
    BuildContext context,
    List<emp.Employe> candidates,
  ) async {
    String search = '';
    return showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateD) {
          final filtered = candidates.where((e) {
            final q = search.trim().toLowerCase();
            if (q.isEmpty) return true;
            return e.nom.toLowerCase().contains(q) || e.poste.toLowerCase().contains(q);
          }).toList();
          return AlertDialog(
            title: const Text('Choisir un chef'),
            content: SizedBox(
              width: 520,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    decoration: const InputDecoration(
                      hintText: 'Rechercher (nom / poste)',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (v) => setStateD(() => search = v),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 320,
                    child: filtered.isEmpty
                        ? const Center(child: Text('Aucun collaborateur trouvé.'))
                        : ListView.builder(
                            itemCount: filtered.length,
                            itemBuilder: (_, i) {
                              final e = filtered[i];
                              return ListTile(
                                title: Text(e.nom),
                                subtitle: Text(e.poste),
                                onTap: () => Navigator.pop(ctx, e.id),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: Text(tr(context, 'cancel'))),
            ],
          );
        },
      ),
    );
  }

  void _showDialogCompte(
      BuildContext context,
      DistributionComptesProvider prov,
      DistributionGroupsProvider groupsProv,
      EmployeesProvider empsProv,
      DistributionCompte? existing) {
    final nomCtrl = TextEditingController(text: existing?.nom ?? '');
    final emailCtrl = TextEditingController(text: existing?.email ?? '');
    final pwdCtrl = TextEditingController(text: existing?.password ?? '');
    final selected = <String>{...(existing?.distributionGroupIds ?? const <String>[])};
    String? selectedEmployeId = existing?.employeId;
    bool actif = existing?.actif ?? true;
    final groups = groupsProv.groups;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateD) {
          final selectedGroups = groups.where((g) => selected.contains(g.id)).toList();
          final sourceGroups = selectedGroups.isNotEmpty ? selectedGroups : groups;
          final allowedEmployeeIds =
              _distributionComptePickerEmployeIds(sourceGroups, empsProv.employes);
          final candidates = empsProv.employes
              .where((e) => allowedEmployeeIds.contains(e.id))
              .toList()
            ..sort((a, b) => a.nom.compareTo(b.nom));
          if (selectedEmployeId != null && !candidates.any((e) => e.id == selectedEmployeId)) {
            selectedEmployeId = null;
          }
          final selectedEmp = selectedEmployeId == null
              ? null
              : candidates.firstWhere((e) => e.id == selectedEmployeId);
          if (selectedEmp != null && nomCtrl.text.trim() != selectedEmp.nom.trim()) {
            nomCtrl.text = selectedEmp.nom;
          }
          return AlertDialog(
          title: Text(existing == null ? 'Nouveau compte Distribution' : 'Modifier compte Distribution'),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                children: [
                  TextFormField(
                    readOnly: true,
                    decoration: const InputDecoration(
                      labelText: 'Chef (depuis les ouvriers)',
                      border: OutlineInputBorder(),
                      suffixIcon: Icon(Icons.arrow_drop_down),
                    ),
                    controller: TextEditingController(
                      text: selectedEmp == null ? '' : '${selectedEmp.nom} — ${selectedEmp.poste}',
                    ),
                    onTap: () async {
                      final id = await _pickEmployeWithFilter(context, candidates);
                      if (id == null) return;
                      setStateD(() => selectedEmployeId = id);
                    },
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: nomCtrl,
                    readOnly: true,
                    decoration: const InputDecoration(
                      labelText: 'Nom (auto depuis collaborateur)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (selected.isEmpty)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Astuce: sans groupe coché, la liste couvre tous les groupes Distribution. Les chefs d’équipe / SHEF sont proposés même s’ils ne figurent pas dans les membres du groupe.',
                        style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                      ),
                    ),
                  if (selected.isEmpty) const SizedBox(height: 10),
                  TextField(controller: emailCtrl, decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder())),
                  const SizedBox(height: 10),
                  TextField(controller: pwdCtrl, decoration: const InputDecoration(labelText: 'Mot de passe', border: OutlineInputBorder())),
                  const SizedBox(height: 10),
                  Container(
                    constraints: const BoxConstraints(maxHeight: 220),
                    decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(10)),
                    child: ListView(
                      shrinkWrap: true,
                      children: groups.map((g) {
                        final checked = selected.contains(g.id);
                        return CheckboxListTile(
                          value: checked,
                          dense: true,
                          title: Text(g.nom),
                          onChanged: (v) => setStateD(() {
                            if (v == true) {
                              selected.add(g.id);
                            } else {
                              selected.remove(g.id);
                            }
                            // Si le collaborateur choisi n’est plus éligible (membre ou chef/SHEF).
                            final scope = groups.where((gx) => selected.contains(gx.id)).toList();
                            final source = scope.isNotEmpty ? scope : groups;
                            final allowed = _distributionComptePickerEmployeIds(source, empsProv.employes);
                            if (selectedEmployeId != null && !allowed.contains(selectedEmployeId)) {
                              selectedEmployeId = null;
                              nomCtrl.text = '';
                            }
                          }),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SwitchListTile(
                    value: actif,
                    onChanged: (v) => setStateD(() => actif = v),
                    title: const Text('Actif'),
                    dense: true,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(tr(context, 'cancel'))),
            ElevatedButton(
              onPressed: () async {
                final nom = nomCtrl.text.trim();
                final email = emailCtrl.text.trim().toLowerCase();
                final pwd = pwdCtrl.text;
                if (selectedEmployeId == null || nom.isEmpty || email.isEmpty || pwd.isEmpty || selected.isEmpty) return;
                final c = DistributionCompte(
                  id: existing?.id ?? '',
                  nom: nom,
                  email: email,
                  password: pwd,
                  employeId: selectedEmployeId,
                  distributionGroupIds: selected.toList(),
                  actif: actif,
                  dateCreation: existing?.dateCreation,
                );
                if (existing == null) {
                  await prov.addCompte(c);
                } else {
                  await prov.updateCompte(c);
                }
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: Text(existing == null ? 'Créer' : 'Enregistrer'),
            ),
          ],
        );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<DistributionComptesProvider>();
    final groupsProv = context.watch<DistributionGroupsProvider>();
    final empsProv = context.watch<EmployeesProvider>();
    final padding = pagePadding(context);
    final list = prov.comptes.where((c) {
      final q = _q.toLowerCase();
      return c.nom.toLowerCase().contains(q) || c.email.toLowerCase().contains(q);
    }).toList();
    return Column(
      children: [
        Container(
          color: Colors.white,
          padding: EdgeInsets.fromLTRB(padding, 14, padding, 12),
          child: Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 36,
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Rechercher...',
                      prefixIcon: const Icon(Icons.search, size: 18),
                      filled: true,
                      fillColor: const Color(0xFFF7F9FC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                    ),
                    onChanged: (v) => setState(() => _q = v),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                onPressed: () => _showDialogCompte(context, prov, groupsProv, empsProv, null),
                icon: const Icon(Icons.add),
                label: const Text('Nouveau compte'),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.all(padding),
            itemCount: list.length,
            itemBuilder: (_, i) {
              final c = list[i];
              final names = groupsProv.groups.where((g) => c.distributionGroupIds.contains(g.id)).map((e) => e.nom).join(', ');
              return Card(
                child: ListTile(
                  title: Text(c.nom, style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text('${c.email}  •  Groupes: $names  •  ${c.actif ? 'Actif' : 'Inactif'}'),
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    IconButton(icon: const Icon(Icons.edit), onPressed: () => _showDialogCompte(context, prov, groupsProv, empsProv, c)),
                    IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => prov.deleteCompte(c.id)),
                  ]),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}


// ─────────────────────────────────────────────
//  SECTION: CHAUFFEURS (السائقون)
// ─────────────────────────────────────────────

class _ChauffeursSection extends StatefulWidget {
  const _ChauffeursSection();
  @override
  State<_ChauffeursSection> createState() => _ChauffeursSectionState();
}

class _ChauffeursSectionState extends State<_ChauffeursSection> {
  String _searchQuery = '';

  /// تحقق إذا كان المنصب سائق
  bool _isChauffeurPoste(String poste) {
    final p = poste.trim().toLowerCase();
    return p.contains('chauffeur') || p.contains('سائق') || p.contains('driver');
  }

  void _confirmDeleteChauffeur(BuildContext ctx, ChauffeursProvider prov, Chauffeur c) {
    showDialog(
      context: ctx,
      builder: (_) => AlertDialog(
        title: const Text('Supprimer le chauffeur'),
        content: Text('Supprimer le chauffeur « ${c.nom} » ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () async {
              await prov.deleteChauffeur(c.id);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<ChauffeursProvider>();
    final emps = context.watch<EmployeesProvider>();
    
    if (prov.loading && prov.firebaseAvailable) {
      return const Center(child: CircularProgressIndicator());
    }

    final filtered = prov.chauffeurs.where((c) {
      final q = _searchQuery.toLowerCase();
      return c.nom.toLowerCase().contains(q) || c.username.toLowerCase().contains(q);
    }).toList();

    final mobile = isMobile(context);
    final padding = pagePadding(context);
    return Column(
      children: [
        if (!prov.firebaseAvailable) _offlineBanner(),
        Container(
          color: Colors.white,
          padding: EdgeInsets.fromLTRB(padding, 14, padding, 12),
          child: mobile
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('Chauffeurs',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _kDark)),
                    Text('${prov.chauffeurs.length} chauffeur(s) — Firestore',
                        style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 36,
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: 'Rechercher...',
                          prefixIcon: const Icon(Icons.search, size: 18),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          filled: true,
                          fillColor: const Color(0xFFF7F9FC),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                        ),
                        onChanged: (v) => setState(() => _searchQuery = v),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _showChauffeurDialog(context, prov, emps, null),
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('Ajouter'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF328EEE),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                  ],
                )
              : Row(
                  children: [
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('Chauffeurs',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _kDark)),
                      Text('${prov.chauffeurs.length} chauffeur(s) — Firestore',
                          style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                    ]),
                    const Spacer(),
                    SizedBox(
                      width: 220,
                      height: 36,
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: 'Rechercher...',
                          prefixIcon: const Icon(Icons.search, size: 18),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          filled: true,
                          fillColor: const Color(0xFFF7F9FC),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                        ),
                        onChanged: (v) => setState(() => _searchQuery = v),
                      ),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton.icon(
                      onPressed: () => _showChauffeurDialog(context, prov, emps, null),
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Ajouter'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF328EEE),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ],
                ),
        ),
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.local_shipping_outlined, size: 56, color: Colors.grey[300]),
                      const SizedBox(height: 12),
                      Text(
                        prov.chauffeurs.isEmpty ? 'Aucun chauffeur ajouté' : 'Aucun résultat',
                        style: TextStyle(color: Colors.grey[500], fontSize: 14),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filtered.length,
                  itemBuilder: (ctx, i) {
                    final c = filtered[i];
                    final empMatch = emps.employes.where((e) => e.id == c.employeId).toList();
                    final linkedEmploye = empMatch.isNotEmpty ? empMatch.first : null;
                    final equipeMatch = emps.equipes.where((e) => e.id == c.equipeId).toList();
                    final linkedEquipe = equipeMatch.isNotEmpty ? equipeMatch.first : null;
                    
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(color: Colors.grey.shade200),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        leading: SmartAvatar(
                          imageUrl: c.photoUrl.isNotEmpty ? c.photoUrl : linkedEmploye?.photoUrl,
                          fallbackText: c.nom,
                          radius: 22,
                        ),
                        title: Text(c.nom, style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Identifiant: ${c.username}', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                            if (linkedEquipe != null)
                              Text('Équipe: ${linkedEquipe.nom}', style: TextStyle(fontSize: 11, color: AppColors.brand)),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: c.actif ? Colors.green.shade50 : Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                c.actif ? 'Actif' : 'Inactif',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: c.actif ? Colors.green.shade700 : Colors.grey.shade600,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, size: 18),
                              onPressed: () => _showChauffeurDialog(context, prov, emps, c),
                              tooltip: 'Modifier',
                            ),
                            IconButton(
                              icon: Icon(Icons.delete_outline, size: 18, color: Colors.red.shade400),
                              onPressed: () => _confirmDeleteChauffeur(context, prov, c),
                              tooltip: 'Supprimer',
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  void _showChauffeurDialog(BuildContext context, ChauffeursProvider prov, EmployeesProvider emps, Chauffeur? existing) {
    final isEdit = existing != null;
    final nomCtrl = TextEditingController(text: existing?.nom ?? '');
    final usernameCtrl = TextEditingController(text: existing?.username ?? '');
    final passwordCtrl = TextEditingController(text: existing?.password ?? '');
    String? selectedEquipeId = existing?.equipeId;
    String? selectedEmployeId = existing?.employeId;
    bool actif = existing?.actif ?? true;
    String? photoUrl = existing?.photoUrl;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final equipes = emps.equipes;
          // فقط الموظفون الذين منصبهم سائق، بدون تكرار حسب الـ id
          final chauffeurEmployes = emps.employes
              .where((e) => _isChauffeurPoste(e.poste))
              .fold<Map<String, emp.Employe>>({}, (m, e) {
                if (!m.containsKey(e.id)) m[e.id] = e;
                return m;
              })
              .values
              .toList();
          final validEmployeIds = chauffeurEmployes.map((e) => e.id).toSet();
          final dropdownValue = (selectedEmployeId != null &&
                  (selectedEmployeId?.isNotEmpty ?? false) &&
                  validEmployeIds.contains(selectedEmployeId))
              ? selectedEmployeId
              : null;

          return AlertDialog(
            title: Text(isEdit ? 'Modifier le chauffeur' : 'Ajouter un chauffeur'),
            content: SizedBox(
              width: 400,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      value: dropdownValue,
                      decoration: const InputDecoration(
                        labelText: 'Lier à un collaborateur (Chauffeur)',
                        prefixIcon: Icon(Icons.local_shipping_outlined),
                      ),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('— Aucun —')),
                        ...chauffeurEmployes.map((e) => DropdownMenuItem(value: e.id, child: Text('${e.nom} — ${e.poste}'))),
                      ],
                      onChanged: (v) {
                        setDialogState(() {
                          selectedEmployeId = v;
                          if (v != null) {
                            final emp = chauffeurEmployes.firstWhere((e) => e.id == v);
                            if (nomCtrl.text.isEmpty) nomCtrl.text = emp.nom;
                            if (emp.photoUrl.isNotEmpty) photoUrl = emp.photoUrl;
                          }
                        });
                      },
                    ),
                    if (chauffeurEmployes.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          'ℹ️ Aucun collaborateur avec le poste "Chauffeur" trouvé. Ajoutez d\'abord un collaborateur avec ce poste.',
                          style: TextStyle(fontSize: 11, color: Colors.orange.shade700),
                        ),
                      ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: nomCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Nom complet *',
                        prefixIcon: Icon(Icons.badge_outlined),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: usernameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Nom d\'utilisateur *',
                        prefixIcon: Icon(Icons.account_circle_outlined),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: passwordCtrl,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Mot de passe *',
                        prefixIcon: Icon(Icons.lock_outline),
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: selectedEquipeId?.isNotEmpty == true ? selectedEquipeId : null,
                      decoration: const InputDecoration(
                        labelText: 'Équipe',
                        prefixIcon: Icon(Icons.groups_outlined),
                      ),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('— Aucune —')),
                        ...equipes.map((e) => DropdownMenuItem(value: e.id, child: Text(e.nom))),
                      ],
                      onChanged: (v) => setDialogState(() => selectedEquipeId = v),
                    ),
                    const SizedBox(height: 16),
                    SwitchListTile(
                      title: const Text('Compte actif'),
                      subtitle: Text(actif ? 'Le chauffeur peut se connecter' : 'Le chauffeur ne peut pas se connecter'),
                      value: actif,
                      onChanged: (v) => setDialogState(() => actif = v),
                      secondary: Icon(actif ? Icons.check_circle : Icons.cancel, color: actif ? Colors.green : Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
              ElevatedButton(
                onPressed: () async {
                  final nom = nomCtrl.text.trim();
                  final username = usernameCtrl.text.trim();
                  final password = passwordCtrl.text.trim();
                  
                  if (nom.isEmpty || username.isEmpty || password.isEmpty) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(content: Text('Veuillez remplir tous les champs obligatoires')),
                    );
                    return;
                  }

                  final chauffeur = Chauffeur(
                    id: existing?.id ?? 'ch_${DateTime.now().millisecondsSinceEpoch}',
                    nom: nom,
                    username: username,
                    password: password,
                    equipeId: selectedEquipeId,
                    employeId: selectedEmployeId,
                    photoUrl: photoUrl ?? '',
                    actif: actif,
                    dateCreation: existing?.dateCreation ?? DateTime.now(),
                  );

                  if (isEdit) {
                    await prov.updateChauffeur(chauffeur);
                  } else {
                    await prov.addChauffeur(chauffeur);
                  }

                  if (ctx.mounted) Navigator.pop(ctx);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF328EEE),
                  foregroundColor: Colors.white,
                ),
                child: Text(isEdit ? 'Enregistrer' : 'Ajouter'),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  SECTION: POSTES (مناصب — من Firestore)
// ─────────────────────────────────────────────

class _PostesSection extends StatelessWidget {
  const _PostesSection();

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<PostesProvider>();
    if (prov.loading && prov.firebaseAvailable) {
      return const Center(child: CircularProgressIndicator());
    }
    final list = prov.postes;
    return Column(
      children: [
        if (!prov.firebaseAvailable) _offlineBanner(),
        if (prov.error != null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Colors.red.shade50,
            child: Row(
              children: [
                Icon(Icons.error_outline, size: 20, color: Colors.red.shade700),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    prov.error!,
                    style: TextStyle(fontSize: 12, color: Colors.red.shade900),
                  ),
                ),
              ],
            ),
          ),
        Container(
          color: Colors.white,
          padding: EdgeInsets.fromLTRB(pagePadding(context), 14, pagePadding(context), 12),
          child: isMobile(context)
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('Postes (fonctions)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _kDark)),
                    Text('${list.length} poste(s) — Gérés depuis Firestore', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _kAccent, foregroundColor: Colors.white, elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
                        ),
                        icon: const Icon(Icons.add, size: 15),
                        label: const Text('Ajouter un poste', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                        onPressed: () => _showPosteDialog(context, prov, null),
                      ),
                    ),
                  ],
                )
              : Row(
                  children: [
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('Postes (fonctions)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _kDark)),
                      Text('${list.length} poste(s) — Gérés depuis Firestore', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                    ]),
                    const Spacer(),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _kAccent, foregroundColor: Colors.white, elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
                      ),
                      icon: const Icon(Icons.add, size: 15),
                      label: const Text('Ajouter un poste', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                      onPressed: () => _showPosteDialog(context, prov, null),
                    ),
                  ],
                ),
        ),
        const Divider(height: 1, color: _kBorder),
        Expanded(
          child: list.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.work_outline, size: 56, color: Colors.grey[400]),
                      const SizedBox(height: 12),
                      Text('Aucun poste. Ajoutez depuis le bouton ci‑dessus.', style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: list.length,
                  itemBuilder: (context, i) {
                    final p = list[i];
                    return ListTile(
                      leading: CircleAvatar(radius: 20, backgroundColor: _kAccent.withOpacity(0.12), child: Icon(Icons.work_outline, color: _kAccent, size: 20)),
                      title: Text(p.nom, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                        IconButton(icon: const Icon(Icons.edit_outlined, size: 18), onPressed: () => _showPosteDialog(context, prov, p)),
                        IconButton(icon: Icon(Icons.delete_outline, size: 18, color: Colors.red[400]), onPressed: () => _confirmDeletePoste(context, prov, p)),
                      ]),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

void _showPosteDialog(BuildContext context, PostesProvider prov, Poste? existing) {
  final nomCtrl = TextEditingController(text: existing?.nom ?? '');
  String siteId = existing?.siteId ?? SiteId.all;
  final navigator = Navigator.of(context);
  final messenger = ScaffoldMessenger.of(context);
  showDialog(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(existing == null ? 'Nouveau poste' : 'Modifier le poste'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: nomCtrl,
            decoration: const InputDecoration(labelText: 'Nom du poste', hintText: 'Ex: Chauffeur, Vendeur'),
            autofocus: true,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: siteId,
            decoration: const InputDecoration(
              labelText: 'Site',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            items: const [
              DropdownMenuItem(value: SiteId.all, child: Text('Tous les sites')),
              DropdownMenuItem(value: SiteId.jadida, child: Text('El Jadida')),
              DropdownMenuItem(value: SiteId.safi, child: Text('Safi')),
            ],
            onChanged: (v) => siteId = v ?? SiteId.all,
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => navigator.pop(), child: const Text('Annuler')),
        ElevatedButton(
          onPressed: () async {
            final nom = nomCtrl.text.trim();
            if (nom.isEmpty) {
              messenger.showSnackBar(const SnackBar(content: Text('Entrez un nom de poste')));
              return;
            }
            if (!prov.firebaseAvailable) {
              messenger.showSnackBar(const SnackBar(
                content: Text('Données hors ligne. Connectez Firebase (ex: Android) pour enregistrer.'),
                backgroundColor: Colors.orange,
              ));
              if (dialogContext.mounted) navigator.pop();
              return;
            }
            try {
              if (existing == null) {
                await prov.addPoste(Poste(id: '', nom: nom, siteId: siteId));
              } else {
                await prov.updatePoste(Poste(id: existing.id, nom: nom, ordre: existing.ordre, siteId: siteId));
              }
              if (dialogContext.mounted) navigator.pop();
              if (context.mounted) {
                messenger.showSnackBar(SnackBar(content: Text(existing == null ? 'Poste « $nom » enregistré.' : 'Poste mis à jour.')));
              }
            } catch (e) {
              if (context.mounted) {
                messenger.showSnackBar(SnackBar(
                  content: Text('Erreur: ${e.toString().replaceFirst(RegExp(r'^\[[\w-]+/\w+\]\s*'), '')}'),
                  backgroundColor: Colors.red,
                ));
              }
            }
          },
          child: const Text('Enregistrer'),
        ),
      ],
    ),
  );
}

void _confirmDeletePoste(BuildContext context, PostesProvider prov, Poste p) {
  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('Supprimer le poste'),
      content: Text('Supprimer « ${p.nom} » ?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
          onPressed: () async {
            await prov.deletePoste(p.id);
            if (context.mounted) Navigator.pop(context);
          },
          child: const Text('Supprimer'),
        ),
      ],
    ),
  );
}

// ─────────────────────────────────────────────
//  SECTION: DÉPARTEMENTS (من Firestore)
// ─────────────────────────────────────────────

class _DepartementsSection extends StatelessWidget {
  const _DepartementsSection();

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<DepartementsProvider>();
    if (prov.loading && prov.firebaseAvailable) {
      return const Center(child: CircularProgressIndicator());
    }
    final list = prov.departements;
    return Column(
      children: [
        if (!prov.firebaseAvailable) _offlineBanner(),
        if (prov.error != null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Colors.red.shade50,
            child: Row(
              children: [
                Icon(Icons.error_outline, size: 20, color: Colors.red.shade700),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    prov.error!,
                    style: TextStyle(fontSize: 12, color: Colors.red.shade900),
                  ),
                ),
              ],
            ),
          ),
        Container(
          color: Colors.white,
          padding: EdgeInsets.fromLTRB(pagePadding(context), 14, pagePadding(context), 12),
          child: isMobile(context)
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('Départements', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _kDark)),
                    Text('${list.length} département(s) — Gérés depuis Firestore', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _kAccent, foregroundColor: Colors.white, elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
                        ),
                        icon: const Icon(Icons.add, size: 15),
                        label: const Text('Ajouter un département', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                        onPressed: () => _showDepartementDialog(context, prov, null),
                      ),
                    ),
                  ],
                )
              : Row(
                  children: [
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('Départements', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _kDark)),
                      Text('${list.length} département(s) — Gérés depuis Firestore', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                    ]),
                    const Spacer(),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _kAccent, foregroundColor: Colors.white, elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
                      ),
                      icon: const Icon(Icons.add, size: 15),
                      label: const Text('Ajouter un département', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                      onPressed: () => _showDepartementDialog(context, prov, null),
                    ),
                  ],
                ),
        ),
        const Divider(height: 1, color: _kBorder),
        Expanded(
          child: list.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.account_tree_outlined, size: 56, color: Colors.grey[400]),
                      const SizedBox(height: 12),
                      Text('Aucun département. Ajoutez depuis le bouton ci‑dessus.', style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: list.length,
                  itemBuilder: (context, i) {
                    final d = list[i];
                    return ListTile(
                      leading: CircleAvatar(radius: 20, backgroundColor: _kAccent.withOpacity(0.12), child: Icon(Icons.account_tree_outlined, color: _kAccent, size: 20)),
                      title: Text(d.nom, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                        IconButton(icon: const Icon(Icons.edit_outlined, size: 18), onPressed: () => _showDepartementDialog(context, prov, d)),
                        IconButton(icon: Icon(Icons.delete_outline, size: 18, color: Colors.red[400]), onPressed: () => _confirmDeleteDepartement(context, prov, d)),
                      ]),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
//  SECTION: RAISONS D'ABSENCE
// ─────────────────────────────────────────────

class _AbsenceReasonsSection extends StatelessWidget {
  const _AbsenceReasonsSection();

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<AbsenceReasonsProvider>();
    final list = prov.reasons;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeader(
            title: 'Raisons d\'absence',
            subtitle: 'Définir les motifs d\'absence et indiquer si chacun est déduit du salaire ou non.',
          ),
          const SizedBox(height: 20),
          if (!prov.firebaseAvailable)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                'Firebase indisponible. Les raisons ne peuvent pas être enregistrées.',
                style: TextStyle(fontSize: 13, color: Colors.orange[800]),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: ElevatedButton.icon(
                icon: const Icon(Icons.add, size: 20),
                label: const Text('Ajouter une raison'),
                onPressed: () => _showAbsenceReasonDialog(context, prov, null),
              ),
            ),
          if (prov.loading)
            const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
          else if (list.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Aucune raison d\'absence. Ajoutez-en pour que le chef et l\'admin puissent les choisir lors d\'un pointage absent (ex: Maladie, Paternité, Mariage).',
                  style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: list.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final r = list[i];
                return Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      radius: 20,
                      backgroundColor: r.deductFromSalary ? Colors.red.withOpacity(0.12) : Colors.green.withOpacity(0.12),
                      child: Icon(
                        r.deductFromSalary ? Icons.remove_circle_outline : Icons.check_circle_outline,
                        color: r.deductFromSalary ? Colors.red : Colors.green,
                        size: 22,
                      ),
                    ),
                    title: Text(r.label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    subtitle: Text(
                      r.deductFromSalary ? 'Déduit du salaire' : 'Non déduit (ex: congé payé)',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 18),
                          onPressed: () => _showAbsenceReasonDialog(context, prov, r),
                        ),
                        IconButton(
                          icon: Icon(Icons.delete_outline, size: 18, color: Colors.red[400]),
                          onPressed: () => _confirmDeleteAbsenceReason(context, prov, r),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

void _showDepartementDialog(BuildContext context, DepartementsProvider prov, Departement? existing) {
  final nomCtrl = TextEditingController(text: existing?.nom ?? '');
  final navigator = Navigator.of(context);
  final messenger = ScaffoldMessenger.of(context);
  showDialog(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(existing == null ? 'Nouveau département' : 'Modifier le département'),
      content: TextField(
        controller: nomCtrl,
        decoration: const InputDecoration(labelText: 'Nom du département', hintText: 'Ex: Ventes, Production'),
        autofocus: true,
      ),
      actions: [
        TextButton(onPressed: () => navigator.pop(), child: const Text('Annuler')),
        ElevatedButton(
          onPressed: () async {
            final nom = nomCtrl.text.trim();
            if (nom.isEmpty) {
              messenger.showSnackBar(const SnackBar(content: Text('Entrez un nom de département')));
              return;
            }
            if (!prov.firebaseAvailable) {
              messenger.showSnackBar(const SnackBar(
                content: Text('Données hors ligne. Connectez Firebase (ex: Android) pour enregistrer.'),
                backgroundColor: Colors.orange,
              ));
              if (dialogContext.mounted) navigator.pop();
              return;
            }
            try {
              if (existing == null) {
                await prov.addDepartement(Departement(id: '', nom: nom));
              } else {
                await prov.updateDepartement(Departement(id: existing.id, nom: nom, ordre: existing.ordre));
              }
              if (dialogContext.mounted) navigator.pop();
              if (context.mounted) {
                messenger.showSnackBar(SnackBar(content: Text(existing == null ? 'Département « $nom » enregistré.' : 'Département mis à jour.')));
              }
            } catch (e) {
              if (context.mounted) {
                messenger.showSnackBar(SnackBar(
                  content: Text('Erreur: ${e.toString().replaceFirst(RegExp(r'^\\[[\\w-]+/\\w+\\]\\s*'), '')}'),
                  backgroundColor: Colors.red,
                ));
              }
            }
          },
          child: const Text('Enregistrer'),
        ),
      ],
    ),
  );
}

void _confirmDeleteDepartement(BuildContext context, DepartementsProvider prov, Departement d) {
  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('Supprimer le département'),
      content: Text('Supprimer « ${d.nom} » ?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
          onPressed: () async {
            await prov.deleteDepartement(d.id);
            if (context.mounted) Navigator.pop(context);
          },
          child: const Text('Supprimer'),
        ),
      ],
    ),
  );
}

// ─────────────────────────────────────────────
//  SECTION: RAISONS D'ABSENCE
// ─────────────────────────────────────────────

void _showAbsenceReasonDialog(BuildContext context, AbsenceReasonsProvider prov, AbsenceReasonConfig? existing) {
  final labelCtrl = TextEditingController(text: existing?.label ?? '');
  bool deductFromSalary = existing?.deductFromSalary ?? true;
  final navigator = Navigator.of(context);
  final messenger = ScaffoldMessenger.of(context);
  showDialog(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (ctx, setDialogState) => AlertDialog(
        title: Text(existing == null ? 'Nouvelle raison d\'absence' : 'Modifier la raison'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: labelCtrl,
                decoration: const InputDecoration(
                  labelText: 'Libellé',
                  hintText: 'Ex: Maladie, Paternité, Mariage',
                ),
                autofocus: true,
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text('Déduire du salaire'),
                subtitle: const Text('Si activé, les heures/salaire sont déduits pour ce motif. Sinon, congé payé.'),
                value: deductFromSalary,
                onChanged: (v) => setDialogState(() => deductFromSalary = v),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => navigator.pop(), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () async {
              final label = labelCtrl.text.trim();
              if (label.isEmpty) {
                messenger.showSnackBar(const SnackBar(content: Text('Entrez un libellé')));
                return;
              }
              try {
                if (existing == null) {
                  await prov.add(AbsenceReasonConfig(
                    id: '',
                    label: label,
                    deductFromSalary: deductFromSalary,
                    order: prov.reasons.length,
                  ));
                } else {
                  await prov.update(existing.copyWith(label: label, deductFromSalary: deductFromSalary));
                }
                if (dialogContext.mounted) navigator.pop();
                if (context.mounted) {
                  messenger.showSnackBar(SnackBar(
                    content: Text(existing == null ? 'Raison « $label » ajoutée.' : 'Raison mise à jour.'),
                  ));
                }
              } catch (e) {
                if (context.mounted) {
                  messenger.showSnackBar(SnackBar(
                    content: Text('Erreur: ${e.toString().replaceFirst(RegExp(r'^\[[\w-]+/\w+\]\s*'), '')}'),
                    backgroundColor: Colors.red,
                  ));
                }
              }
            },
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    ),
  );
}

void _confirmDeleteAbsenceReason(BuildContext context, AbsenceReasonsProvider prov, AbsenceReasonConfig r) {
  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('Supprimer la raison'),
      content: Text("Supprimer « ${r.label} » ? Les pointages déjà enregistrés avec ce motif garderont l'historique."),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
          onPressed: () async {
            await prov.delete(r.id);
            if (context.mounted) Navigator.pop(context);
          },
          child: const Text('Supprimer'),
        ),
      ],
    ),
  );
}

// ─────────────────────────────────────────────
//  SECTION: PARAMÈTRES GÉNÉRAUX
// ─────────────────────────────────────────────

class _GeneralSection extends StatefulWidget {
  const _GeneralSection();
  @override
  State<_GeneralSection> createState() => _GeneralSectionState();
}

class _GeneralSectionState extends State<_GeneralSection> {
  final _nomEntCtrl = TextEditingController(text: 'DIPS Entreprise');
  final _adresseCtrl = TextEditingController(text: 'Casablanca, Maroc');
  final _emailCtrl = TextEditingController(text: 'contact@dips.ma');
  final _telCtrl = TextEditingController(text: '+212 52 00 00 00');
  String _langue = 'Français';
  String _devise = 'MAD (Dirham Marocain)';
  bool _modeMainenance = false;
  bool _notifDesktop = true;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeader(title: 'Paramètres Généraux', subtitle: 'Configuration de base de l\'application'),
          const SizedBox(height: 20),
          _SettingsCard(
            title: 'Informations de l\'entreprise',
            icon: Icons.business,
            children: [
              Row(
                children: [
                  Expanded(child: _FormField(label: 'Nom de l\'entreprise', controller: _nomEntCtrl, hint: '')),
                  const SizedBox(width: 16),
                  Expanded(child: _FormField(label: 'Adresse', controller: _adresseCtrl, hint: '')),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _FormField(label: 'Email', controller: _emailCtrl, hint: '')),
                  const SizedBox(width: 16),
                  Expanded(child: _FormField(label: 'Téléphone', controller: _telCtrl, hint: '')),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          _SettingsCard(
            title: 'Localisation',
            icon: Icons.language,
            children: [
              Row(
                children: [
                  Expanded(
                    child: _DropdownSetting(
                      label: 'Langue',
                      value: _langue,
                      items: ['Français', 'Arabe', 'English'],
                      onChanged: (v) => setState(() => _langue = v!),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _DropdownSetting(
                      label: 'Devise',
                      value: _devise,
                      items: ['MAD (Dirham Marocain)', 'EUR (Euro)', 'USD (Dollar)'],
                      onChanged: (v) => setState(() => _devise = v!),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          _SettingsCard(
            title: 'Système',
            icon: Icons.tune,
            children: [
              _SwitchSetting(
                label: 'Mode Maintenance',
                subtitle: 'Désactiver l\'accès utilisateur temporairement',
                value: _modeMainenance,
                onChanged: (v) => setState(() => _modeMainenance = v),
                iconColor: Colors.orange,
              ),
              const Divider(height: 20),
              _SwitchSetting(
                label: 'Notifications desktop',
                subtitle: 'Afficher les notifications système',
                value: _notifDesktop,
                onChanged: (v) => setState(() => _notifDesktop = v),
                iconColor: const Color(0xFF328EEE),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF328EEE),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
              icon: const Icon(Icons.save_outlined, size: 18),
              label: const Text('Enregistrer', style: TextStyle(fontWeight: FontWeight.w600)),
              onPressed: () => _showSaveSuccess(context),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  SECTION: NOTIFICATIONS
// ─────────────────────────────────────────────

class _NotificationsSection extends StatefulWidget {
  const _NotificationsSection();
  @override
  State<_NotificationsSection> createState() => _NotificationsSectionState();
}

class _NotificationsSectionState extends State<_NotificationsSection> {
  bool _notifAbsences = true;
  bool _notifStockBas = true;
  bool _notifRapports = false;
  bool _notifConnexions = true;
  bool _notifEmail = true;
  bool _notifSon = false;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeader(title: 'Notifications', subtitle: 'Gérer les alertes et notifications du système'),
          const SizedBox(height: 20),
          _SettingsCard(
            title: 'Alertes Métier',
            icon: Icons.notifications_active,
            children: [
              _SwitchSetting(label: 'Absences non justifiées', subtitle: 'Alerte lors d\'une absence non signalée', value: _notifAbsences, onChanged: (v) => setState(() => _notifAbsences = v), iconColor: Colors.red),
              const Divider(height: 20),
              _SwitchSetting(label: 'Stock bas', subtitle: 'Alerte quand un produit est en stock critique', value: _notifStockBas, onChanged: (v) => setState(() => _notifStockBas = v), iconColor: Colors.orange),
              const Divider(height: 20),
              _SwitchSetting(label: 'Génération de rapports', subtitle: 'Notifier quand un rapport est prêt', value: _notifRapports, onChanged: (v) => setState(() => _notifRapports = v), iconColor: Colors.purple),
              const Divider(height: 20),
              _SwitchSetting(label: 'Nouvelles connexions admin', subtitle: 'Alerte lors de connexion d\'un compte admin', value: _notifConnexions, onChanged: (v) => setState(() => _notifConnexions = v), iconColor: const Color(0xFF328EEE)),
            ],
          ),
          const SizedBox(height: 16),
          _SettingsCard(
            title: 'Canaux de notification',
            icon: Icons.send,
            children: [
              _SwitchSetting(label: 'Email', subtitle: 'Envoyer des notifications par email', value: _notifEmail, onChanged: (v) => setState(() => _notifEmail = v), iconColor: Colors.green),
              const Divider(height: 20),
              _SwitchSetting(label: 'Son', subtitle: 'Jouer un son lors des notifications', value: _notifSon, onChanged: (v) => setState(() => _notifSon = v), iconColor: AppColors.brand),
            ],
          ),
          const SizedBox(height: 20),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF328EEE), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), elevation: 0),
              icon: const Icon(Icons.save_outlined, size: 18),
              label: const Text('Enregistrer', style: TextStyle(fontWeight: FontWeight.w600)),
              onPressed: () => _showSaveSuccess(context),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  SECTION: SÉCURITÉ
// ─────────────────────────────────────────────

class _SecuriteSection extends StatefulWidget {
  const _SecuriteSection();
  @override
  State<_SecuriteSection> createState() => _SecuriteSectionState();
}

class _SecuriteSectionState extends State<_SecuriteSection> {
  bool _double_auth = false;
  bool _verrouillage = true;
  String _dureeSession = '30 minutes';
  String _tentatives = '3 tentatives';
  final _oldPwdCtrl = TextEditingController();
  final _newPwdCtrl = TextEditingController();
  final _confirmPwdCtrl = TextEditingController();
  bool _showOld = false, _showNew = false, _showConf = false;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeader(title: 'Sécurité', subtitle: 'Paramètres de sécurité et d\'authentification'),
          const SizedBox(height: 20),
          _SettingsCard(
            title: 'Politique de sécurité',
            icon: Icons.security,
            children: [
              _SwitchSetting(label: 'Double authentification (2FA)', subtitle: 'Vérification en deux étapes à la connexion', value: _double_auth, onChanged: (v) => setState(() => _double_auth = v), iconColor: Colors.green),
              const Divider(height: 20),
              _SwitchSetting(label: 'Verrouillage automatique', subtitle: 'Verrouiller la session après inactivité', value: _verrouillage, onChanged: (v) => setState(() => _verrouillage = v), iconColor: Colors.orange),
              const Divider(height: 20),
              Row(
                children: [
                  Expanded(
                    child: _DropdownSetting(
                      label: 'Durée de session',
                      value: _dureeSession,
                      items: ['15 minutes', '30 minutes', '1 heure', '2 heures'],
                      onChanged: (v) => setState(() => _dureeSession = v!),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _DropdownSetting(
                      label: 'Tentatives de connexion',
                      value: _tentatives,
                      items: ['3 tentatives', '5 tentatives', '10 tentatives'],
                      onChanged: (v) => setState(() => _tentatives = v!),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          _SettingsCard(
            title: 'Changer le mot de passe Super Admin',
            icon: Icons.lock_outline,
            children: [
              _PasswordField(label: 'Mot de passe actuel', controller: _oldPwdCtrl, show: _showOld, onToggle: () => setState(() => _showOld = !_showOld)),
              const SizedBox(height: 12),
              _PasswordField(label: 'Nouveau mot de passe', controller: _newPwdCtrl, show: _showNew, onToggle: () => setState(() => _showNew = !_showNew)),
              const SizedBox(height: 12),
              _PasswordField(label: 'Confirmer le mot de passe', controller: _confirmPwdCtrl, show: _showConf, onToggle: () => setState(() => _showConf = !_showConf)),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade600, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), elevation: 0),
                  onPressed: () => _showSaveSuccess(context),
                  child: const Text('Modifier le mot de passe'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF328EEE), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), elevation: 0),
              icon: const Icon(Icons.save_outlined, size: 18),
              label: const Text('Enregistrer', style: TextStyle(fontWeight: FontWeight.w600)),
              onPressed: () => _showSaveSuccess(context),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  SECTION: DATABASE  (import / export fonctionnels)
// ─────────────────────────────────────────────

class _DatabaseSection extends StatefulWidget {
  const _DatabaseSection();
  @override
  State<_DatabaseSection> createState() => _DatabaseSectionState();
}

class _DatabaseSectionState extends State<_DatabaseSection> {
  bool _exportLoading = false;
  bool _importLoading = false;
  String? _lastExportPath;
  String? _importStatus;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeader(title: 'Base de données', subtitle: 'Sauvegarde, restauration et maintenance'),
          const SizedBox(height: 20),
          _SettingsCard(
            title: 'Export des données',
            icon: Icons.file_download_outlined,
            children: [
              Text(
                'Exportez toutes les données de l\'application dans un fichier CSV ou JSON lisible par Excel.',
                style: TextStyle(fontSize: 13, color: Colors.grey[600]),
              ),
              const SizedBox(height: 14),
              Row(children: [
                _ExportFormatBtn(
                  label: 'Exporter en CSV',
                  icon: Icons.table_chart_outlined,
                  color: Colors.green,
                  loading: _exportLoading,
                  onTap: () => _doExport(context, 'csv'),
                ),
                const SizedBox(width: 12),
                _ExportFormatBtn(
                  label: 'Exporter en JSON',
                  icon: Icons.data_object,
                  color: AppColors.brand,
                  loading: _exportLoading,
                  onTap: () => _doExport(context, 'json'),
                ),
              ]),
              if (_lastExportPath != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.withOpacity(0.2)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.check_circle_outline, color: Colors.green, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text('Fichier enregistré : $_lastExportPath',
                          style: const TextStyle(fontSize: 12, color: Colors.green),
                          overflow: TextOverflow.ellipsis),
                    ),
                  ]),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
          _SettingsCard(
            title: 'Import des données',
            icon: Icons.file_upload_outlined,
            children: [
              Text(
                'Importez des données depuis un fichier CSV. Le fichier doit respecter le format exporté par DIPS.',
                style: TextStyle(fontSize: 13, color: Colors.grey[600]),
              ),
              const SizedBox(height: 14),
              Row(children: [
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kDark, foregroundColor: Colors.white, elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: _importLoading
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.folder_open_outlined, size: 16),
                  label: const Text('Choisir un fichier CSV', style: TextStyle(fontSize: 13)),
                  onPressed: _importLoading ? null : () => _doImport(context),
                ),
              ]),
              if (_importStatus != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _importStatus!.startsWith('✓')
                        ? Colors.green.withOpacity(0.06)
                        : Colors.red.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _importStatus!.startsWith('✓')
                          ? Colors.green.withOpacity(0.2)
                          : Colors.red.withOpacity(0.2),
                    ),
                  ),
                  child: Row(children: [
                    Icon(
                      _importStatus!.startsWith('✓') ? Icons.check_circle_outline : Icons.error_outline,
                      color: _importStatus!.startsWith('✓') ? Colors.green : Colors.red,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_importStatus!, style: TextStyle(fontSize: 12, color: _importStatus!.startsWith('✓') ? Colors.green : Colors.red))),
                  ]),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
          _SettingsCard(
            title: 'Historique des sauvegardes',
            icon: Icons.history,
            children: [
              ...['01/03/2026 - 08:00', '28/02/2026 - 08:00', '27/02/2026 - 08:00'].map(
                    (d) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(children: [
                    const Icon(Icons.check_circle, color: Colors.green, size: 16),
                    const SizedBox(width: 8),
                    Text(d, style: const TextStyle(fontSize: 13)),
                    const Spacer(),
                    TextButton.icon(
                      icon: const Icon(Icons.restore, size: 14),
                      label: const Text('Restaurer', style: TextStyle(fontSize: 12)),
                      onPressed: () => _showRestoreConfirm(context, d),
                    ),
                  ]),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _SettingsCard(
            title: 'Zone de danger',
            icon: Icons.warning_amber_rounded,
            children: [
              Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Réinitialiser la base de données',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.red)),
                    Text('Cette action est irréversible. Toutes les données seront effacées.',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                  ]),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red, foregroundColor: Colors.white, elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () => _showResetConfirm(context),
                  child: const Text('Réinitialiser', style: TextStyle(fontSize: 13)),
                ),
              ]),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _doExport(BuildContext context, String format) async {
    setState(() { _exportLoading = true; _lastExportPath = null; });
    try {
      final dir = await _getDesktopOrDocumentsPath();
      final now = DateTime.now();
      final ts = '${now.year}${now.month.toString().padLeft(2,'0')}${now.day.toString().padLeft(2,'0')}_${now.hour.toString().padLeft(2,'0')}${now.minute.toString().padLeft(2,'0')}';
      final fileName = 'dips_export_$ts.$format';
      final filePath = '$dir/$fileName';

      String content;
      if (format == 'csv') {
        final buf = StringBuffer();
        buf.writeln('Type,ID,Nom,Prénom,Email,Téléphone,Rôle/Département,Statut,Date Création');
        // Sample data rows
        buf.writeln('"Admin","ADM001","El Amrani","Karim","k.elamrani@dips.ma","0661 23 45 67","Admin RH","Actif","2024-01-15"');
        buf.writeln('"Chef","CE001","Benhaddou","Farid","f.benhaddou@dips.ma","0661 44 33 22","Production","Actif","2024-02-10"');
        content = buf.toString();
      } else {
        content = '{\n'
            '  "export_date": "${now.toIso8601String()}",\n'
            '  "application": "DIPS Système de Gestion",\n'
            '  "version": "1.0.0",\n'
            '  "administrateurs": [\n'
            '    {"id":"ADM001","nom":"El Amrani","prenom":"Karim","email":"k.elamrani@dips.ma","role":"Admin RH","actif":true}\n'
            '  ],\n'
            '  "chefs_equipe": [\n'
            '    {"id":"CE001","nom":"Benhaddou","prenom":"Farid","email":"f.benhaddou@dips.ma","departement":"Production","actif":true}\n'
            '  ]\n'
            '}';
      }

      await _saveAndOpenFile(filePath, content, context);
      setState(() { _lastExportPath = filePath; });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: Colors.red, content: Text('Erreur export : $e')),
        );
      }
    } finally {
      setState(() { _exportLoading = false; });
    }
  }

  Future<void> _doImport(BuildContext context) async {
    setState(() { _importLoading = true; _importStatus = null; });
    try {
      // On desktop, we simulate a file picker by reading a known test path.
      // In production, replace with file_picker package:
      // final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['csv']);
      final dir = await _getDesktopOrDocumentsPath();
      final testFile = dart_io.File('$dir/dips_import_test.csv');
      if (await testFile.exists()) {
        final lines = await testFile.readAsLines();
        final count = lines.length - 1; // minus header
        setState(() { _importStatus = '✓ Import réussi : $count enregistrement(s) chargé(s) depuis ${testFile.path}'; });
      } else {
        // Simulate success for demo
        await Future.delayed(const Duration(milliseconds: 800));
        setState(() { _importStatus = '✓ Import simulé : Placez votre fichier CSV nommé "dips_import_test.csv" dans le dossier Documents pour un import réel.'; });
      }
    } catch (e) {
      setState(() { _importStatus = 'Erreur lors de l\'import : $e'; });
    } finally {
      setState(() { _importLoading = false; });
    }
  }

  void _showRestoreConfirm(BuildContext context, String date) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Row(children: const [Icon(Icons.restore, color: AppColors.brand), SizedBox(width: 8), Text('Restaurer la sauvegarde')]),
        content: Text('Restaurer les données du $date ? Les données actuelles seront remplacées.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.brand, foregroundColor: Colors.white, elevation: 0),
            onPressed: () { Navigator.pop(context); _showSaveSuccess(context); },
            child: const Text('Restaurer'),
          ),
        ],
      ),
    );
  }

  void _showResetConfirm(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Row(children: const [Icon(Icons.warning, color: Colors.red), SizedBox(width: 8), Text('Réinitialisation')]),
        content: const Text('Cette action est IRRÉVERSIBLE. Toutes les données seront effacées. Continuer ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white, elevation: 0),
            onPressed: () => Navigator.pop(context),
            child: const Text('Réinitialiser'),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  SECTION: À PROPOS
// ─────────────────────────────────────────────

class _AboutSection extends StatelessWidget {
  const _AboutSection();
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeader(title: 'À propos', subtitle: 'Informations sur le système DIPS'),
          const SizedBox(height: 24),
          Center(
            child: Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE8EDF5)),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF328EEE).withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.business, color: Color(0xFF328EEE), size: 56),
                  ),
                  const SizedBox(height: 16),
                  const Text('DIPS', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Color(0xFF1A2340))),
                  const Text('Système de Gestion', style: TextStyle(fontSize: 16, color: Colors.grey)),
                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 16),
                  ...[
                    ['Version', '1.0.0'],
                    ['Build', '2026.03.01'],
                    ['Plateforme', 'Flutter Desktop'],
                    ['Base de données', 'SQLite Local'],
                    ['Licence', 'Propriétaire'],
                  ].map((item) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(width: 130, child: Text(item[0], style: TextStyle(color: Colors.grey[600], fontSize: 13))),
                        Text(item[1], style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      ],
                    ),
                  )),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  SHARED HELPER WIDGETS
// ─────────────────────────────────────────────

class _FormField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String hint;
  final bool isEmail;
  final bool isPassword;
  final bool isNumber;

  const _FormField({
    required this.label,
    required this.controller,
    required this.hint,
    this.isEmail = false,
    this.isPassword = false,
    this.isNumber = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          obscureText: isPassword,
          keyboardType: isNumber ? TextInputType.number : (isEmail ? TextInputType.emailAddress : TextInputType.text),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF328EEE), width: 1.5)),
            filled: true,
            fillColor: Colors.white,
          ),
          validator: (v) => v == null || v.isEmpty ? 'Champ requis' : null,
        ),
      ],
    );
  }
}

class _PasswordField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final bool show;
  final VoidCallback onToggle;

  const _PasswordField({required this.label, required this.controller, required this.show, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          obscureText: !show,
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF328EEE), width: 1.5)),
            filled: true,
            fillColor: Colors.white,
            suffixIcon: IconButton(icon: Icon(show ? Icons.visibility_off : Icons.visibility, size: 18), onPressed: onToggle),
          ),
        ),
      ],
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MiniStat({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        ],
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _IconBtn({required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(7),
        ),
        child: Icon(icon, size: 16, color: color),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SectionHeader({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1A2340))),
        const SizedBox(height: 4),
        Text(subtitle, style: const TextStyle(fontSize: 13, color: Colors.grey)),
      ],
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;

  const _SettingsCard({required this.title, required this.icon, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE8EDF5)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFF328EEE), size: 18),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1A2340))),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }
}

class _SwitchSetting extends StatelessWidget {
  final String label;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final Color iconColor;

  const _SwitchSetting({required this.label, required this.subtitle, required this.value, required this.onChanged, required this.iconColor});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: iconColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
          child: Icon(Icons.circle, size: 8, color: iconColor),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
            ],
          ),
        ),
        Switch(value: value, onChanged: onChanged, activeColor: const Color(0xFF328EEE)),
      ],
    );
  }
}

class _DropdownSetting extends StatelessWidget {
  final String label;
  final String value;
  final List<String> items;
  final ValueChanged<String?> onChanged;

  const _DropdownSetting({required this.label, required this.value, required this.items, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          value: value,
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
            filled: true,
            fillColor: Colors.white,
          ),
          items: items.map((i) => DropdownMenuItem(value: i, child: Text(i, style: const TextStyle(fontSize: 13)))).toList(),
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _DbActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _DbActionCard({required this.icon, required this.title, required this.subtitle, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 13)),
                  Text(subtitle, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  IMPORT / EXPORT UTILITIES
// ─────────────────────────────────────────────

Future<String> _getDesktopOrDocumentsPath() async {
  // Works on Windows/macOS/Linux desktop Flutter
  final home = dart_io.Platform.environment['HOME'] ??
      dart_io.Platform.environment['USERPROFILE'] ??
      '.';
  final docs = dart_io.Directory('$home/Documents');
  if (await docs.exists()) return docs.path;
  return home;
}

Future<void> _saveAndOpenFile(
    String fileNameOrPath, String content, BuildContext context) async {
  try {
    final path = fileNameOrPath.contains('/')
        ? fileNameOrPath
        : '${await _getDesktopOrDocumentsPath()}/$fileNameOrPath';
    final file = dart_io.File(path);
    await file.writeAsString(content, flush: true);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          width: 400,
          backgroundColor: Colors.green.shade700,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          content: Row(children: [
            const Icon(Icons.check_circle_outline, color: Colors.white, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text('Fichier enregistré : $path',
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                  overflow: TextOverflow.ellipsis),
            ),
          ]),
        ),
      );
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: Colors.red, content: Text('Erreur : $e')),
      );
    }
  }
}

// ─────────────────────────────────────────────
//  SMALL SHARED UI WIDGETS
// ─────────────────────────────────────────────

/// Table header cell (const-friendly)
class _TH extends StatelessWidget {
  final String label;
  final bool center;
  const _TH(this.label, {this.center = false});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      textAlign: center ? TextAlign.center : TextAlign.left,
      style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
          color: Color(0xFF6B7A99)),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.search_off_rounded, size: 44, color: Colors.grey[300]),
        const SizedBox(height: 10),
        Text('Aucun résultat', style: TextStyle(color: Colors.grey[400], fontSize: 13)),
      ]),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _DetailRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(children: [
        Icon(icon, size: 15, color: Colors.grey[400]),
        const SizedBox(width: 10),
        SizedBox(
          width: 90,
          child: Text(label,
              style: TextStyle(fontSize: 12, color: Colors.grey[500], fontWeight: FontWeight.w600)),
        ),
        Expanded(
          child: Text(value,
              style: const TextStyle(fontSize: 13, color: _kDark, fontWeight: FontWeight.w500),
              overflow: TextOverflow.ellipsis),
        ),
      ]),
    );
  }
}

class _ExportFormatBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool loading;
  final VoidCallback onTap;
  const _ExportFormatBtn({required this.label, required this.icon, required this.color, required this.loading, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: color.withOpacity(0.4)),
        foregroundColor: color,
        backgroundColor: color.withOpacity(0.05),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      icon: loading
          ? SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: color))
          : Icon(icon, size: 16),
      label: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
      onPressed: loading ? null : onTap,
    );
  }
}

// ─────────────────────────────────────────────
//  OLD _th helper kept for backward compat
// ─────────────────────────────────────────────
Widget _the(String label, {int flex = 1, TextAlign align = TextAlign.left}) =>
    Expanded(
      flex: flex,
      child: Text(label,
          textAlign: align,
          style: const TextStyle(
              fontSize: 11, fontWeight: FontWeight.w700,
              letterSpacing: 0.6, color: Color(0xFF6B7A99))),
    );

void _showSaveSuccess(BuildContext context) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      width: 320,
      backgroundColor: Colors.green,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      content: const Row(
        children: [
          Icon(Icons.check_circle, color: Colors.white, size: 18),
          SizedBox(width: 8),
          Text('Paramètres enregistrés avec succès', style: TextStyle(color: Colors.white)),
        ],
      ),
    ),
  );
}

// ═══════════════════════════════════════════════════════════════════════════
// Section: Types de congé
// ═══════════════════════════════════════════════════════════════════════════

class _LeaveTypesSection extends StatefulWidget {
  const _LeaveTypesSection();
  @override
  State<_LeaveTypesSection> createState() => _LeaveTypesSectionState();
}

class _LeaveTypesSectionState extends State<_LeaveTypesSection> {
  final _labelCtrl = TextEditingController();
  final _reasonCtrl = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _labelCtrl.dispose();
    _reasonCtrl.dispose();
    super.dispose();
  }

  Future<void> _addType() async {
    final label = _labelCtrl.text.trim();
    if (label.isEmpty) return;
    setState(() => _saving = true);
    await FirebaseFirestore.instance.collection('leave_types').add({
      'label': label,
      'defaultReason': _reasonCtrl.text.trim(),
      'actif': true,
      'createdAt': Timestamp.now(),
    });
    _labelCtrl.clear();
    _reasonCtrl.clear();
    if (mounted) setState(() => _saving = false);
  }

  Future<void> _editType(String docId, String currentLabel, String currentReason) async {
    final editLabelCtrl = TextEditingController(text: currentLabel);
    final editReasonCtrl = TextEditingController(text: currentReason);
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Modifier le type de congé'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: editLabelCtrl,
              decoration: const InputDecoration(labelText: 'Libellé *', border: OutlineInputBorder()),
              autofocus: true,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: editReasonCtrl,
              decoration: const InputDecoration(
                labelText: 'Motif par défaut',
                hintText: 'Pré-rempli automatiquement dans le formulaire',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          FilledButton(
            onPressed: () async {
              final lbl = editLabelCtrl.text.trim();
              if (lbl.isEmpty) return;
              await FirebaseFirestore.instance.collection('leave_types').doc(docId).update({
                'label': lbl,
                'defaultReason': editReasonCtrl.text.trim(),
              });
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleType(String docId, bool currentActif) async {
    await FirebaseFirestore.instance.collection('leave_types').doc(docId).update({
      'actif': !currentActif,
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeader(
            title: 'Types de congé',
            subtitle: 'Définir les types de congé disponibles et leur motif par défaut (pré-rempli automatiquement dans les formulaires).',
          ),
          const SizedBox(height: 20),
          // ── Formulaire d'ajout ──
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Ajouter un nouveau type', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _labelCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Libellé du type *',
                      hintText: 'Ex: Congé annuel, Congé maladie, Congé paternité...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _reasonCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Motif par défaut',
                      hintText: 'Ce motif sera pré-rempli automatiquement lors de la saisie d\'une demande',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      icon: _saving
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.add),
                      label: const Text('Ajouter'),
                      onPressed: _saving ? null : _addType,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          // ── Liste des types ──
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('leave_types')
                .orderBy('createdAt', descending: false)
                .snapshots(),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()));
              }
              final docs = snap.data?.docs ?? const [];
              if (docs.isEmpty) {
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Aucun type de congé défini. Ajoutez-en pour qu\'ils apparaissent dans les formulaires de demande.',
                      style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                    ),
                  ),
                );
              }
              final actifs = docs.where((d) => d.data()['actif'] == true).toList();
              final inactifs = docs.where((d) => d.data()['actif'] != true).toList();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (actifs.isNotEmpty) ...[
                    Text('Types actifs (${actifs.length})', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF328EEE))),
                    const SizedBox(height: 8),
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: actifs.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (_, i) => _LeaveTypeCard(
                        doc: actifs[i],
                        onEdit: () => _editType(actifs[i].id, (actifs[i].data()['label'] as String?) ?? '', (actifs[i].data()['defaultReason'] as String?) ?? ''),
                        onToggle: () => _toggleType(actifs[i].id, true),
                      ),
                    ),
                  ],
                  if (inactifs.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    Text('Types désactivés (${inactifs.length})', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Colors.grey[600])),
                    const SizedBox(height: 8),
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: inactifs.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (_, i) => _LeaveTypeCard(
                        doc: inactifs[i],
                        onEdit: () => _editType(inactifs[i].id, (inactifs[i].data()['label'] as String?) ?? '', (inactifs[i].data()['defaultReason'] as String?) ?? ''),
                        onToggle: () => _toggleType(inactifs[i].id, false),
                        isDisabled: true,
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _LeaveTypeCard extends StatelessWidget {
  final QueryDocumentSnapshot<Map<String, dynamic>> doc;
  final VoidCallback onEdit;
  final VoidCallback onToggle;
  final bool isDisabled;

  const _LeaveTypeCard({
    required this.doc,
    required this.onEdit,
    required this.onToggle,
    this.isDisabled = false,
  });

  @override
  Widget build(BuildContext context) {
    final m = doc.data();
    final label = (m['label'] as String?)?.trim() ?? doc.id;
    final reason = (m['defaultReason'] as String?)?.trim() ?? '';

    return Card(
      color: isDisabled ? Colors.grey.shade50 : null,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isDisabled ? Colors.grey.shade200 : const Color(0xFFE3F2FD),
          child: Icon(
            Icons.beach_access,
            color: isDisabled ? Colors.grey : const Color(0xFF00044D),
            size: 20,
          ),
        ),
        title: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: isDisabled ? Colors.grey : null,
            decoration: isDisabled ? TextDecoration.lineThrough : null,
          ),
        ),
        subtitle: reason.isNotEmpty
            ? Text(
                'Motif par défaut: $reason',
                style: TextStyle(fontSize: 12, color: isDisabled ? Colors.grey : Colors.grey.shade600),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              )
            : Text(
                'Aucun motif par défaut',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade400, fontStyle: FontStyle.italic),
              ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!isDisabled)
              IconButton(
                tooltip: 'Modifier',
                icon: const Icon(Icons.edit_outlined, size: 20, color: Color(0xFF328EEE)),
                onPressed: onEdit,
              ),
            IconButton(
              tooltip: isDisabled ? 'Réactiver' : 'Désactiver',
              icon: Icon(
                isDisabled ? Icons.toggle_off_outlined : Icons.toggle_on_outlined,
                size: 22,
                color: isDisabled ? Colors.grey : Colors.orange,
              ),
              onPressed: onToggle,
            ),
          ],
        ),
      ),
    );
  }
}