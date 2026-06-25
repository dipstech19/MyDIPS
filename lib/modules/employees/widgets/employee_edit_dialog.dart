import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../../../core/site/site_model.dart';
import '../../../core/utils/responsive.dart';
import '../models/employe_model.dart';
import '../models/document_model.dart';
import '../departements_provider.dart';
import '../postes_provider.dart';
import '../services/storage_service.dart';

class EmployeeEditDialog extends StatefulWidget {
  final Employe employe;
  final List<Employe> allEmployes;
  final Function(Employe) onSave;

  const EmployeeEditDialog({
    super.key,
    required this.employe,
    required this.allEmployes,
    required this.onSave,
  });

  @override
  State<EmployeeEditDialog> createState() => _EmployeeEditDialogState();
}

class _EmployeeEditDialogState extends State<EmployeeEditDialog> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nomCtrl;
  late TextEditingController _cinCtrl;
  late TextEditingController _telCtrl;
  late TextEditingController _tel2Ctrl;
  late TextEditingController _naissanceCtrl;
  late TextEditingController _adresseCtrl;
  late TextEditingController _emailCtrl;
  late TextEditingController _salaireCtrl;
  late TextEditingController _dateDebutCtrl;
  late TextEditingController _leaveExtraCtrl;
  late TextEditingController _finContratCtrl;
  late TextEditingController _cnssCtrl;
  late TextEditingController _dateCnssCtrl;

  late String _poste;
  late String _dept;
  late String _contrat;
  late String _chefId;
  late EmployeStatut _statut;
  
  String? _photoPath;
  Uint8List? _photoBytes;
  String _existingPhotoUrl = '';
  
  late List<Document> _documents;
  final List<_TempDocument> _newDocuments = [];
  bool _badgeActif = false;
  late TextEditingController _badgeExpiryCtrl;
  late String _ocpExcelSegment;
  late bool _ocpForceSalleControle;

  static const _contrats = ['CDI', 'CDD', 'Anapec'];

  @override
  void initState() {
    super.initState();
    final e = widget.employe;
    _nomCtrl = TextEditingController(text: e.nom);
    _cinCtrl = TextEditingController(text: e.cin);
    _telCtrl = TextEditingController(text: e.telephone);
    _tel2Ctrl = TextEditingController(text: e.telephone2);
    _naissanceCtrl = TextEditingController(text: e.dateNaissance);
    _adresseCtrl = TextEditingController(text: e.adresse);
    _emailCtrl = TextEditingController(text: e.email);
    _salaireCtrl = TextEditingController(text: e.salaireBase.toStringAsFixed(0));
    _dateDebutCtrl = TextEditingController(text: e.dateDebut);
    _leaveExtraCtrl = TextEditingController(text: e.leaveDaysExtra.toStringAsFixed(1));
    _finContratCtrl = TextEditingController(text: e.finContrat);
    _cnssCtrl = TextEditingController(text: e.cnss);
    _dateCnssCtrl = TextEditingController(text: e.dateCnss);
    
    _poste = e.poste;
    _dept = e.departement;
    _contrat = _contrats.contains(e.typeContrat) ? e.typeContrat : 'CDI';
    _chefId = e.chefDirectId;
    _statut = e.statut;
    _existingPhotoUrl = e.photoUrl;
    _documents = List.from(e.documents);
    _badgeActif = e.badgeActif;
    _badgeExpiryCtrl = TextEditingController(text: e.badgeExpiration);
    final seg = e.ocpExcelSegment.trim();
    _ocpExcelSegment = OcpExcelSegmentCode.allCodes.contains(seg) ? seg : OcpExcelSegmentCode.auto;
    _ocpForceSalleControle = e.ocpForceSalleControle;
  }

  @override
  void dispose() {
    _nomCtrl.dispose();
    _cinCtrl.dispose();
    _telCtrl.dispose();
    _tel2Ctrl.dispose();
    _naissanceCtrl.dispose();
    _adresseCtrl.dispose();
    _emailCtrl.dispose();
    _salaireCtrl.dispose();
    _dateDebutCtrl.dispose();
    _leaveExtraCtrl.dispose();
    _finContratCtrl.dispose();
    _cnssCtrl.dispose();
    _dateCnssCtrl.dispose();
    _badgeExpiryCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final postesProv = context.watch<PostesProvider>();
    final deptProv = context.watch<DepartementsProvider>();
    final siteId = widget.employe.siteId;
    final posteNames = postesProv.postes
        .where((p) => p.siteId == siteId || p.siteId == SiteId.all)
        .map((p) => p.nom)
        .toList();
    const distributionPostes = ['operateur Phase 1', 'operateur Radeej', 'operateur RMC', 'operateur Digue', "Chef d'equipe"];
    final effectivePosteNames = _dept.toLowerCase().contains('distribution')
        ? distributionPostes
        : posteNames;
    final depts = _departementOptions(deptProv, current: _dept);
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
                  Icon(Icons.edit, color: const Color(0xFF000966), size: mobile ? 22 : 26),
                  SizedBox(width: mobile ? 8 : 12),
                  Expanded(
                    child: Text('Modifier le collaborateur',
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
                        // Photo de profil
                        _sectionTitle('📷 Photo de profil'),
                        const SizedBox(height: 12),
                        _buildPhotoSection(),
                        
                        const SizedBox(height: 20),
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
                        // 1. Département
                        _dropdown('Département *', _dept, depts.isEmpty ? ['—'] : depts, (v) {
                          setState(() {
                            _dept = v ?? '';
                            final newPostes = _dept.toLowerCase().contains('distribution')
                                ? distributionPostes
                                : posteNames;
                            if (!newPostes.contains(_poste)) {
                              _poste = newPostes.isNotEmpty ? newPostes.first : '';
                            }
                          });
                        }),
                        const SizedBox(height: 12),
                        // 2. Poste (filtré selon le département)
                        _dropdownPoste(effectivePosteNames),
                        const SizedBox(height: 12),
                        // 3. Salaire + Type contrat
                        _row2(
                          _field(_salaireCtrl, 'Salaire base (DH) *', required: true, isNumber: true),
                          _dropdown('Type contrat *', _contrat, _contrats, (v) => setState(() => _contrat = v!)),
                        ),
                        const SizedBox(height: 12),
                        // 4. Date début
                        _dateField(_dateDebutCtrl, 'Date début *', required: true),
                        const SizedBox(height: 12),
                        _field(
                          _leaveExtraCtrl,
                          'Solde congé additionnel / reporté (jours)',
                          isNumber: true,
                        ),
                        const SizedBox(height: 12),
                        _row2(
                          _contrat != 'CDI'
                              ? _dateField(_finContratCtrl, 'Fin contrat')
                              : const SizedBox(),
                          _dropdownEmploye(),
                        ),
                        const SizedBox(height: 12),
                        _sectionTitle('Export pointage OCP'),
                        const SizedBox(height: 8),
                        _dropdownOcpSegment(),
                        const SizedBox(height: 4),
                        CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          value: _ocpForceSalleControle,
                          onChanged: (v) => setState(() => _ocpForceSalleControle = v ?? false),
                          title: const Text('Salle de contrôle (P1)'),
                          subtitle: Text(
                            'Cocher si le libellé du poste ne contient pas « salle de contrôle » mais l’export Excel doit classer en P1.',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                          ),
                          controlAffinity: ListTileControlAffinity.leading,
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
                          _field(_cnssCtrl, 'Numéro CNSS'),
                          _dateField(_dateCnssCtrl, 'Date inscription CNSS'),
                        ),
                        
                        const SizedBox(height: 20),
                        _sectionTitle('🎫 Badge d\'accès (Site)'),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Switch(
                              value: _badgeActif,
                              onChanged: (v) => setState(() => _badgeActif = v),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Badge activé',
                                style: TextStyle(fontSize: 13, color: _badgeActif ? Colors.green[700] : Colors.grey[700], fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        _dateField(_badgeExpiryCtrl, 'Date d\'expiration du badge'),
                        
                        const SizedBox(height: 20),
                        _sectionTitle('📁 Documents'),
                        const SizedBox(height: 12),
                        _buildDocumentsSection(),
                      ],
                    ),
                  ),
                ),

                const Divider(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      onPressed: _saving ? null : () => Navigator.pop(context),
                      child: const Text('Annuler'),
                    ),
                    const SizedBox(width: 12),
                    Flexible(
                      child: ElevatedButton.icon(
                        onPressed: _saving ? null : _save,
                        icon: _saving 
                            ? SizedBox(
                                width: mobile ? 18 : 24,
                                height: mobile ? 18 : 24,
                                child: const CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : Icon(Icons.save, size: mobile ? 18 : 24),
                        label: Text(_saving ? 'Enregistrement...' : 'Enregistrer'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF000966),
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

  bool _saving = false;
  
  void _save() async {
    if (_formKey.currentState!.validate() && !_saving) {
      setState(() => _saving = true);
      
      final posteNames = context.read<PostesProvider>().postes.map((p) => p.nom).toList();
      final depts = _departementOptions(context.read<DepartementsProvider>(), current: _dept);
      final poste = _poste.isEmpty && posteNames.isNotEmpty ? posteNames.first : _poste;
      final dept = _dept.isEmpty && depts.isNotEmpty && depts.first != '—' ? depts.first : _dept;
      
      final employeeId = widget.employe.id;
      
      // Upload photo to Firebase Storage if new photo selected
      String photoUrl = _existingPhotoUrl;
      if (_photoBytes != null) {
        final ext = _photoPath?.split('.').last ?? 'jpg';
        final uploadedUrl = await StorageService.uploadEmployeePhoto(
          employeeId: employeeId,
          bytes: _photoBytes!,
          extension: ext,
        );
        if (uploadedUrl != null) {
          photoUrl = uploadedUrl;
        }
      }
      
      // Combine existing and upload new documents
      final allDocs = [..._documents];
      for (final td in _newDocuments) {
        final docId = DateTime.now().millisecondsSinceEpoch.toString() + td.name.hashCode.toString();
        String? docUrl;
        if (td.bytes != null) {
          docUrl = await StorageService.uploadEmployeeDocument(
            employeeId: employeeId,
            documentId: docId,
            bytes: td.bytes!,
            fileName: td.name,
            extension: td.extension,
          );
        }
        allDocs.add(Document(
          id: docId,
          nom: td.name,
          path: docUrl ?? td.path ?? '',
          categorie: td.categorie,
          dateAjout: '${DateTime.now().day.toString().padLeft(2, '0')}/${DateTime.now().month.toString().padLeft(2, '0')}/${DateTime.now().year}',
          extension: td.extension,
        ));
      }
      
      widget.onSave(Employe(
        id: employeeId,
        nom: _nomCtrl.text,
        cin: _cinCtrl.text,
        telephone: _telCtrl.text,
        telephone2: _tel2Ctrl.text,
        dateNaissance: _naissanceCtrl.text,
        adresse: _adresseCtrl.text,
        email: _emailCtrl.text,
        poste: poste,
        magasin: '',
        departement: dept,
        salaireBase: double.tryParse(_salaireCtrl.text) ?? 0,
        typeContrat: _contrat,
        dateDebut: _dateDebutCtrl.text,
        finContrat: _finContratCtrl.text,
        chefDirectId: _chefId,
        cnss: _cnssCtrl.text,
        dateCnss: _dateCnssCtrl.text,
        badgeActif: _badgeActif,
        badgeExpiration: _badgeExpiryCtrl.text,
        statut: _statut,
        documents: allDocs,
        photoUrl: photoUrl,
        siteId: widget.employe.siteId,
        leaveDaysTaken: widget.employe.leaveDaysTaken,
        leaveDaysExtra: double.tryParse(_leaveExtraCtrl.text.replaceFirst(',', '.')) ?? widget.employe.leaveDaysExtra,
        ocpExcelSegment: OcpExcelSegmentCode.allCodes.contains(_ocpExcelSegment.trim())
            ? _ocpExcelSegment.trim()
            : OcpExcelSegmentCode.auto,
        ocpForceSalleControle: _ocpForceSalleControle,
        dateQuitte: widget.employe.dateQuitte,
      ));
      
      if (mounted) {
        Navigator.pop(context);
      }
    }
  }

  // HELPERS
  Widget _sectionTitle(String t) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(
      color: const Color(0xFF000966).withOpacity(0.08),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(t, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF000966))),
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

  Widget _dateField(TextEditingController ctrl, String label, {bool required = false}) {
    return StatefulBuilder(
      builder: (context, setInnerState) {
        return TextFormField(
          controller: ctrl,
          readOnly: true,
          validator: required ? (v) => v!.isEmpty ? 'Obligatoire' : null : null,
          decoration: InputDecoration(
            labelText: label,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            isDense: true,
            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Clear button - only show if not required and has value
                if (!required && ctrl.text.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.clear, size: 18, color: Colors.red),
                    onPressed: () {
                      setInnerState(() {
                        ctrl.clear();
                      });
                      setState(() {});
                    },
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    tooltip: 'Effacer',
                  ),
                const Padding(
                  padding: EdgeInsets.only(right: 12),
                  child: Icon(Icons.calendar_today, size: 18),
                ),
              ],
            ),
          ),
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: DateTime.now(),
              firstDate: DateTime(1950),
              lastDate: DateTime(2100),
            );
            if (picked != null) {
              setInnerState(() {
                ctrl.text = '${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year}';
              });
              setState(() {});
            }
          },
        );
      },
    );
  }

  List<String> _departementOptions(DepartementsProvider prov, {String? current}) {
    final set = prov.departements.map((d) => d.nom).where((n) => n.isNotEmpty).toSet();
    if (current != null && current.isNotEmpty) set.add(current);
    final list = set.toList()..sort();
    return list.isEmpty ? ['—'] : list;
  }

  Widget _dropdownPoste(List<String> posteNames) {
    final items = posteNames.isEmpty
        ? <String>['(Ajoutez des postes dans Paramètres > Postes)']
        : List<String>.from(posteNames);
    
    // Add current poste if not in list
    if (_poste.isNotEmpty && !items.contains(_poste)) {
      items.add(_poste);
    }
    
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

  Widget _dropdown(String label, String value, List<String> items, void Function(String?) onChanged) {
    final effectiveValue = value.isEmpty && items.isNotEmpty ? items.first : value;
    final effectiveItems = items.contains(effectiveValue) ? items : [...items, effectiveValue];
    
    return DropdownButtonFormField<String>(
      value: effectiveValue,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        isDense: true,
      ),
      items: effectiveItems.map((i) => DropdownMenuItem(value: i, child: Text(i))).toList(),
      onChanged: onChanged,
    );
  }

  static bool _isChefPoste(String poste) {
    final p = poste.trim().toLowerCase();
    return p.contains('chef') || p == 'shef';
  }

  Widget _dropdownOcpSegment() {
    final effective = OcpExcelSegmentCode.allCodes.contains(_ocpExcelSegment)
        ? _ocpExcelSegment
        : OcpExcelSegmentCode.auto;
    return DropdownButtonFormField<String>(
      value: effective,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Bloc OCP (tri Excel)',
        border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8))),
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        isDense: true,
      ),
      items: [
        for (final code in OcpExcelSegmentCode.allCodes)
          DropdownMenuItem<String>(
            value: code,
            child: Text(
              OcpExcelSegmentCode.labelFr(code),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
      onChanged: (v) => setState(() => _ocpExcelSegment = v ?? OcpExcelSegmentCode.auto),
    );
  }

  Widget _dropdownEmploye() {
    final chefCandidates = widget.allEmployes
        .where((e) => _isChefPoste(e.poste) && e.id != widget.employe.id)
        .toList();
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
  
  // Photo Section
  Widget _buildPhotoSection() {
    return Center(
      child: Column(
        children: [
          GestureDetector(
            onTap: _pickPhoto,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.grey.shade300, width: 2),
                image: _photoBytes != null
                    ? DecorationImage(
                        image: MemoryImage(_photoBytes!),
                        fit: BoxFit.cover,
                      )
                    : _existingPhotoUrl.isNotEmpty
                        ? DecorationImage(
                            image: NetworkImage(_existingPhotoUrl),
                            fit: BoxFit.cover,
                          )
                        : null,
              ),
              child: (_photoBytes == null && _existingPhotoUrl.isEmpty)
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.person, size: 40, color: Colors.grey.shade400),
                        const SizedBox(height: 4),
                        Text(
                          'Ajouter photo',
                          style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                        ),
                      ],
                    )
                  : null,
            ),
          ),
          if (_photoBytes != null || _existingPhotoUrl.isNotEmpty) ...[
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () => setState(() {
                _photoBytes = null;
                _photoPath = null;
                _existingPhotoUrl = '';
              }),
              icon: const Icon(Icons.delete, size: 16, color: Colors.red),
              label: const Text('Supprimer', style: TextStyle(color: Colors.red, fontSize: 12)),
            ),
          ],
        ],
      ),
    );
  }
  
  Future<void> _pickPhoto() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
      withData: true, // Important: ensures bytes are loaded
    );
    if (result != null && result.files.isNotEmpty) {
      final file = result.files.first;
      Uint8List? bytes = file.bytes;
      
      // On desktop, bytes might be null, so read from file path
      if (bytes == null && file.path != null && !kIsWeb) {
        try {
          bytes = File(file.path!).readAsBytesSync();
        } catch (e) {
          debugPrint('Error reading photo file: $e');
        }
      }
      
      if (bytes != null) {
        setState(() {
          _photoPath = file.path ?? file.name;
          _photoBytes = bytes;
        });
        debugPrint('Photo picked: ${file.name}, ${bytes.length} bytes');
      }
    }
  }
  
  // Documents Section
  Widget _buildDocumentsSection() {
    final allDocs = [..._documents.map((d) => _DocItem(doc: d)), ..._newDocuments.map((d) => _DocItem(temp: d))];
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        OutlinedButton.icon(
          onPressed: _addDocument,
          icon: const Icon(Icons.upload_file, size: 18),
          label: const Text('Ajouter un document'),
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF000966),
            side: const BorderSide(color: Color(0xFF000966)),
          ),
        ),
        const SizedBox(height: 12),
        
        if (allDocs.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.folder_open, color: Colors.grey.shade400),
                const SizedBox(width: 8),
                Text(
                  'Aucun document',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                ),
              ],
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: allDocs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final item = allDocs[index];
              final isExisting = item.doc != null;
              final name = isExisting ? item.doc!.nom : item.temp!.name;
              final cat = isExisting ? item.doc!.categorie : item.temp!.categorie;
              final ext = isExisting ? item.doc!.extension : item.temp!.extension;
              
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: cat.color.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: cat.color.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(cat.icon, color: cat.color, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            '${cat.label} • ${ext.toUpperCase()}',
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                      onPressed: () {
                        setState(() {
                          if (isExisting) {
                            _documents.remove(item.doc);
                          } else {
                            _newDocuments.remove(item.temp);
                          }
                        });
                      },
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }
  
  Future<void> _addDocument() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'doc', 'docx'],
      allowMultiple: false,
      withData: true, // Important: ensures bytes are loaded
    );

    if (result != null && result.files.isNotEmpty) {
      final file = result.files.first;
      
      // Get bytes - on desktop, bytes might be null, so read from file path
      Uint8List? bytes = file.bytes;
      if (bytes == null && file.path != null && !kIsWeb) {
        try {
          bytes = File(file.path!).readAsBytesSync();
        } catch (e) {
          debugPrint('Error reading document file: $e');
        }
      }

      final category = await showDialog<DocCategorie>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Catégorie du document'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: DocCategorie.values.map((cat) {
              return ListTile(
                leading: Icon(cat.icon, color: cat.color),
                title: Text(cat.label),
                onTap: () => Navigator.pop(ctx, cat),
              );
            }).toList(),
          ),
        ),
      );

      if (category != null && bytes != null) {
        setState(() {
          _newDocuments.add(_TempDocument(
            name: file.name,
            path: file.path,
            bytes: bytes,
            extension: file.extension ?? '',
            categorie: category,
          ));
        });
        debugPrint('Document added: ${file.name}, ${bytes.length} bytes');
      }
    }
  }
}

class _TempDocument {
  final String name;
  final String? path;
  final Uint8List? bytes;
  final String extension;
  final DocCategorie categorie;
  
  _TempDocument({
    required this.name,
    this.path,
    this.bytes,
    required this.extension,
    required this.categorie,
  });
}

class _DocItem {
  final Document? doc;
  final _TempDocument? temp;
  
  _DocItem({this.doc, this.temp});
}
