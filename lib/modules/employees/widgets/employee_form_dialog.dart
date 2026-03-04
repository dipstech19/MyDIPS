import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/utils/responsive.dart';
import '../models/employe_model.dart';
import '../employees_provider.dart';
import '../postes_provider.dart';

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

  String _poste = '';
  String _magasin = '';
  String _dept = '';
  String _contrat = 'CDI';
  String _chefId = '';
  EmployeStatut _statut = EmployeStatut.enService;

  static const _contrats = ['CDI', 'CDD', 'Stage'];

  @override
  Widget build(BuildContext context) {
    final postesProv = context.watch<PostesProvider>();
    final empProv = context.watch<EmployeesProvider>();
    final posteNames = postesProv.postes.map((p) => p.nom).toList();
    final magasins = _uniqueMagasins(empProv);
    final depts = _uniqueDepartements(empProv);
    final mobile = isMobile(context);
    final maxW = dialogMaxWidth(context);
    final maxH = dialogMaxHeight(context);
    final padding = mobile ? 16.0 : 28.0;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: EdgeInsets.symmetric(
        horizontal: dialogMargin(context),
        vertical: dialogMargin(context),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: maxW,
          maxHeight: maxH,
        ),
        child: Container(
          padding: EdgeInsets.all(padding),
          child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // HEADER
              Row(children: [
                Icon(Icons.person_add, color: const Color(0xFF1565C0), size: mobile ? 22 : 26),
                SizedBox(width: mobile ? 8 : 12),
                Expanded(
                  child: Text('Nouvel Employé',
                      style: TextStyle(fontSize: mobile ? 18 : 22, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis),
                ),
                IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 40, minHeight: 40)),
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
                        _dropdownPoste(posteNames),
                        _dropdown('Magasin *', _magasin, magasins.isEmpty ? ['—'] : magasins, (v) => setState(() => _magasin = v ?? '')),
                      ),
                      const SizedBox(height: 12),
                      _row2(
                        _dropdown('Département *', _dept, depts.isEmpty ? ['—'] : depts, (v) => setState(() => _dept = v ?? '')),
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
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Annuler'),
                  ),
                  const SizedBox(width: 12),
                  Flexible(
                    child: ElevatedButton.icon(
                      onPressed: _save,
                      icon: Icon(Icons.save, size: mobile ? 18 : 24),
                      label: const Text('Enregistrer'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1565C0),
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(
                          horizontal: mobile ? 16 : 24,
                          vertical: mobile ? 12 : 14,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        ),
      ),
    );
  }

  void _save() {
    if (_formKey.currentState!.validate()) {
      final posteNames = context.read<PostesProvider>().postes.map((p) => p.nom).toList();
      final empProv = context.read<EmployeesProvider>();
      final magasins = _uniqueMagasins(empProv);
      final depts = _uniqueDepartements(empProv);
      final poste = _poste.isEmpty && posteNames.isNotEmpty ? posteNames.first : _poste;
      final magasin = _magasin.isEmpty && magasins.isNotEmpty && magasins.first != '—' ? magasins.first : _magasin;
      final dept = _dept.isEmpty && depts.isNotEmpty && depts.first != '—' ? depts.first : _dept;
      widget.onSave(Employe(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        nom: _nomCtrl.text,
        cin: _cinCtrl.text,
        telephone: _telCtrl.text,
        telephone2: _tel2Ctrl.text,
        dateNaissance: _naissanceCtrl.text,
        adresse: _adresseCtrl.text,
        email: _emailCtrl.text,
        poste: poste,
        magasin: magasin,
        departement: dept,
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

  Widget _row2(Widget a, Widget b) {
    if (isMobile(context)) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [a, const SizedBox(height: 12), b],
      );
    }
    return Row(children: [
      Expanded(child: a),
      const SizedBox(width: 16),
      Expanded(child: b),
    ]);
  }

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

  List<String> _uniqueMagasins(EmployeesProvider prov) {
    final set = <String>{};
    for (final e in prov.equipes) if (e.magasin.isNotEmpty) set.add(e.magasin);
    for (final e in prov.employes) if (e.magasin.isNotEmpty) set.add(e.magasin);
    final list = set.toList()..sort();
    return list.isEmpty ? ['—'] : list;
  }

  List<String> _uniqueDepartements(EmployeesProvider prov) {
    final set = prov.employes.map((e) => e.departement).where((d) => d.isNotEmpty).toSet();
    final list = set.toList()..sort();
    return list.isEmpty ? ['—'] : list;
  }

  Widget _dropdownPoste(List<String> posteNames) {
    final items = posteNames.isEmpty
        ? <String>['(Ajoutez des postes dans Paramètres > Postes)']
        : posteNames;
    final value = items.contains(_poste)
        ? _poste
        : (posteNames.isNotEmpty ? posteNames.first : items.first);
    return DropdownButtonFormField<String>(
      value: value,
      decoration: const InputDecoration(
        labelText: 'Poste *',
        border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8))),
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        isDense: true,
      ),
      items: items.map((i) => DropdownMenuItem(value: i, child: Text(i))).toList(),
      onChanged: (v) => setState(() => _poste = v ?? ''),
    );
  }

  Widget _dropdown(String label, String value, List<String> items, void Function(String?) onChanged) =>
      DropdownButtonFormField<String>(
        value: value.isEmpty && items.isNotEmpty ? items.first : value,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          isDense: true,
        ),
        items: items.map((i) => DropdownMenuItem(value: i, child: Text(i))).toList(),
        onChanged: onChanged,
      );

  /// الموظفون الذين منصبهم "Chef" أو يحتوي على "chef" (مثلاً Chef d'équipe) — يظهرون فقط في قائمة Chef direct
  static bool _isChefPoste(String poste) {
    final p = poste.trim().toLowerCase();
    return p.contains('chef') || p == 'shef';
  }

  Widget _dropdownEmploye() {
    final chefCandidates = widget.employes.where((e) => _isChefPoste(e.poste)).toList();
    final value = _chefId.isEmpty || !chefCandidates.any((e) => e.id == _chefId)
        ? ''
        : _chefId;
    return DropdownButtonFormField<String>(
      value: value,
      decoration: const InputDecoration(
        labelText: 'Chef direct',
        border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8))),
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        isDense: true,
      ),
      items: [
        const DropdownMenuItem(value: '', child: Text('— Aucun —')),
        ...chefCandidates.map((e) => DropdownMenuItem(value: e.id, child: Text('${e.nom} — ${e.poste}'))),
      ],
      onChanged: (v) => setState(() => _chefId = v ?? ''),
    );
  }
}