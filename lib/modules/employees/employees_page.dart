import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/auth/auth_provider.dart';
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
  EmployeStatut? _filterStatut;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<Employe> _employes(EmployeesProvider prov, AuthProvider auth) {
    if (auth.isDirecteur) return prov.employes;
    final eqId = auth.equipeId;
    if (eqId == null || eqId.isEmpty) return [];
    final eq = prov.equipes.where((e) => e.id == eqId).toList();
    if (eq.isEmpty) return [];
    final ids = [...eq.first.membreIds, eq.first.chefId];
    return prov.employes.where((e) => ids.contains(e.id)).toList();
  }

  List<Equipe> _equipes(EmployeesProvider prov, AuthProvider auth) {
    if (auth.isDirecteur) return prov.equipes;
    final eqId = auth.equipeId;
    if (eqId == null || eqId.isEmpty) return [];
    return prov.equipes.where((e) => e.id == eqId).toList();
  }

  List<Employe> _filtered(List<Employe> employes) => employes.where((e) {
    final q = _search.toLowerCase();
    final matchSearch = q.isEmpty ||
        e.nom.toLowerCase().contains(q) ||
        e.cin.toLowerCase().contains(q) ||
        e.telephone.contains(q) ||
        e.poste.toLowerCase().contains(q) ||
        e.magasin.toLowerCase().contains(q);
    final matchStatut =
        _filterStatut == null || e.statut == _filterStatut;
    return matchSearch && matchStatut;
  }).toList();

  String _getChefNom(String chefId, List<Employe> employes) {
    if (chefId.isEmpty) return '—';
    final chef = employes.where((e) => e.id == chefId).toList();
    return chef.isNotEmpty ? chef.first.nom : '—';
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
    final prov = context.watch<EmployeesProvider>();
    final employes = _employes(prov, auth);
    final equipes = _equipes(prov, auth);
    final filtered = _filtered(employes);

    final padding = pagePadding(context);
    final mobile = isMobile(context);

    // Show loading indicator
    if (prov.loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: padding, vertical: mobile ? 12 : 16),
      child: Column(
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
                Text('Gestion des Employés', style: TextStyle(fontSize: titleFontSize(context), fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(auth.isDirecteur ? 'Vue complète - ${employes.length} employés' : 'Mon équipe - ${employes.length} membre(s)', style: TextStyle(color: Colors.grey[600], fontSize: subtitleFontSize(context))),
                if (auth.isDirecteur) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => showDialog(context: context, builder: (_) => EmployeeFormDialog(employes: employes, onSave: (e) async { await prov.addEmploye(e); })),
                      icon: const Icon(Icons.person_add, size: 20),
                      label: const Text('Nouvel Employé'),
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1565C0), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14)),
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
                    Text('Gestion des Employés', style: TextStyle(fontSize: titleFontSize(context), fontWeight: FontWeight.bold)),
                    Text(auth.isDirecteur ? 'Vue complète - ${employes.length} employés' : 'Mon équipe - ${employes.length} membre(s)', style: TextStyle(color: Colors.grey[600], fontSize: subtitleFontSize(context))),
                  ],
                ),
                if (auth.isDirecteur)
                  ElevatedButton.icon(
                    onPressed: () => showDialog(context: context, builder: (_) => EmployeeFormDialog(employes: employes, onSave: (e) async { await prov.addEmploye(e); })),
                    icon: const Icon(Icons.person_add),
                    label: const Text('Nouvel Employé'),
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1565C0), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14)),
                  ),
              ],
            ),
          SizedBox(height: mobile ? 16 : 20),

          // ===== SEARCH + FILTER =====
          Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    hintText: mobile ? 'Rechercher...' : 'Rechercher : Nom, CIN, Téléphone, Poste, Magasin...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    contentPadding: EdgeInsets.symmetric(vertical: mobile ? 10 : 12),
                    isDense: mobile,
                  ),
                  onChanged: (v) => setState(() => _search = v),
                ),
              ),
              SizedBox(width: mobile ? 8 : 12),
              Flexible(
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: ([null, ...EmployeStatut.values]).map((s) {
                    final isSelected = _filterStatut == s;
                    final label = s == null ? 'Tous' : s.label;
                    final color = s == null ? Colors.grey : s.color;
                    return FilterChip(
                      label: Text(label, style: TextStyle(fontSize: mobile ? 11 : 12, color: isSelected ? Colors.white : color)),
                      selected: isSelected,
                      onSelected: (_) => setState(() => _filterStatut = s),
                      backgroundColor: Colors.white,
                      selectedColor: color,
                      side: BorderSide(color: color),
                      padding: EdgeInsets.symmetric(horizontal: mobile ? 6 : 8, vertical: mobile ? 0 : 4),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
          SizedBox(height: mobile ? 12 : 16),

          // ===== TABS =====
          TabBar(
            controller: _tabController,
            labelColor: const Color(0xFF1565C0),
            unselectedLabelColor: Colors.grey,
            indicatorColor: const Color(0xFF1565C0),
            tabs: [
              Tab(
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.people, size: 18),
                  const SizedBox(width: 8),
                  Text('Employés (${employes.length})'),
                ]),
              ),
              Tab(
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.groups, size: 18),
                  const SizedBox(width: 8),
                  Text('Équipes (${equipes.length})'),
                ]),
              ),
            ],
          ),
          const SizedBox(height: 16),

          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildEmployesTab(context, employes, equipes, filtered, auth.isDirecteur, prov),
                EquipesTab(
                  equipes: equipes,
                  employes: employes,
                  isDirecteur: auth.isDirecteur,
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
      ),
    );
  }

  Widget _buildEmployesTab(BuildContext context, List<Employe> employes, List<Equipe> equipes, List<Employe> filtered, bool isDirecteur, EmployeesProvider prov) {
    final mobile = isMobile(context);
    return Column(
      children: [
        // STATS (scroll horizontal sur mobile pour éviter overflow)
        mobile
            ? SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: EmployeStatut.values.map((s) {
                    final count = employes.where((e) => e.statut == s).length;
                    return Container(
                      width: 120,
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: s.color.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: s.color.withOpacity(0.3)),
                      ),
                      child: Row(children: [
                        Icon(s.icon, color: s.color, size: 18),
                        const SizedBox(width: 6),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('$count', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: s.color)),
                            Text(s.label, style: TextStyle(fontSize: 10, color: Colors.grey[600])),
                          ],
                        ),
                      ]),
                    );
                  }).toList(),
                ),
              )
            : Row(
                children: EmployeStatut.values.map((s) {
                  final count = employes.where((e) => e.statut == s).length;
                  return Expanded(
                    child: Container(
                      margin: const EdgeInsets.only(right: 12),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: s.color.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: s.color.withOpacity(0.3)),
                      ),
                      child: Row(children: [
                        Icon(s.icon, color: s.color, size: 20),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('$count', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: s.color)),
                            Text(s.label, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                          ],
                        ),
                      ]),
                    ),
                  );
                }).toList(),
              ),
        const SizedBox(height: 16),

        // TABLE (horizontal scroll on mobile; fixed height so Column+Expanded layout works)
        Expanded(
          child: mobile
              ? LayoutBuilder(
                  builder: (context, constraints) {
                    return SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SizedBox(
                        width: 700,
                        height: constraints.maxHeight,
                        child: _employesTable(context, employes, filtered, isDirecteur, prov),
                      ),
                    );
                  },
                )
              : _employesTable(context, employes, filtered, isDirecteur, prov),
        ),
      ],
    );
  }

  Widget _employesTable(BuildContext context, List<Employe> employes, List<Employe> filtered, bool isDirecteur, EmployeesProvider prov) {
    final mobile = isMobile(context);
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
              const Expanded(flex: 3, child: Text('Employé', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13), overflow: TextOverflow.ellipsis)),
              const Expanded(flex: 2, child: Text('Poste / Magasin', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13), overflow: TextOverflow.ellipsis)),
              const Expanded(flex: 2, child: Text('Contrat', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13), overflow: TextOverflow.ellipsis)),
              const Expanded(flex: 2, child: Text('Chef direct', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13), overflow: TextOverflow.ellipsis)),
              if (isDirecteur) const Expanded(flex: 1, child: Text('Salaire', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13), overflow: TextOverflow.ellipsis)),
              const Expanded(flex: 2, child: Text('Statut', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13), overflow: TextOverflow.ellipsis)),
              SizedBox(width: mobile ? 100 : 120, child: const Text('Actions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13), overflow: TextOverflow.ellipsis)),
            ]),
          ),
          const Divider(height: 1),
          if (filtered.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Center(child: Text('Aucun employé trouvé', style: TextStyle(color: Colors.grey[600], fontSize: mobile ? 12 : 14))),
            )
          else
            Expanded(
              child: ListView.separated(
                itemCount: filtered.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final e = filtered[i];
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
                                  Text(e.cin, style: TextStyle(color: Colors.grey[500], fontSize: mobile ? 10 : 11)),
                                ]),
                          ),
                        ])),
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
                                  color: e.typeContrat == 'CDI' ? Colors.blue.shade50 : Colors.orange.shade50,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(e.typeContrat, style: TextStyle(fontSize: mobile ? 10 : 11, color: e.typeContrat == 'CDI' ? Colors.blue : Colors.orange, fontWeight: FontWeight.bold)),
                              ),
                              Text('Depuis ${e.dateDebut}', style: TextStyle(color: Colors.grey[500], fontSize: mobile ? 10 : 11)),
                            ])),
                        Expanded(flex: 2, child: Text(_getChefNom(e.chefDirectId, employes), style: TextStyle(fontSize: mobile ? 12 : 13))),
                        if (isDirecteur) Expanded(flex: 1, child: Text('${e.salaireBase.toInt()} DH', style: TextStyle(fontSize: mobile ? 12 : 13, fontWeight: FontWeight.w600))),
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
                        SizedBox(
                          width: mobile ? 100 : 120,
                          child: isDirecteur
                              ? Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.visibility, size: 18),
                                      tooltip: 'Voir détails',
                                      onPressed: () => showDialog(context: context, builder: (_) => EmployeeDetailDialog(employe: e, allEmployes: employes, isDirecteur: isDirecteur)),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
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
                                    ),
                                    IconButton(
                                      icon: Icon(Icons.swap_horiz, size: 18, color: Colors.blue[700]),
                                      tooltip: 'Changer statut',
                                      onPressed: () => _showChangeStatutDialog(context, e, prov),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                    ),
                                  ],
                                )
                              : IconButton(
                                  icon: Icon(Icons.swap_horiz, size: 18, color: Colors.blue[700]),
                                  onPressed: () => _showChangeStatutDialog(context, e, prov),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                ),
                        ),
                      ]),
                    ),
                  );
                },
              ),
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
            const Icon(Icons.swap_horiz, color: Color(0xFF1565C0)),
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
                backgroundColor: const Color(0xFF1565C0),
                foregroundColor: Colors.white,
              ),
              child: const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );
  }
}