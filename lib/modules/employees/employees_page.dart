import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/auth/auth_provider.dart';
import 'models/employe_model.dart';
import 'models/equipe_model.dart';
import 'data/dummy_data.dart';
import 'widgets/employee_detail_dialog.dart';
import 'widgets/employee_form_dialog.dart';
import 'widgets/equipes_tab.dart';

<<<<<<< HEAD
// ===== STATUT ENUM =====
enum EmployeStatut { enService, quitte, enConge, enMaladie }

extension EmployeStatutExt on EmployeStatut {
  String get label {
    switch (this) {
      case EmployeStatut.enService: return 'En service';
      case EmployeStatut.quitte: return 'Quitté';
      case EmployeStatut.enConge: return 'En congé';
      case EmployeStatut.enMaladie: return 'En maladie';
    }
  }

  Color get color {
    switch (this) {
      case EmployeStatut.enService: return Colors.green;
      case EmployeStatut.quitte: return Colors.red;
      case EmployeStatut.enConge: return Colors.orange;
      case EmployeStatut.enMaladie: return Colors.blue;
    }
  }

  IconData get icon {
    switch (this) {
      case EmployeStatut.enService: return Icons.check_circle;
      case EmployeStatut.quitte: return Icons.cancel;
      case EmployeStatut.enConge: return Icons.beach_access;
      case EmployeStatut.enMaladie: return Icons.medical_services;
    }
  }
}

// ===== MODEL =====
class Employe {
  final String id;
  final String nom;
  final String cin;
  final String telephone;
  final String telephone2;
  final String dateNaissance;
  final String adresse;
  final String email;
  final String poste;
  final String magasin;
  final String departement;
  final double salaireBase;
  final String typeContrat;
  final String dateDebut;
  final String finContrat;
  final String chefDirectId; // ID du chef
  final String cnss;
  final String dateCnss;
  final EmployeStatut statut;

  Employe({
    required this.id,
    required this.nom,
    required this.cin,
    required this.telephone,
    this.telephone2 = '',
    required this.dateNaissance,
    required this.adresse,
    required this.email,
    required this.poste,
    required this.magasin,
    required this.departement,
    required this.salaireBase,
    required this.typeContrat,
    required this.dateDebut,
    this.finContrat = '',
    this.chefDirectId = '',
    required this.cnss,
    required this.dateCnss,
    required this.statut,
  });
}

// ===== DUMMY DATA =====
final List<Employe> dummyEmployes = [
  Employe(
    id: '001', nom: 'Fatima Zahra', cin: 'BK987654',
    telephone: '0662345678', telephone2: '',
    dateNaissance: '10/05/1988', adresse: 'Rue Hassan II, El Jadida',
    email: 'fatima@dips.ma', poste: 'Manager', magasin: 'El Jadida #1',
    departement: 'Administration', salaireBase: 8000,
    typeContrat: 'CDI', dateDebut: '01/01/2018', finContrat: '',
    chefDirectId: '', cnss: '11111111', dateCnss: '01/01/2018',
    statut: EmployeStatut.enService,
  ),
  Employe(
    id: '002', nom: 'Ahmed Benali', cin: 'BE123456',
    telephone: '0661234567', telephone2: '0661234568',
    dateNaissance: '15/03/1995', adresse: 'Rue Ibn Khaldoun, El Jadida',
    email: 'ahmed@dips.ma', poste: 'Vendeur', magasin: 'El Jadida #1',
    departement: 'Ventes', salaireBase: 3500,
    typeContrat: 'CDI', dateDebut: '18/02/2026', finContrat: '',
    chefDirectId: '001', cnss: '22222222', dateCnss: '18/02/2026',
    statut: EmployeStatut.enService,
  ),
  Employe(
    id: '003', nom: 'Youssef Alami', cin: 'CD456789',
    telephone: '0663456789', telephone2: '',
    dateNaissance: '22/07/1990', adresse: 'Bd Mohammed V, El Jadida',
    email: 'youssef@dips.ma', poste: 'Caissier', magasin: 'El Jadida #2',
    departement: 'Ventes', salaireBase: 3200,
    typeContrat: 'CDD', dateDebut: '01/06/2025', finContrat: '31/05/2026',
    chefDirectId: '001', cnss: '33333333', dateCnss: '01/06/2025',
    statut: EmployeStatut.enConge,
  ),
  Employe(
    id: '004', nom: 'Salma Idrissi', cin: 'GH321654',
    telephone: '0664567890', telephone2: '',
    dateNaissance: '08/11/1992', adresse: 'Rue Zerktouni, El Jadida',
    email: 'salma@dips.ma', poste: 'Chauffeur', magasin: 'Entrepôt',
    departement: 'Logistique', salaireBase: 3800,
    typeContrat: 'CDI', dateDebut: '20/09/2020', finContrat: '',
    chefDirectId: '001', cnss: '44444444', dateCnss: '20/09/2020',
    statut: EmployeStatut.enMaladie,
  ),
  Employe(
    id: '005', nom: 'Karim Tazi', cin: 'HB741852',
    telephone: '0665678901', telephone2: '',
    dateNaissance: '30/01/1987', adresse: 'Hay Essalam, El Jadida',
    email: 'karim@dips.ma', poste: 'Vendeur', magasin: 'El Jadida #2',
    departement: 'Ventes', salaireBase: 3500,
    typeContrat: 'CDI', dateDebut: '05/04/2023', finContrat: '',
    chefDirectId: '001', cnss: '55555555', dateCnss: '05/04/2023',
    statut: EmployeStatut.quitte,
  ),
];

