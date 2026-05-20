import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import 'package:provider/provider.dart';
import '../../core/auth/app_permissions.dart';
import '../../core/auth/auth_provider.dart';
import '../../core/site/site_model.dart';
import '../../core/site/site_provider.dart';
import '../../core/utils/responsive.dart';
import '../../shared/widgets/smart_avatar.dart';
import 'models/employe_model.dart';
import 'models/equipe_model.dart';
import 'employees_provider.dart';
import 'widgets/employee_detail_dialog.dart';
import 'widgets/employee_form_dialog.dart';
import 'widgets/employee_edit_dialog.dart';
import 'widgets/equipes_tab.dart';

class EmployeesPage extends StatefulWidget {
  const EmployeesPage({super.key});

  @override
  State<EmployeesPage> createState() => _EmployeesPageState();
}

class _EmployeesPageState extends State<EmployeesPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _search = '';
  String? _filterCategorie;
  String? _filterEquipeId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!mounted) return;
      if (_tabController.indexIsChanging) return;
      setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<Employe> _employes(EmployeesProvider prov, AuthProvider auth, SiteProvider? site) {
    List<Employe> base;
    if (auth.isDirecteur) {
      base = SiteId.filterBySite(
        prov.employes,
        auth.currentUser?.allowedSiteIds,
        auth.currentUser?.isSuperAdmin == true ? site?.selectedSiteId : null,
        (e) => e.siteId,
      );
    } else {
      final eqId = auth.equipeId;
      if (eqId == null || eqId.isEmpty) return [];
      final eq = prov.equipes.where((e) => e.id == eqId).toList();
      if (eq.isEmpty) return [];
      final ids = [...eq.first.membreIds, eq.first.chefId];
      base = prov.employes.where((e) => ids.contains(e.id)).toList();
    }
    return base;
  }

  List<Equipe> _equipes(EmployeesProvider prov, AuthProvider auth, SiteProvider? site) {
    if (auth.isDirecteur) {
      return SiteId.filterBySite(
        prov.equipes,
        auth.currentUser?.allowedSiteIds,
        auth.currentUser?.isSuperAdmin == true ? site?.selectedSiteId : null,
        (e) => e.siteId,
      );
    }
    final eqId = auth.equipeId;
    if (eqId == null || eqId.isEmpty) return [];
    return prov.equipes.where((e) => e.id == eqId).toList();
  }

  List<Employe> _filtered(List<Employe> employes, List<Equipe> equipes) => employes.where((e) {
    final q = _search.toLowerCase();
    final matchSearch = q.isEmpty ||
        e.nom.toLowerCase().contains(q) ||
        e.cin.toLowerCase().contains(q) ||
        e.telephone.contains(q) ||
        e.poste.toLowerCase().contains(q) ||
        e.magasin.toLowerCase().contains(q);
    bool matchCategorie = true;
    if (_filterCategorie != null) {
      if (_filterEquipeId != null) {
        // Équipe sélectionnée : filtrer par appartenance (membres + chef), indépendamment du département
        final eq = equipes.where((eq) => eq.id == _filterEquipeId).toList();
        matchCategorie = eq.isNotEmpty &&
            (eq.first.membreIds.contains(e.id) || eq.first.chefId == e.id);
      } else {
        // Pas d'équipe sélectionnée : filtrer par département
        matchCategorie = e.departement.toLowerCase().contains(_filterCategorie!);
      }
    }
    return matchSearch && matchCategorie;
  }).toList();

  String _getChefNom(String chefId, List<Employe> employes) {
    if (chefId.isEmpty) return '—';
    final chef = employes.where((e) => e.id == chefId).toList();
    return chef.isNotEmpty ? chef.first.nom : '—';
  }

  Widget _filterCatChip(String label, String key, {bool small = false}) {
    final isSelected = _filterCategorie == key;
    return FilterChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: small ? 11 : 12,
          color: isSelected ? Colors.white : Colors.grey[700],
        ),
      ),
      selected: isSelected,
      onSelected: (_) => setState(() {
        _filterCategorie = isSelected ? null : key;
        _filterEquipeId = null;
      }),
      backgroundColor: Colors.white,
      selectedColor: AppColors.brand,
      side: BorderSide(color: isSelected ? AppColors.brand : Colors.grey.shade400),
      padding: EdgeInsets.symmetric(horizontal: small ? 4 : 6, vertical: 0),
    );
  }

  Widget _filterCatDropdown(String label, String key, List<Equipe> equipes, {bool small = false}) {
    final isSelected = _filterCategorie == key;
    final matches = _filterEquipeId != null
        ? equipes.where((e) => e.id == _filterEquipeId).toList()
        : <Equipe>[];
    final selEq = matches.isNotEmpty ? matches.first : null;
    final chipLabel = isSelected && selEq != null ? selEq.nom : label;

    return PopupMenuButton<String>(
      tooltip: '',
      offset: const Offset(0, 36),
      onSelected: (v) {
        setState(() {
          if (v == '__clear__') {
            _filterCategorie = null;
            _filterEquipeId = null;
          } else if (v == '__all__') {
            _filterCategorie = key;
            _filterEquipeId = null;
          } else {
            _filterCategorie = key;
            _filterEquipeId = v;
          }
        });
      },
      itemBuilder: (ctx) => [
        if (isSelected)
          PopupMenuItem<String>(
            value: '__clear__',
            child: Row(children: [
              Icon(Icons.clear, size: 14, color: Colors.grey[600]),
              const SizedBox(width: 8),
              Text('Effacer', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
            ]),
          ),
        const PopupMenuItem<String>(
          value: '__all__',
          child: Text('Toutes les équipes'),
        ),
        ...equipes.map((eq) => PopupMenuItem<String>(
          value: eq.id,
          child: Text(eq.nom),
        )),
      ],
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: small ? 8 : 10, vertical: small ? 5 : 7),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.brand : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.brand : Colors.grey.shade400,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              chipLabel,
              style: TextStyle(
                fontSize: small ? 11 : 12,
                color: isSelected ? Colors.white : Colors.grey[700],
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
            Icon(
              Icons.arrow_drop_down,
              size: 16,
              color: isSelected ? Colors.white : Colors.grey[600],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOfflineBanner() {
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

  Widget _buildErrorBanner(String error) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        border: Border(bottom: BorderSide(color: Colors.red.shade200)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, size: 22, color: Colors.red.shade800),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Erreur Firebase: $error',
              style: TextStyle(fontSize: 13, color: Colors.red.shade900),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final site = context.watch<SiteProvider>();
    final prov = context.watch<EmployeesProvider>();
    final employes = _employes(prov, auth, site);
    final equipes = _equipes(prov, auth, site);
    final filtered = _filtered(employes, equipes);

    final padding = pagePadding(context);
    final mobile = isMobile(context);
    final canManageEmployees = auth.hasPermission(AppPermissions.employeesManage);
    final canDeleteEmployees = auth.hasPermission(AppPermissions.employeesDelete);
    final canManageTeams = auth.hasPermission(AppPermissions.teamsManage);
    final canManageMembers = auth.hasAnyPermission([
      AppPermissions.teamsManage,
      AppPermissions.employeesManage,
    ]);

    // Show loading indicator
    if (prov.loading) {
      return const Center(child: CircularProgressIndicator());
    }

    // Équipes filtrées par département pour les dropdowns
    final distributionEquipes = equipes.where((eq) =>
      employes.any((e) =>
        (eq.membreIds.contains(e.id) || eq.chefId == e.id) &&
        e.departement.toLowerCase().contains('distribution')
      )
    ).toList();

    final pageBody = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
          if (!prov.firebaseAvailable) _buildOfflineBanner(),
          if (!prov.firebaseAvailable) const SizedBox(height: 12),
          if (prov.error != null && prov.firebaseAvailable) _buildErrorBanner(prov.error!),
          if (prov.error != null && prov.firebaseAvailable) const SizedBox(height: 12),
          // ===== HEADER =====
          if (mobile)
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Gestion des Collaborateurs', style: TextStyle(fontSize: titleFontSize(context), fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(auth.isDirecteur ? 'Vue complète - ${employes.length} collaborateurs' : 'Mon équipe - ${employes.length} membre(s)', style: TextStyle(color: Colors.grey[600], fontSize: subtitleFontSize(context))),
                if (canManageEmployees) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => showDialog(context: context, builder: (_) => EmployeeFormDialog(employes: employes, onSave: (e) async { await prov.addEmploye(e); })),
                      icon: const Icon(Icons.person_add, size: 20),
                      label: const Text('Nouveau Collaborateur'),
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF000966), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14)),
                    ),
                  ),
                ],
              ],
            )
          else
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Gestion des Collaborateurs', style: TextStyle(fontSize: titleFontSize(context), fontWeight: FontWeight.bold)),
                    Text(auth.isDirecteur ? 'Vue complète - ${employes.length} collaborateurs' : 'Mon équipe - ${employes.length} membre(s)', style: TextStyle(color: Colors.grey[600], fontSize: subtitleFontSize(context))),
                  ],
                ),
                if (canManageEmployees)
                  ElevatedButton.icon(
                    onPressed: () => showDialog(context: context, builder: (_) => EmployeeFormDialog(employes: employes, onSave: (e) async { await prov.addEmploye(e); })),
                    icon: const Icon(Icons.person_add),
                    label: const Text('Nouveau Collaborateur'),
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF000966), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14)),
                  ),
              ],
            ),
          SizedBox(height: mobile ? 16 : 20),

          // ===== SEARCH + FILTER =====
          if (mobile)
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Rechercher...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    isDense: true,
                  ),
                  onChanged: (v) => setState(() => _search = v),
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _filterCatChip('Management', 'management', small: true),
                      const SizedBox(width: 6),
                      _filterCatDropdown('Dessalement', 'dessalement', equipes, small: true),
                      const SizedBox(width: 6),
                      _filterCatDropdown('Distribution', 'distribution', distributionEquipes, small: true),
                      const SizedBox(width: 6),
                      _filterCatChip('Nettoyage', 'nettoyage', small: true),
                    ],
                  ),
                ),
              ],
            )
          else
            Row(
              children: [
                SizedBox(
                  width: 210,
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Rechercher...',
                      prefixIcon: const Icon(Icons.search, size: 18),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                      isDense: true,
                    ),
                    onChanged: (v) => setState(() => _search = v),
                  ),
                ),
                const SizedBox(width: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _filterCatChip('Management', 'management'),
                    _filterCatDropdown('Dessalement', 'dessalement', equipes),
                    _filterCatDropdown('Distribution', 'distribution', distributionEquipes),
                    _filterCatChip('Nettoyage', 'nettoyage'),
                  ],
                ),
              ],
            ),
          SizedBox(height: mobile ? 12 : 16),

          // ===== TABS =====
          TabBar(
            controller: _tabController,
            labelColor: const Color(0xFF000966),
            unselectedLabelColor: Colors.grey,
            indicatorColor: const Color(0xFF000966),
            tabs: [
              Tab(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.people, size: 18),
                    const SizedBox(width: 8),
                    Text('Collaborateurs (${employes.length})'),
                  ]),
                ),
              ),
              Tab(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.groups, size: 18),
                    const SizedBox(width: 8),
                    Text('Équipes (${equipes.length})'),
                  ]),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (mobile)
            (_tabController.index == 0
                ? _buildEmployesTab(
                    context,
                    employes,
                    equipes,
                    filtered,
                    auth.isDirecteur,
                    canManageEmployees,
                    canDeleteEmployees,
                    prov,
                    internalScroll: false,
                    filterCategorie: _filterCategorie,
                    filterEquipeId: _filterEquipeId,
                  )
                : EquipesTab(
                    equipes: equipes,
                    employes: employes,
                    isDirecteur: auth.isDirecteur,
                    canManageTeams: canManageTeams,
                    canManageMembers: canManageMembers,
                    internalScroll: false,
                    onAddEquipe: (eq) async {
                      await prov.addEquipe(eq);
                    },
                    onDeleteEquipe: (eq) async {
                      await prov.deleteEquipe(eq.id);
                    },
                  ))
          else
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildEmployesTab(
                    context,
                    employes,
                    equipes,
                    filtered,
                    auth.isDirecteur,
                    canManageEmployees,
                    canDeleteEmployees,
                    prov,
                    filterCategorie: _filterCategorie,
                    filterEquipeId: _filterEquipeId,
                  ),
                  EquipesTab(
                    equipes: equipes,
                    employes: employes,
                    isDirecteur: auth.isDirecteur,
                    canManageTeams: canManageTeams,
                    canManageMembers: canManageMembers,
                    onAddEquipe: (eq) async {
                      await prov.addEquipe(eq);
                    },
                    onDeleteEquipe: (eq) async {
                      await prov.deleteEquipe(eq.id);
                    },
                  ),
                ],
              ),
            ),
        ],
    );

    if (mobile) {
      return SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: padding, vertical: 12),
        child: pageBody,
      );
    }

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: padding, vertical: 16),
      child: pageBody,
    );
  }

  Widget _buildEmployesTab(
    BuildContext context,
    List<Employe> employes,
    List<Equipe> equipes,
    List<Employe> filtered,
    bool isDirecteur,
    bool canManageEmployees,
    bool canDeleteEmployees,
    EmployeesProvider prov,
    {bool internalScroll = true,
     String? filterCategorie,
     String? filterEquipeId}
  ) {
    final mobile = isMobile(context);

    final tableSection = internalScroll
        ? Expanded(
            child: mobile
                ? LayoutBuilder(
                    builder: (context, constraints) {
                      return SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: SizedBox(
                          width: 700,
                          height: constraints.maxHeight,
                          child: _employesTable(
                            context,
                            employes,
                            equipes,
                            filtered,
                            isDirecteur,
                            canManageEmployees,
                            canDeleteEmployees,
                            prov,
                            filterCategorie: filterCategorie,
                            filterEquipeId: filterEquipeId,
                          ),
                        ),
                      );
                    },
                  )
                : _employesTable(
                    context,
                    employes,
                    equipes,
                    filtered,
                    isDirecteur,
                    canManageEmployees,
                    canDeleteEmployees,
                    prov,
                    filterCategorie: filterCategorie,
                    filterEquipeId: filterEquipeId,
                  ),
          )
        : (mobile
            ? SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: 700,
                  child: _employesTable(
                    context,
                    employes,
                    equipes,
                    filtered,
                    isDirecteur,
                    canManageEmployees,
                    canDeleteEmployees,
                    prov,
                    internalScroll: false,
                    filterCategorie: filterCategorie,
                    filterEquipeId: filterEquipeId,
                  ),
                ),
              )
            : _employesTable(
                context,
                employes,
                equipes,
                filtered,
                isDirecteur,
                canManageEmployees,
                canDeleteEmployees,
                prov,
                internalScroll: false,
                filterCategorie: filterCategorie,
                filterEquipeId: filterEquipeId,
              ));

    return Column(
      children: [
        tableSection,
      ],
    );
  }

  // ── helper: build a single employee row ──────────────────────────────────
  Widget _buildEmployeeRowWidget(
    BuildContext context,
    Employe e,
    String? chefEquipeNom,
    List<Employe> employes,
    bool isDirecteur,
    bool canManageEmployees,
    bool canDeleteEmployees,
    EmployeesProvider prov,
    bool mobile,
    bool isChefOnly,
    double actionsColumnWidth,
  ) {
    return InkWell(
      onTap: () => showDialog(
        context: context,
        builder: (_) => EmployeeDetailDialog(employe: e, allEmployes: employes, isDirecteur: isDirecteur),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: mobile ? 12 : 16, vertical: mobile ? 10 : 12),
        child: Row(children: [
          Expanded(flex: 3, child: Row(children: [
            SmartAvatar(imageUrl: e.photoUrl, fallbackText: e.nom, radius: mobile ? 14 : 18),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(e.nom, style: TextStyle(fontWeight: FontWeight.w600, fontSize: mobile ? 12 : 13)),
                Text('CIN: ${e.cin}', style: TextStyle(color: Colors.grey[500], fontSize: mobile ? 10 : 11)),
                if (chefEquipeNom != null) ...[
                  const SizedBox(height: 3),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.brand.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text('Chef d\'équipe • $chefEquipeNom',
                      style: TextStyle(fontSize: mobile ? 9 : 10, color: AppColors.brand, fontWeight: FontWeight.w700),
                      overflow: TextOverflow.ellipsis),
                  ),
                ],
              ]),
            ),
          ])),
          if (!isChefOnly) ...[
            Expanded(flex: 2, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(e.poste, style: TextStyle(fontSize: mobile ? 12 : 13)),
              Text(e.magasin, style: TextStyle(color: Colors.grey[500], fontSize: mobile ? 10 : 11)),
            ])),
            Expanded(flex: 2, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: e.typeContrat == 'CDI' ? AppColors.brandLight : Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(e.typeContrat,
                  style: TextStyle(fontSize: mobile ? 10 : 11, color: e.typeContrat == 'CDI' ? AppColors.brand : Colors.orange, fontWeight: FontWeight.bold)),
              ),
              Text('Depuis ${e.dateDebut}', style: TextStyle(color: Colors.grey[500], fontSize: mobile ? 10 : 11)),
            ])),
            Expanded(flex: 2, child: Text(_getChefNom(e.chefDirectId, employes), style: TextStyle(fontSize: mobile ? 12 : 13))),
            if (isDirecteur) Expanded(flex: 1, child: Text('${e.salaireBase.toInt()} DH', style: TextStyle(fontSize: mobile ? 12 : 13, fontWeight: FontWeight.w600))),
          ],
          Expanded(flex: 2, child: Container(
            padding: EdgeInsets.symmetric(horizontal: mobile ? 6 : 10, vertical: 4),
            decoration: BoxDecoration(color: e.statut.color.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(e.statut.icon, size: mobile ? 12 : 14, color: e.statut.color),
              SizedBox(width: mobile ? 4 : 6),
              Flexible(child: Text(e.statut.label,
                style: TextStyle(fontSize: mobile ? 10 : 12, color: e.statut.color, fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis)),
            ]),
          )),
          if (isChefOnly) const SizedBox(width: 60),
          if (!isChefOnly)
            SizedBox(
              width: actionsColumnWidth,
              child: canManageEmployees
                ? ClipRect(child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    reverse: true,
                    child: Row(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.end, children: [
                      IconButton(icon: const Icon(Icons.visibility, size: 18), tooltip: 'Voir détails',
                        onPressed: () => showDialog(context: context, builder: (_) => EmployeeDetailDialog(employe: e, allEmployes: employes, isDirecteur: isDirecteur)),
                        padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                        style: IconButton.styleFrom(tapTargetSize: MaterialTapTargetSize.shrinkWrap)),
                      IconButton(icon: Icon(Icons.edit, size: 18, color: Colors.green[700]), tooltip: 'Modifier',
                        onPressed: () => showDialog(context: context, builder: (_) => EmployeeEditDialog(
                          employe: e, allEmployes: employes,
                          onSave: (updated) async { await prov.updateEmploye(updated); })),
                        padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                        style: IconButton.styleFrom(tapTargetSize: MaterialTapTargetSize.shrinkWrap)),
                      IconButton(icon: Icon(Icons.swap_horiz, size: 18, color: AppColors.brand), tooltip: 'Changer statut',
                        onPressed: () => _showChangeStatutDialog(context, e, prov),
                        padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                        style: IconButton.styleFrom(tapTargetSize: MaterialTapTargetSize.shrinkWrap)),
                      if (canDeleteEmployees)
                        IconButton(icon: Icon(Icons.delete_outline, size: 18, color: Colors.red[700]), tooltip: 'Supprimer le collaborateur',
                          onPressed: () => _showDeleteEmployeConfirm(context, e, prov),
                          padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                          style: IconButton.styleFrom(tapTargetSize: MaterialTapTargetSize.shrinkWrap)),
                    ]),
                  ))
                : (isDirecteur
                    ? const SizedBox.shrink()
                    : IconButton(icon: Icon(Icons.swap_horiz, size: 18, color: AppColors.brand),
                        onPressed: () => _showChangeStatutDialog(context, e, prov),
                        padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                        style: IconButton.styleFrom(tapTargetSize: MaterialTapTargetSize.shrinkWrap))),
            ),
        ]),
      ),
    );
  }

  // ── helper: build distribution grouped items ─────────────────────────────
  List<Object> _buildDistributionGroups(List<Employe> emps, List<Equipe> eqs) {
    final items = <Object>[];
    final assigned = <String>{};
    for (final eq in eqs) {
      final chef = emps.where((e) => e.id == eq.chefId).toList();
      final members = emps.where((e) => eq.membreIds.contains(e.id)).toList();
      if (chef.isEmpty && members.isEmpty) continue;
      items.add(eq);
      if (chef.isNotEmpty) { items.add(chef.first); assigned.add(chef.first.id); }
      for (final m in members) { items.add(m); assigned.add(m.id); }
    }
    for (final e in emps) { if (!assigned.contains(e.id)) items.add(e); }
    return items;
  }

  Widget _buildGroupHeader(Equipe eq, bool mobile) => Container(
    color: AppColors.brand.withValues(alpha: 0.06),
    padding: EdgeInsets.symmetric(horizontal: mobile ? 12 : 16, vertical: 8),
    child: Row(children: [
      Icon(Icons.groups_outlined, size: 15, color: AppColors.brand),
      const SizedBox(width: 8),
      Text(eq.nom, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.brand)),
    ]),
  );

  Widget _employesTable(
    BuildContext context,
    List<Employe> employes,
    List<Equipe> equipes,
    List<Employe> filtered,
    bool isDirecteur,
    bool canManageEmployees,
    bool canDeleteEmployees,
    EmployeesProvider prov,
    {bool internalScroll = true,
     String? filterCategorie,
     String? filterEquipeId}
  ) {
    final mobile = isMobile(context);
    final isChefOnly = !isDirecteur;
    final actionsColumnWidth = mobile ? 140.0 : 160.0;
    final Map<String, String> chefEquipeMap = {
      for (final eq in equipes) if (eq.chefId.isNotEmpty) eq.chefId: eq.nom,
    };
    final sortedFiltered = [
      ...filtered.where((e) => chefEquipeMap.containsKey(e.id)),
      ...filtered.where((e) => !chefEquipeMap.containsKey(e.id)),
    ];
    // Vue groupée pour Distribution sans équipe spécifique
    final useGrouped = filterCategorie == 'distribution' && filterEquipeId == null;
    final groupedItems = useGrouped ? _buildDistributionGroups(sortedFiltered, equipes) : <Object>[];
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.max,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: mobile ? 12 : 16, vertical: mobile ? 10 : 12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(12), topRight: Radius.circular(12)),
            ),
            child: Row(children: [
              const Expanded(flex: 3, child: Text('Collaborateur', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13), overflow: TextOverflow.ellipsis)),
              if (!isChefOnly) ...[
                const Expanded(flex: 2, child: Text('Poste / Magasin', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13), overflow: TextOverflow.ellipsis)),
                const Expanded(flex: 2, child: Text('Contrat', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13), overflow: TextOverflow.ellipsis)),
                const Expanded(flex: 2, child: Text('Chef direct', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13), overflow: TextOverflow.ellipsis)),
                if (isDirecteur) const Expanded(flex: 1, child: Text('Salaire', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13), overflow: TextOverflow.ellipsis)),
              ],
              const Expanded(flex: 2, child: Text('Statut', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13), overflow: TextOverflow.ellipsis)),
              if (isChefOnly)
                const SizedBox(width: 60, child: Text('', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
              if (!isChefOnly)
                SizedBox(width: actionsColumnWidth, child: const Text('Actions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13), overflow: TextOverflow.ellipsis)),
            ]),
          ),
          const Divider(height: 1),
          if (filtered.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Center(child: Text('Aucun collaborateur trouvé', style: TextStyle(color: Colors.grey[600], fontSize: mobile ? 12 : 14))),
            )
          else if (internalScroll)
            Expanded(
              child: useGrouped
                ? ListView.builder(
                    itemCount: groupedItems.length,
                    itemBuilder: (context, i) {
                      final item = groupedItems[i];
                      if (item is Equipe) {
                        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                          if (i > 0) const SizedBox(height: 6),
                          _buildGroupHeader(item, mobile),
                        ]);
                      }
                      final e = item as Employe;
                      final chefEquipeNom = chefEquipeMap[e.id];
                      final nextIsGroup = i + 1 < groupedItems.length && groupedItems[i + 1] is Equipe;
                      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        _buildEmployeeRowWidget(context, e, chefEquipeNom, employes, isDirecteur, canManageEmployees, canDeleteEmployees, prov, mobile, isChefOnly, actionsColumnWidth),
                        if (!nextIsGroup) const Divider(height: 1),
                      ]);
                    },
                  )
                : ListView.separated(
                itemCount: sortedFiltered.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final e = sortedFiltered[i];
                  final chefEquipeNom = chefEquipeMap[e.id];
                  return InkWell(
                    onTap: () => showDialog(
                      context: context,
                      builder: (_) => EmployeeDetailDialog(employe: e, allEmployes: employes, isDirecteur: isDirecteur),
                    ),
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: mobile ? 12 : 16, vertical: mobile ? 10 : 12),
                      child: Row(children: [
                        Expanded(flex: 3, child: Row(children: [
                          SmartAvatar(
                            imageUrl: e.photoUrl,
                            fallbackText: e.nom,
                            radius: mobile ? 14 : 18,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(e.nom, style: TextStyle(fontWeight: FontWeight.w600, fontSize: mobile ? 12 : 13)),
                                  Text('CIN: ${e.cin}', style: TextStyle(color: Colors.grey[500], fontSize: mobile ? 10 : 11)),
                                  if (chefEquipeNom != null) ...[
                                    const SizedBox(height: 3),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppColors.brand.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        'Chef d\'équipe • $chefEquipeNom',
                                        style: TextStyle(fontSize: mobile ? 9 : 10, color: AppColors.brand, fontWeight: FontWeight.w700),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ]),
                          ),
                        ])),
                        if (!isChefOnly) ...[
                          Expanded(flex: 2, child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(e.poste, style: TextStyle(fontSize: mobile ? 12 : 13)),
                                Text(e.magasin, style: TextStyle(color: Colors.grey[500], fontSize: mobile ? 10 : 11)),
                              ])),
                          Expanded(flex: 2, child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: e.typeContrat == 'CDI' ? AppColors.brandLight : Colors.orange.shade50,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(e.typeContrat, style: TextStyle(fontSize: mobile ? 10 : 11, color: e.typeContrat == 'CDI' ? AppColors.brand : Colors.orange, fontWeight: FontWeight.bold)),
                                ),
                                Text('Depuis ${e.dateDebut}', style: TextStyle(color: Colors.grey[500], fontSize: mobile ? 10 : 11)),
                              ])),
                          Expanded(flex: 2, child: Text(_getChefNom(e.chefDirectId, employes), style: TextStyle(fontSize: mobile ? 12 : 13))),
                          if (isDirecteur) Expanded(flex: 1, child: Text('${e.salaireBase.toInt()} DH', style: TextStyle(fontSize: mobile ? 12 : 13, fontWeight: FontWeight.w600))),
                        ],
                        Expanded(flex: 2, child: Container(
                          padding: EdgeInsets.symmetric(horizontal: mobile ? 6 : 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: e.statut.color.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(e.statut.icon, size: mobile ? 12 : 14, color: e.statut.color),
                              SizedBox(width: mobile ? 4 : 6),
                              Flexible(child: Text(e.statut.label, style: TextStyle(fontSize: mobile ? 10 : 12, color: e.statut.color, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
                            ],
                          ),
                        )),
                        if (isChefOnly)
                          const SizedBox(width: 60),
                        if (!isChefOnly)
                        SizedBox(
                          width: actionsColumnWidth,
                          child: canManageEmployees
                              ? ClipRect(
                                  child: SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    reverse: true,
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.visibility, size: 18),
                                          tooltip: 'Voir détails',
                                          onPressed: () => showDialog(context: context, builder: (_) => EmployeeDetailDialog(employe: e, allEmployes: employes, isDirecteur: isDirecteur)),
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                          style: IconButton.styleFrom(
                                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                          ),
                                        ),
                                        IconButton(
                                          icon: Icon(Icons.edit, size: 18, color: Colors.green[700]),
                                          tooltip: 'Modifier',
                                          onPressed: () => showDialog(
                                            context: context,
                                            builder: (_) => EmployeeEditDialog(
                                              employe: e,
                                              allEmployes: employes,
                                              onSave: (updated) async {
                                                await prov.updateEmploye(updated);
                                              },
                                            ),
                                          ),
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                          style: IconButton.styleFrom(
                                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                          ),
                                        ),
                                        IconButton(
                                          icon: Icon(Icons.swap_horiz, size: 18, color: AppColors.brand),
                                          tooltip: 'Changer statut',
                                          onPressed: () => _showChangeStatutDialog(context, e, prov),
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                          style: IconButton.styleFrom(
                                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                          ),
                                        ),
                                        if (canDeleteEmployees)
                                          IconButton(
                                            icon: Icon(Icons.delete_outline, size: 18, color: Colors.red[700]),
                                            tooltip: 'Supprimer le collaborateur',
                                            onPressed: () => _showDeleteEmployeConfirm(context, e, prov),
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                            style: IconButton.styleFrom(
                                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                )
                              : (isDirecteur
                                  ? const SizedBox.shrink()
                                  : IconButton(
                                      icon: Icon(Icons.swap_horiz, size: 18, color: AppColors.brand),
                                      onPressed: () => _showChangeStatutDialog(context, e, prov),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                      style: IconButton.styleFrom(
                                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      ),
                                    )),
                        ),
                      ]),
                    ),
                  );
                },
              ),
            )
          else
            useGrouped
              ? ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: groupedItems.length,
                  itemBuilder: (context, i) {
                    final item = groupedItems[i];
                    if (item is Equipe) {
                      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        if (i > 0) const SizedBox(height: 6),
                        _buildGroupHeader(item, mobile),
                      ]);
                    }
                    final e = item as Employe;
                    final chefEquipeNom = chefEquipeMap[e.id];
                    final nextIsGroup = i + 1 < groupedItems.length && groupedItems[i + 1] is Equipe;
                    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      _buildEmployeeRowWidget(context, e, chefEquipeNom, employes, isDirecteur, canManageEmployees, canDeleteEmployees, prov, mobile, isChefOnly, actionsColumnWidth),
                      if (!nextIsGroup) const Divider(height: 1),
                    ]);
                  },
                )
              : ListView.separated(
              itemCount: sortedFiltered.length,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final e = sortedFiltered[i];
                final chefEquipeNom = chefEquipeMap[e.id];
                return InkWell(
                  onTap: () => showDialog(
                    context: context,
                    builder: (_) => EmployeeDetailDialog(employe: e, allEmployes: employes, isDirecteur: isDirecteur),
                  ),
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: mobile ? 12 : 16, vertical: mobile ? 10 : 12),
                    child: Row(children: [
                      Expanded(flex: 3, child: Row(children: [
                        SmartAvatar(
                          imageUrl: e.photoUrl,
                          fallbackText: e.nom,
                          radius: mobile ? 14 : 18,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(e.nom, style: TextStyle(fontWeight: FontWeight.w600, fontSize: mobile ? 12 : 13)),
                                Text('CIN: ${e.cin}', style: TextStyle(color: Colors.grey[500], fontSize: mobile ? 10 : 11)),
                                if (chefEquipeNom != null) ...[
                                  const SizedBox(height: 3),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppColors.brand.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      'Chef d\'équipe • $chefEquipeNom',
                                      style: TextStyle(fontSize: mobile ? 9 : 10, color: AppColors.brand, fontWeight: FontWeight.w700),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ]),
                        ),
                      ])),
                      if (!isChefOnly) ...[
                        Expanded(flex: 2, child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(e.poste, style: TextStyle(fontSize: mobile ? 12 : 13)),
                              Text(e.magasin, style: TextStyle(color: Colors.grey[500], fontSize: mobile ? 10 : 11)),
                            ])),
                        Expanded(flex: 2, child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: e.typeContrat == 'CDI' ? AppColors.brandLight : Colors.orange.shade50,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(e.typeContrat, style: TextStyle(fontSize: mobile ? 10 : 11, color: e.typeContrat == 'CDI' ? AppColors.brand : Colors.orange, fontWeight: FontWeight.bold)),
                              ),
                              Text('Depuis ${e.dateDebut}', style: TextStyle(color: Colors.grey[500], fontSize: mobile ? 10 : 11)),
                            ])),
                        Expanded(flex: 2, child: Text(_getChefNom(e.chefDirectId, employes), style: TextStyle(fontSize: mobile ? 12 : 13))),
                        if (isDirecteur) Expanded(flex: 1, child: Text('${e.salaireBase.toInt()} DH', style: TextStyle(fontSize: mobile ? 12 : 13, fontWeight: FontWeight.w600))),
                      ],
                      Expanded(flex: 2, child: Container(
                        padding: EdgeInsets.symmetric(horizontal: mobile ? 6 : 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: e.statut.color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(e.statut.icon, size: mobile ? 12 : 14, color: e.statut.color),
                            SizedBox(width: mobile ? 4 : 6),
                            Flexible(child: Text(e.statut.label, style: TextStyle(fontSize: mobile ? 10 : 12, color: e.statut.color, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
                          ],
                        ),
                      )),
                      if (isChefOnly)
                        const SizedBox(width: 60),
                      if (!isChefOnly)
                      SizedBox(
                        width: actionsColumnWidth,
                        child: canManageEmployees
                            ? ClipRect(
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  reverse: true,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.visibility, size: 18),
                                        tooltip: 'Voir détails',
                                        onPressed: () => showDialog(context: context, builder: (_) => EmployeeDetailDialog(employe: e, allEmployes: employes, isDirecteur: isDirecteur)),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                        style: IconButton.styleFrom(
                                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                        ),
                                      ),
                                      IconButton(
                                        icon: Icon(Icons.edit, size: 18, color: Colors.green[700]),
                                        tooltip: 'Modifier',
                                        onPressed: () => showDialog(
                                          context: context,
                                          builder: (_) => EmployeeEditDialog(
                                            employe: e,
                                            allEmployes: employes,
                                            onSave: (updated) async {
                                              await prov.updateEmploye(updated);
                                            },
                                          ),
                                        ),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                        style: IconButton.styleFrom(
                                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                        ),
                                      ),
                                      IconButton(
                                        icon: Icon(Icons.swap_horiz, size: 18, color: AppColors.brand),
                                        tooltip: 'Changer statut',
                                        onPressed: () => _showChangeStatutDialog(context, e, prov),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                        style: IconButton.styleFrom(
                                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                        ),
                                      ),
                                      if (canDeleteEmployees)
                                        IconButton(
                                          icon: Icon(Icons.delete_outline, size: 18, color: Colors.red[700]),
                                          tooltip: 'Supprimer le collaborateur',
                                          onPressed: () => _showDeleteEmployeConfirm(context, e, prov),
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                          style: IconButton.styleFrom(
                                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              )
                            : (isDirecteur
                                ? const SizedBox.shrink()
                                : IconButton(
                                    icon: Icon(Icons.swap_horiz, size: 18, color: AppColors.brand),
                                    onPressed: () => _showChangeStatutDialog(context, e, prov),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                    style: IconButton.styleFrom(
                                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    ),
                                  )),
                      ),
                    ]),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  void _showChangeStatutDialog(BuildContext context, Employe employe, EmployeesProvider prov) {
    EmployeStatut selected = employe.statut;
    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setStateD) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Row(children: [
            const Icon(Icons.swap_horiz, color: Color(0xFF000966)),
            const SizedBox(width: 8),
            Text('Statut - ${employe.nom}'),
          ]),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: EmployeStatut.values.map((s) {
              final isSelected = selected == s;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: InkWell(
                  onTap: () => setStateD(() => selected = s),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? s.color.withOpacity(0.15)
                          : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected ? s.color : Colors.grey.shade200,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Row(children: [
                      Icon(s.icon,
                          color: isSelected ? s.color : Colors.grey,
                          size: 20),
                      const SizedBox(width: 10),
                      Text(s.label,
                          style: TextStyle(
                              color: isSelected ? s.color : Colors.grey,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal)),
                      const Spacer(),
                      if (isSelected)
                        Icon(Icons.check_circle,
                            color: s.color, size: 18),
                    ]),
                  ),
                ),
              );
            }).toList(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () async {
                await prov.updateEmployeStatut(employe.id, selected);
                if (context.mounted) Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF000966),
                foregroundColor: Colors.white,
              ),
              child: const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteEmployeConfirm(BuildContext context, Employe employe, EmployeesProvider prov) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Row(
          children: [
            Icon(Icons.delete_outline, color: Colors.red[700], size: 24),
            const SizedBox(width: 8),
            const Expanded(child: Text('Supprimer le collaborateur')),
          ],
        ),
        content: Text(
          'Êtes-vous sûr de vouloir supprimer « ${employe.nom} » ? Cette action est irréversible.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await prov.deleteEmploye(employe.id);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Collaborateur ${employe.nom} supprimé'),
                    backgroundColor: Colors.green,
                    behavior: SnackBarBehavior.fixed,
                  ),
                );
              }
            },
            child: Text('Supprimer', style: TextStyle(color: Colors.red[700], fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}