import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../../../core/auth/auth_provider.dart';
import '../../../core/site/site_model.dart';
import '../../../core/site/site_provider.dart';
import '../../../core/utils/responsive.dart';
import '../models/employe_model.dart';
import '../models/document_model.dart';
import '../employees_provider.dart';
import '../postes_provider.dart';
import '../services/storage_service.dart';

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
  String _siteId = SiteId.jadida;
  EmployeStatut _statut = EmployeStatut.enService;
  bool _siteIdInitialized = false;
  
  // Photo de profil
  String? _photoPath;
  Uint8List? _photoBytes;
  
  // Documents
  final List<_TempDocument> _tempDocuments = [];

  static const _contrats = ['CDI', 'CDD', 'Anapec'];

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final site = context.watch<SiteProvider>();
    if (!_siteIdInitialized) {
      _siteIdInitialized = true;
      final allowed = auth.currentUser?.allowedSiteIds;
      if (allowed != null && allowed.isNotEmpty && allowed.first != SiteId.all) {
        _siteId = allowed.first;
      } else {
        _siteId = site.selectedSiteId ?? SiteId.jadida;
        if (_siteId == SiteId.all) _siteId = SiteId.jadida;
      }
    }
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
                      _row2(
                        _dropdownPoste(posteNames),
                        _dropdown('Magasin *', _magasin, magasins.isEmpty ? ['—'] : magasins, (v) => setState(() => _magasin = v ?? '')),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: _siteId,
                        decoration: InputDecoration(
                          labelText: 'Zone (الموقع) *',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          isDense: true,
                        ),
                        items: [
                          DropdownMenuItem(value: SiteId.jadida, child: Text(SiteId.labelFr(SiteId.jadida))),
                          DropdownMenuItem(value: SiteId.safi, child: Text(SiteId.labelFr(SiteId.safi))),
                        ],
                        onChanged: (v) => setState(() => _siteId = v ?? SiteId.jadida),
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
                        _field(_cnssCtrl, 'Numéro CNSS'),
                        _dateField(_dateCnssCtrl, 'Date inscription CNSS'),
                      ),
                      
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

  bool _saving = false;
  
  void _save() async {
    if (_formKey.currentState!.validate() && !_saving) {
      setState(() => _saving = true);
      
      debugPrint('EmployeeFormDialog: Starting save...');
      debugPrint('EmployeeFormDialog: Photo bytes: ${_photoBytes?.length ?? 0}');
      debugPrint('EmployeeFormDialog: Photo path: $_photoPath');
      debugPrint('EmployeeFormDialog: Documents count: ${_tempDocuments.length}');
      
      final posteNames = context.read<PostesProvider>().postes.map((p) => p.nom).toList();
      final empProv = context.read<EmployeesProvider>();
      final magasins = _uniqueMagasins(empProv);
      final depts = _uniqueDepartements(empProv);
      final poste = _poste.isEmpty && posteNames.isNotEmpty ? posteNames.first : _poste;
      final magasin = _magasin.isEmpty && magasins.isNotEmpty && magasins.first != '—' ? magasins.first : _magasin;
      final dept = _dept.isEmpty && depts.isNotEmpty && depts.first != '—' ? depts.first : _dept;
      
      final employeeId = DateTime.now().millisecondsSinceEpoch.toString();
      debugPrint('EmployeeFormDialog: Employee ID: $employeeId');
      
      // Upload photo to Firebase Storage
      String? photoUrl;
      if (_photoBytes != null) {
        final ext = _photoPath?.split('.').last ?? 'jpg';
        debugPrint('EmployeeFormDialog: Uploading photo with extension: $ext');
        photoUrl = await StorageService.uploadEmployeePhoto(
          employeeId: employeeId,
          bytes: _photoBytes!,
          extension: ext,
        );
        debugPrint('EmployeeFormDialog: Photo URL received: $photoUrl');
      } else {
        debugPrint('EmployeeFormDialog: No photo to upload');
      }
      
      // Upload documents to Firebase Storage
      final documents = <Document>[];
      for (final td in _tempDocuments) {
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
        documents.add(Document(
          id: docId,
          nom: td.name,
          path: docUrl ?? td.path ?? '',
          categorie: td.categorie,
          dateAjout: '${DateTime.now().day.toString().padLeft(2, '0')}/${DateTime.now().month.toString().padLeft(2, '0')}/${DateTime.now().year}',
          extension: td.extension,
        ));
      }
      
      final newEmployee = Employe(
        id: employeeId,
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
        documents: documents,
        photoUrl: photoUrl ?? '',
        siteId: _siteId,
      );
      
      debugPrint('EmployeeFormDialog: Saving employee with photoUrl: ${newEmployee.photoUrl}');
      widget.onSave(newEmployee);
      
      if (mounted) {
        Navigator.pop(context);
      }
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
  
  // ========== Photo de profil ==========
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
                    : null,
              ),
              child: _photoBytes == null
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
          if (_photoBytes != null) ...[
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () => setState(() {
                _photoBytes = null;
                _photoPath = null;
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
  
  // ========== Documents Section ==========
  Widget _buildDocumentsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Add document button
        OutlinedButton.icon(
          onPressed: _addDocument,
          icon: const Icon(Icons.upload_file, size: 18),
          label: const Text('Ajouter un document'),
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF1565C0),
            side: const BorderSide(color: Color(0xFF1565C0)),
          ),
        ),
        const SizedBox(height: 12),
        
        // Document list
        if (_tempDocuments.isEmpty)
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
                  'Aucun document ajouté',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                ),
              ],
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _tempDocuments.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final doc = _tempDocuments[index];
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: doc.categorie.color.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: doc.categorie.color.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(doc.categorie.icon, color: doc.categorie.color, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            doc.name,
                            style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            '${doc.categorie.label} • ${doc.extension.toUpperCase()}',
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                      onPressed: () => setState(() => _tempDocuments.removeAt(index)),
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

      // Show dialog to select category
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
          _tempDocuments.add(_TempDocument(
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

// Temporary document class for form
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