// ===== MAIN PAGE =====
=======
>>>>>>> d4f0996 (Add auth module, employees module with models and widgets)
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
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
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
<<<<<<< HEAD
              );
            }).toList(),
          ),
          const SizedBox(height: 20),

          // ===== SEARCH + FILTER =====
          Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Rechercher : Nom, CIN, Téléphone, Poste, Magasin...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onChanged: (v) => setState(() => _search = v),
                ),
              ),
              const SizedBox(width: 12),
              // Filter par statut
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: ([null, ...EmployeStatut.values]).map((s) {
                  final isSelected = _filterStatut == s;
                  final label = s == null ? 'Tous' : s.label;
                  final color = s == null ? Colors.grey : s.color;
                  return FilterChip(
                    label: Text(label, style: TextStyle(fontSize: 12, color: isSelected ? Colors.white : color)),
                    selected: isSelected,
                    onSelected: (_) => setState(() => _filterStatut = s),
                    backgroundColor: Colors.white,
                    selectedColor: color,
                    side: BorderSide(color: color),
                  );
                }).toList(),
              ),
=======
>>>>>>> d4f0996 (Add auth module, employees module with models and widgets)
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

<<<<<<< HEAD
  // ===== DETAIL DIALOG =====
  void _showDetailDialog(BuildContext context, Employe e) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.9,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: const Color(0xFF1565C0).withOpacity(0.15),
                      child: Text(e.nom[0],
                          style: const TextStyle(fontSize: 22, color: Color(0xFF1565C0), fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 16),
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(e.nom, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                        Text('${e.poste} - ${e.magasin}', style: TextStyle(color: Colors.grey[600])),
                      ],
                    )),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: e.statut.color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(e.statut.label,
                          style: TextStyle(color: e.statut.color, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 12),
                    IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                  ],
                ),
                const Divider(height: 28),
                // Sections
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _sectionTitle('🪪 Identité'),
                        _infoRow('CIN', e.cin),
                        _infoRow('Tél', e.telephone),
                        if (e.telephone2.isNotEmpty) _infoRow('Tél 2', e.telephone2),
                        _infoRow('Naissance', e.dateNaissance),
                        _infoRow('Email', e.email),
                        _infoRow('Adresse', e.adresse),
                      ],
                    )),
                    const SizedBox(width: 24),
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _sectionTitle('💼 Travail'),
                        _infoRow('Département', e.departement),
                        _infoRow('Contrat', e.typeContrat),
                        _infoRow('Début', e.dateDebut),
                        if (e.finContrat.isNotEmpty) _infoRow('Fin contrat', e.finContrat),
                        _infoRow('Salaire', '${e.salaireBase.toInt()} DH'),
                        _infoRow('Chef direct', _getChefNom(e.chefDirectId)),
                        const SizedBox(height: 12),
                        _sectionTitle('📋 CNSS'),
                        _infoRow('N° CNSS', e.cnss),
                        _infoRow('Date inscription', e.dateCnss),
                      ],
                    )),
                  ],
=======
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
>>>>>>> d4f0996 (Add auth module, employees module with models and widgets)
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