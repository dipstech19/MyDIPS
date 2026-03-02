import 'package:flutter/material.dart';
import '../models/employe_model.dart';

class EmployeeFormDialog extends StatefulWidget {
  final List<Employe> employes;
  final Function(Employe) onSave;

  const EmployeeFormDialog({
    super.key,
    required this.employes,
    required this.onSave,
  });

  @override
  State<EmployeeFormDialog> createState() => _EmployeeFormDialogState();
}

class _EmployeeFormDialogState extends State<EmployeeFormDialog> {
  final _formKey = GlobalKey<FormState>();

  final _nomCtrl = TextEditingController();
  final _cinCtrl = TextEditingController();
  final _telCtrl = TextEditingController();
  final _tel2Ctrl = TextEditingController();
  final _naissanceCtrl = TextEditingController();
  final _adresseCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _salaireCtrl = TextEditingController();
  final _dateDebutCtrl = TextEditingController();
  final _finContratCtrl = TextEditingController();
  final _cnssCtrl = TextEditingController();
  final _dateCnssCtrl = TextEditingController();

  String _poste = 'Vendeur';
  String _magasin = 'El Jadida #1';
  String _dept = 'Ventes';
  String _contrat = 'CDI';
  String _chefId = '';
  EmployeStatut _statut = EmployeStatut.enService;

