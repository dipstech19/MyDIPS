import 'package:flutter/material.dart';

// ===== STATUT ENUM =====
enum EmployeStatut { enService, quitte, enConge, enMaladie }

extension EmployeStatutExt on EmployeStatut {
  String get label {
    switch (this) {
      case EmployeStatut.enService: return 'En service';
      case EmployeStatut.quitte: return 'Quitté';
      case EmployeStatut.enConge: return 'En congé';
      case EmployeStatut.enMaladie: return 'En maladi';
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
class EmployeesPage extends StatefulWidget {
  const EmployeesPage({super.key});

  @override
  State<EmployeesPage> createState() => _EmployeesPageState();
}

class _EmployeesPageState extends State<EmployeesPage> {
  final List<Employe> _employes = List.from(dummyEmployes);
  String _search = '';
  EmployeStatut? _filterStatut;

  List<Employe> get _filtered => _employes.where((e) {
    final q = _search.toLowerCase();
    final matchSearch = q.isEmpty ||
        e.nom.toLowerCase().contains(q) ||
        e.cin.toLowerCase().contains(q) ||
        e.telephone.contains(q) ||
        e.poste.toLowerCase().contains(q) ||
        e.magasin.toLowerCase().contains(q);
    final matchStatut = _filterStatut == null || e.statut == _filterStatut;
    return matchSearch && matchStatut;
  }).toList();

  String _getChefNom(String chefId) {
    if (chefId.isEmpty) return '—';
    final chef = _employes.where((e) => e.id == chefId).toList();
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
                      style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
                  Text('${_employes.length} employés au total',
                      style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                ],
              ),
              ElevatedButton.icon(
                onPressed: () => _showAddDialog(context),
                icon: const Icon(Icons.person_add),
                label: const Text('Nouvel Employé'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1565C0),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // ===== STATS =====
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
                  child: Row(
                    children: [
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
                              style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                        ],
                      ),
                    ],
                  ),
                ),
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
              ...([null, ...EmployeStatut.values]).map((s) {
                final isSelected = _filterStatut == s;
                final label = s == null ? 'Tous' : s.label;
                final color = s == null ? Colors.grey : s.color;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(label, style: TextStyle(fontSize: 12, color: isSelected ? Colors.white : color)),
                    selected: isSelected,
                    onSelected: (_) => setState(() => _filterStatut = s),
                    backgroundColor: Colors.white,
                    selectedColor: color,
                    side: BorderSide(color: color),
                  ),
                );
              }),
            ],
          ),
          const SizedBox(height: 16),

          // ===== TABLE =====
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(12),
                          topRight: Radius.circular(12)),
                    ),
                    child: const Row(
                      children: [
                        Expanded(flex: 3, child: Text('Employé', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                        Expanded(flex: 2, child: Text('Poste / Magasin', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                        Expanded(flex: 2, child: Text('Contrat', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                        Expanded(flex: 2, child: Text('Chef direct', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                        Expanded(flex: 1, child: Text('Salaire', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                        Expanded(flex: 2, child: Text('Statut', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                        SizedBox(width: 80, child: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  // Rows
                  Expanded(
                    child: _filtered.isEmpty
                        ? const Center(child: Text('Aucun employé trouvé', style: TextStyle(color: Colors.grey)))
                        : ListView.separated(
                      itemCount: _filtered.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, i) {
                        final e = _filtered[i];
                        return InkWell(
                          onTap: () => _showDetailDialog(context, e),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            child: Row(
                              children: [
                                // Employé
                                Expanded(flex: 3, child: Row(
                                  children: [
                                    CircleAvatar(
                                      backgroundColor: const Color(0xFF1565C0).withOpacity(0.15),
                                      radius: 18,
                                      child: Text(e.nom[0],
                                          style: const TextStyle(color: Color(0xFF1565C0), fontWeight: FontWeight.bold)),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(e.nom, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                        Text(e.cin, style: TextStyle(color: Colors.grey[500], fontSize: 11)),
                                      ],
                                    )),
                                  ],
                                )),
                                // Poste
                                Expanded(flex: 2, child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(e.poste, style: const TextStyle(fontSize: 13)),
                                    Text(e.magasin, style: TextStyle(color: Colors.grey[500], fontSize: 11)),
                                  ],
                                )),
                                // Contrat
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
                                    const SizedBox(height: 2),
                                    Text('Depuis ${e.dateDebut}', style: TextStyle(color: Colors.grey[500], fontSize: 11)),
                                  ],
                                )),
                                // Chef
                                Expanded(flex: 2, child: Text(_getChefNom(e.chefDirectId),
                                    style: const TextStyle(fontSize: 13))),
                                // Salaire
                                Expanded(flex: 1, child: Text('${e.salaireBase.toInt()} DH',
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
                                // Statut
                                Expanded(flex: 2, child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: e.statut.color.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(e.statut.icon, color: e.statut.color, size: 14),
                                      const SizedBox(width: 4),
                                      Text(e.statut.label,
                                          style: TextStyle(color: e.statut.color, fontSize: 12, fontWeight: FontWeight.w600)),
                                    ],
                                  ),
                                )),
                                // Actions
                                SizedBox(width: 80, child: Row(
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.visibility, size: 18),
                                      color: Colors.blue,
                                      tooltip: 'Voir détails',
                                      onPressed: () => _showDetailDialog(context, e),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.edit, size: 18),
                                      color: Colors.orange,
                                      tooltip: 'Modifier',
                                      onPressed: () {},
                                    ),
                                  ],
                                )),
                              ],
                            ),
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
      ),
    );
  }

  // ===== DETAIL DIALOG =====
  void _showDetailDialog(BuildContext context, Employe e) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: 600,
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
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(t, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
  );

  Widget _infoRow(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 100, child: Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 13))),
        Expanded(child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
      ],
    ),
  );

  // ===== ADD DIALOG (skeleton) =====
  void _showAddDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => const Dialog(
        child: SizedBox(
          width: 500,
          height: 200,
          child: Center(child: Text('Formulaire ajout employé - Bientôt')),
        ),
      ),
    );
  }
}