import 'package:flutter/material.dart';
import '../models/employe_model.dart';
import 'documents_tab.dart';

class EmployeeDetailDialog extends StatelessWidget {
  final Employe employe;
  final List<Employe> allEmployes;
  final bool isDirecteur;

  const EmployeeDetailDialog({
    super.key,
    required this.employe,
    required this.allEmployes,
    this.isDirecteur = true,
  });

  String _getChefNom(String chefId) {
    if (chefId.isEmpty) return '—';
    final chef = allEmployes.where((e) => e.id == chefId).toList();
    return chef.isNotEmpty ? chef.first.nom : '—';
  }

  @override
  Widget build(BuildContext context) {
    final e = employe;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 640,
        height: 560,
        padding: const EdgeInsets.all(28),
        child: DefaultTabController(
          length: 4,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // HEADER
              Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: const Color(0xFF1565C0).withOpacity(0.15),
                    child: Text(e.nom[0],
                        style: const TextStyle(
                            fontSize: 22,
                            color: Color(0xFF1565C0),
                            fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(e.nom,
                            style: const TextStyle(
                                fontSize: 20, fontWeight: FontWeight.bold)),
                        Text('${e.poste} - ${e.magasin}',
                            style: TextStyle(color: Colors.grey[600])),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: e.statut.color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(e.statut.icon, color: e.statut.color, size: 14),
                      const SizedBox(width: 6),
                      Text(e.statut.label,
                          style: TextStyle(
                              color: e.statut.color,
                              fontWeight: FontWeight.bold)),
                    ]),
                  ),
                  const SizedBox(width: 12),
                  IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close)),
                ],
              ),
              const SizedBox(height: 16),

              // TABS
              TabBar(
                labelColor: const Color(0xFF1565C0),
                unselectedLabelColor: Colors.grey,
                indicatorColor: const Color(0xFF1565C0),
                tabs: const [
                  Tab(icon: Icon(Icons.person, size: 18), text: 'Identité'),
                  Tab(icon: Icon(Icons.work, size: 18), text: 'Contrat'),
                  Tab(icon: Icon(Icons.assignment, size: 18), text: 'CNSS'),
                  Tab(icon: Icon(Icons.folder, size: 18), text: 'Documents'),
                ],
              ),
              const SizedBox(height: 16),

              // TAB CONTENT
              Expanded(
                child: TabBarView(
                  children: [
                    // TAB 1 - IDENTITÉ
                    SingleChildScrollView(
                      child: Column(children: [
                        _card(children: [
                          _row('Nom complet', e.nom),
                          _row('CIN', e.cin),
                          _row('Date de naissance', e.dateNaissance),
                          _row('Adresse', e.adresse),
                        ]),
                        const SizedBox(height: 12),
                        _card(children: [
                          _row('Téléphone', e.telephone),
                          if (e.telephone2.isNotEmpty)
                            _row('Téléphone 2', e.telephone2),
                          _row('Email', e.email),
                        ]),
                      ]),
                    ),

                    // TAB 2 - CONTRAT
                    SingleChildScrollView(
                      child: Column(children: [
                        _card(children: [
                          _row('Poste', e.poste),
                          _row('Magasin', e.magasin),
                          _row('Département', e.departement),
                          _row('Chef direct', _getChefNom(e.chefDirectId)),
                        ]),
                        const SizedBox(height: 12),
                        _card(children: [
                          _row('Type contrat', e.typeContrat),
                          _row('Date début', e.dateDebut),
                          if (e.finContrat.isNotEmpty)
                            _row('Fin contrat', e.finContrat),
                          // ✅ الراتب فقط للـ Directeur
                          if (isDirecteur)
                            _row('Salaire base',
                                '${e.salaireBase.toInt()} DH'),
                        ]),
                      ]),
                    ),

                    // TAB 3 - CNSS
                    SingleChildScrollView(
                      child: _card(children: [
                        _row('Numéro CNSS', e.cnss),
                        _row('Date inscription', e.dateCnss),
                      ]),
                    ),

                    // TAB 4 - DOCUMENTS
                    DocumentsTab(employe: e),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _card({required List<Widget> children}) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.grey.shade50,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.grey.shade200),
    ),
    child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, children: children),
  );

  Widget _row(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(children: [
      SizedBox(
          width: 130,
          child: Text(label,
              style:
              TextStyle(color: Colors.grey[600], fontSize: 13))),
      Expanded(
          child: Text(value,
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w500))),
    ]),
  );
}