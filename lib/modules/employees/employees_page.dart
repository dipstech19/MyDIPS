import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/auth/auth_provider.dart';
import 'models/employe_model.dart';
import 'models/equipe_model.dart';
import 'data/dummy_data.dart';
import 'widgets/employee_detail_dialog.dart';
import 'widgets/employee_form_dialog.dart';
import 'widgets/equipes_tab.dart';

class EmployeesPage extends StatefulWidget {
  const EmployeesPage({super.key});

  @override
  State<EmployeesPage> createState() => _EmployeesPageState();
}

class _EmployeesPageState extends State<EmployeesPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late List<Employe> _employes;
  late List<Equipe> _equipes;
  late bool _isDirecteur;
  String _search = '';
  EmployeStatut? _filterStatut;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _initData();
  }

  void _initData() {
    final auth = context.read<AuthProvider>();
    _isDirecteur = auth.isDirecteur;

    if (_isDirecteur) {
      // ✅ Directeur → كل شي
      _employes = List.from(dummyEmployes);
      _equipes = List.from(dummyEquipes);
    } else {
      // ✅ Chef Équipe → فريقه فقط
      final monEquipe = dummyEquipes
          .where((eq) => eq.id == auth.equipeId)
          .toList();
      _equipes = monEquipe;

      if (monEquipe.isNotEmpty) {
        final eq = monEquipe.first;
        final ids = [...eq.membreIds, eq.chefId];
        _employes = dummyEmployes
            .where((e) => ids.contains(e.id))
            .toList();
      } else {
        _employes = [];
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<Employe> get _filtered => _employes.where((e) {
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

  String _getChefNom(String chefId) {
    if (chefId.isEmpty) return '—';
    final chef = dummyEmployes.where((e) => e.id == chefId).toList();
    return chef.isNotEmpty ? chef.first.nom : '—';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ===== HEADER =====
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Gestion des Employés',
                      style: TextStyle(
                          fontSize: 26, fontWeight: FontWeight.bold)),
                  Text(
                    _isDirecteur
                        ? 'Vue complète - ${_employes.length} employés'
                        : 'Mon équipe - ${_employes.length} membre(s)',
                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                  ),
                ],
              ),
              // زر إضافة فقط للـ Directeur
              if (_isDirecteur)
                ElevatedButton.icon(
                  onPressed: () => showDialog(
                    context: context,
                    builder: (_) => EmployeeFormDialog(
                      employes: _employes,
                      onSave: (e) => setState(() => _employes.add(e)),
                    ),
                  ),
                  icon: const Icon(Icons.person_add),
                  label: const Text('Nouvel Employé'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1565C0),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 14),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),

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
                  Text('Employés (${_employes.length})'),
                ]),
              ),
              Tab(
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.groups, size: 18),
                  const SizedBox(width: 8),
                  Text('Équipes (${_equipes.length})'),
                ]),
              ),
            ],
          ),
          const SizedBox(height: 16),

          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildEmployesTab(),
                EquipesTab(
                  equipes: _equipes,
                  employes: _employes,
                  isDirecteur: _isDirecteur,
                  onAddEquipe: (eq) => setState(() {
                    final idx = _equipes.indexWhere((e) => e.id == eq.id);
                    if (idx >= 0) {
                      _equipes[idx] = eq;
                    } else {
                      _equipes.add(eq);
                    }
                  }),
                  onDeleteEquipe: (eq) =>
                      setState(() => _equipes.remove(eq)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmployesTab() {
    return Column(
      children: [
        // STATS
        Row(
          children: EmployeStatut.values.map((s) {
            final count = _employes.where((e) => e.statut == s).length;
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
                      children: [
                        Text('$count',
                            style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: s.color)),
                        Text(s.label,
                            style: TextStyle(
                                fontSize: 11, color: Colors.grey[600])),
                      ]),
                ]),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),

        // SEARCH + FILTER
        Row(
          children: [
            Expanded(
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Rechercher : Nom, CIN, Téléphone, Poste...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                  contentPadding:
                  const EdgeInsets.symmetric(vertical: 12),
                ),
                onChanged: (v) => setState(() => _search = v),
              ),
            ),
            const SizedBox(width: 12),
            ...([null, ...EmployeStatut.values]).map((s) {
              final isSelected = _filterStatut == s;
              final label = s == null ? 'Tous' : s.label;
              final color = s == null ? Colors.grey : s.color;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(label,
                      style: TextStyle(
                          fontSize: 12,
                          color: isSelected ? Colors.white : color)),
                  selected: isSelected,
                  onSelected: (_) =>
                      setState(() => _filterStatut = s),
                  backgroundColor: Colors.white,
                  selectedColor: color,
                  side: BorderSide(color: color),
                ),
              );
            }),
          ],
        ),
        const SizedBox(height: 12),

        // TABLE
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(12),
                        topRight: Radius.circular(12)),
                  ),
                  child: Row(children: [
                    const Expanded(flex: 3, child: Text('Employé', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                    const Expanded(flex: 2, child: Text('Poste / Magasin', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                    const Expanded(flex: 2, child: Text('Contrat', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                    const Expanded(flex: 2, child: Text('Chef direct', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                    // الراتب - فقط للـ Directeur
                    if (_isDirecteur)
                      const Expanded(flex: 1, child: Text('Salaire', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                    const Expanded(flex: 2, child: Text('Statut', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                    const SizedBox(width: 80, child: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                  ]),
                ),
                const Divider(height: 1),
                Expanded(
                  child: _filtered.isEmpty
                      ? const Center(
                      child: Text('Aucun employé trouvé',
                          style: TextStyle(color: Colors.grey)))
                      : ListView.separated(
                    itemCount: _filtered.length,
                    separatorBuilder: (_, __) =>
                    const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final e = _filtered[i];
                      return InkWell(
                        onTap: () => showDialog(
                          context: context,
                          builder: (_) => EmployeeDetailDialog(
                              employe: e,
                              allEmployes: _employes,
                              isDirecteur: _isDirecteur),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          child: Row(children: [
                            // NOM
                            Expanded(flex: 3, child: Row(children: [
                              CircleAvatar(
                                backgroundColor: const Color(0xFF1565C0).withOpacity(0.15),
                                radius: 18,
                                child: Text(e.nom[0],
                                    style: const TextStyle(
                                        color: Color(0xFF1565C0),
                                        fontWeight: FontWeight.bold)),
                              ),
                              const SizedBox(width: 10),
                              Expanded(child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(e.nom, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                    Text(e.cin, style: TextStyle(color: Colors.grey[500], fontSize: 11)),
                                  ])),
                            ])),
                            // POSTE
                            Expanded(flex: 2, child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(e.poste, style: const TextStyle(fontSize: 13)),
                                  Text(e.magasin, style: TextStyle(color: Colors.grey[500], fontSize: 11)),
                                ])),
                            // CONTRAT
                            Expanded(flex: 2, child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: e.typeContrat == 'CDI' ? Colors.blue.shade50 : Colors.orange.shade50,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(e.typeContrat,
                                        style: TextStyle(
                                            fontSize: 11,
                                            color: e.typeContrat == 'CDI' ? Colors.blue : Colors.orange,
                                            fontWeight: FontWeight.bold)),
                                  ),
                                  Text('Depuis ${e.dateDebut}',
                                      style: TextStyle(color: Colors.grey[500], fontSize: 11)),
                                ])),
                            // CHEF
                            Expanded(flex: 2, child: Text(
                                _getChefNom(e.chefDirectId),
                                style: const TextStyle(fontSize: 13))),
                            // SALAIRE - فقط Directeur
                            if (_isDirecteur)
                              Expanded(flex: 1, child: Text(
                                  '${e.salaireBase.toInt()} DH',
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
                            // STATUT
                            Expanded(flex: 2, child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: e.statut.color.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(mainAxisSize: MainAxisSize.min, children: [
                                Icon(e.statut.icon, color: e.statut.color, size: 14),
                                const SizedBox(width: 4),
                                Text(e.statut.label,
                                    style: TextStyle(
                                        color: e.statut.color,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600)),
                              ]),
                            )),
                            // ACTIONS
                            SizedBox(width: 80, child: Row(children: [
                              IconButton(
                                icon: const Icon(Icons.visibility, size: 18),
                                color: Colors.blue,
                                onPressed: () => showDialog(
                                  context: context,
                                  builder: (_) => EmployeeDetailDialog(
                                      employe: e,
                                      allEmployes: _employes,
                                      isDirecteur: _isDirecteur),
                                ),
                              ),
                              // تعديل الـ Statut للـ Chef Équipe
                              IconButton(
                                icon: const Icon(Icons.edit, size: 18),
                                color: Colors.orange,
                                onPressed: () => _isDirecteur
                                    ? null // غنزيدو edit كامل بعدها
                                    : _showChangeStatutDialog(context, e),
                              ),
                            ])),
                          ]),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // Chef Équipe يقدر يبدل Statut فقط
  void _showChangeStatutDialog(BuildContext context, Employe employe) {
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
              onPressed: () {
                setState(() {
                  final idx = _employes.indexWhere((e) => e.id == employe.id);
                  if (idx >= 0) {
                    // نبنيو employe جديد بالـ statut الجديد
                    final old = _employes[idx];
                    _employes[idx] = Employe(
                      id: old.id, nom: old.nom, cin: old.cin,
                      telephone: old.telephone, telephone2: old.telephone2,
                      dateNaissance: old.dateNaissance, adresse: old.adresse,
                      email: old.email, poste: old.poste, magasin: old.magasin,
                      departement: old.departement, salaireBase: old.salaireBase,
                      typeContrat: old.typeContrat, dateDebut: old.dateDebut,
                      finContrat: old.finContrat, chefDirectId: old.chefDirectId,
                      cnss: old.cnss, dateCnss: old.dateCnss,
                      statut: selected,
                      documents: old.documents,
                    );
                  }
                });
                Navigator.pop(context);
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