  final _postes = ['Vendeur', 'Caissier', 'Manager', 'Chauffeur', 'Technicien'];
  final _magasins = ['El Jadida #1', 'El Jadida #2', 'Entrepôt'];
  final _depts = ['Ventes', 'Logistique', 'Administration', 'Technique'];
  final _contrats = ['CDI', 'CDD', 'Stage'];

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 750,
        height: 640,
        padding: const EdgeInsets.all(28),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // HEADER
              Row(children: [
                const Icon(Icons.person_add, color: Color(0xFF1565C0), size: 26),
                const SizedBox(width: 12),
                const Text('Nouvel Employé',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                const Spacer(),
                IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close)),
              ]),
              const Divider(height: 24),

              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sectionTitle('🪪 Identité'),
                      const SizedBox(height: 12),
                      _row2(
                        _field(_nomCtrl, 'Nom complet *', required: true),
                        _field(_cinCtrl, 'CIN *', required: true),
                      ),
                      const SizedBox(height: 12),
                      _row2(
                        _field(_telCtrl, 'Téléphone *', required: true),
                        _field(_tel2Ctrl, 'Téléphone 2'),
                      ),
                      const SizedBox(height: 12),
                      _row2(
                        _dateField(_naissanceCtrl, 'Date de naissance *', required: true),
                        _field(_emailCtrl, 'Email'),
                      ),
                      const SizedBox(height: 12),
                      _field(_adresseCtrl, 'Adresse *', required: true),

                      const SizedBox(height: 20),
                      _sectionTitle('💼 Travail'),
                      const SizedBox(height: 12),
                      _row2(
                        _dropdown('Poste *', _poste, _postes, (v) => setState(() => _poste = v!)),
                        _dropdown('Magasin *', _magasin, _magasins, (v) => setState(() => _magasin = v!)),
                      ),
                      const SizedBox(height: 12),
                      _row2(
                        _dropdown('Département *', _dept, _depts, (v) => setState(() => _dept = v!)),
                        _field(_salaireCtrl, 'Salaire base (DH) *', required: true, isNumber: true),
                      ),
                      const SizedBox(height: 12),
                      _row2(
                        _dropdown('Type contrat *', _contrat, _contrats, (v) => setState(() => _contrat = v!)),
                        _dateField(_dateDebutCtrl, 'Date début *', required: true),
                      ),
                      const SizedBox(height: 12),
                      _row2(
                        _contrat != 'CDI'
                            ? _dateField(_finContratCtrl, 'Fin contrat *')
                            : const SizedBox(),
                        _dropdownEmploye(),
                      ),
                      const SizedBox(height: 12),
                      // STATUT
                      const Text('Statut *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 10,
                        children: EmployeStatut.values.map((s) {
                          final isSelected = _statut == s;
                          return InkWell(
                            onTap: () => setState(() => _statut = s),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: isSelected ? s.color.withOpacity(0.15) : Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isSelected ? s.color : Colors.grey.shade300,
                                  width: isSelected ? 2 : 1,
                                ),
                              ),
                              child: Row(mainAxisSize: MainAxisSize.min, children: [
                                Icon(s.icon, color: isSelected ? s.color : Colors.grey, size: 16),
                                const SizedBox(width: 6),
                                Text(s.label,
                                    style: TextStyle(
                                        color: isSelected ? s.color : Colors.grey,
                                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                        fontSize: 13)),
                              ]),
                            ),
                          );
                        }).toList(),
                      ),

                      const SizedBox(height: 20),
                      _sectionTitle('📋 CNSS'),
                      const SizedBox(height: 12),
                      _row2(
                        _field(_cnssCtrl, 'Numéro CNSS *', required: true),
                        _dateField(_dateCnssCtrl, 'Date inscription CNSS *', required: true),
                      ),
                    ],
                  ),
                ),
              ),

              const Divider(height: 24),
              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Annuler'),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.save),
                  label: const Text('Enregistrer'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1565C0),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  void _save() {
    if (_formKey.currentState!.validate()) {
      widget.onSave(Employe(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        nom: _nomCtrl.text,
        cin: _cinCtrl.text,
        telephone: _telCtrl.text,
        telephone2: _tel2Ctrl.text,
        dateNaissance: _naissanceCtrl.text,
        adresse: _adresseCtrl.text,
        email: _emailCtrl.text,
        poste: _poste,
        magasin: _magasin,
        departement: _dept,
        salaireBase: double.tryParse(_salaireCtrl.text) ?? 0,
        typeContrat: _contrat,
        dateDebut: _dateDebutCtrl.text,
        finContrat: _finContratCtrl.text,
        chefDirectId: _chefId,
        cnss: _cnssCtrl.text,
        dateCnss: _dateCnssCtrl.text,
        statut: _statut,
      ));
      Navigator.pop(context);
    }
  }

  // HELPERS
  Widget _sectionTitle(String t) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(
      color: const Color(0xFF1565C0).withOpacity(0.08),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(t, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1565C0))),
  );

  Widget _row2(Widget a, Widget b) => Row(children: [
    Expanded(child: a), const SizedBox(width: 16), Expanded(child: b),
  ]);

  Widget _field(TextEditingController ctrl, String label, {bool required = false, bool isNumber = false}) =>
      TextFormField(
        controller: ctrl,
        keyboardType: isNumber ? TextInputType.number : null,
        validator: required ? (v) => v!.isEmpty ? 'Obligatoire' : null : null,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          isDense: true,
        ),
      );

  Widget _dateField(TextEditingController ctrl, String label, {bool required = false}) =>
      TextFormField(
        controller: ctrl,
        readOnly: true,
        validator: required ? (v) => v!.isEmpty ? 'Obligatoire' : null : null,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          isDense: true,
          suffixIcon: const Icon(Icons.calendar_today, size: 18),
        ),
        onTap: () async {
          final picked = await showDatePicker(
            context: context,
            initialDate: DateTime.now(),
            firstDate: DateTime(1950),
            lastDate: DateTime(2100),
          );
          if (picked != null) {
            ctrl.text = '${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year}';
          }
        },
      );

  Widget _dropdown(String label, String value, List<String> items, void Function(String?) onChanged) =>
      DropdownButtonFormField<String>(
        value: value,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          isDense: true,
        ),
        items: items.map((i) => DropdownMenuItem(value: i, child: Text(i))).toList(),
        onChanged: onChanged,
      );

  Widget _dropdownEmploye() => DropdownButtonFormField<String>(
    value: _chefId.isEmpty ? null : _chefId,
    decoration: InputDecoration(
      labelText: 'Chef direct',
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      isDense: true,
    ),
    items: [
      const DropdownMenuItem(value: '', child: Text('— Aucun —')),
      ...widget.employes.map((e) => DropdownMenuItem(value: e.id, child: Text(e.nom))),
    ],
    onChanged: (v) => setState(() => _chefId = v ?? ''),
  );
}