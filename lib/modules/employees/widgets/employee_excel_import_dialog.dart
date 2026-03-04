import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../models/employe_model.dart';
import '../models/equipe_model.dart';
import '../data/excel_import.dart';

/// Dialog to import employees from an Excel file (.xlsx).
/// First row = headers (Nom, CIN, Téléphone, Poste, Magasin, etc.).
/// Option to assign all imported employees to an existing équipe (شاف).
class EmployeeExcelImportDialog extends StatefulWidget {
  final List<Equipe> equipes;
  final Future<void> Function(Employe) onAddEmploye;
  final Future<void> Function(Equipe) onUpdateEquipe;

  const EmployeeExcelImportDialog({
    super.key,
    required this.equipes,
    required this.onAddEmploye,
    required this.onUpdateEquipe,
  });

  @override
  State<EmployeeExcelImportDialog> createState() =>
      _EmployeeExcelImportDialogState();
}

class _EmployeeExcelImportDialogState extends State<EmployeeExcelImportDialog> {
  List<Employe> _preview = [];
  List<String> _parseErrors = [];
  String? _fileName;
  String? _selectedEquipeId;
  bool _importing = false;
  String? _importError;

  Future<void> _pickAndParse() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'xls'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    final file = result.files.single;
    List<int>? bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) {
      if (file.path != null) {
        try {
          final f = File(file.path!);
          if (await f.exists()) bytes = await f.readAsBytes();
        } catch (_) {}
      }
    }
    if (bytes == null || bytes.isEmpty) {
      if (mounted) {
        setState(() {
          _parseErrors = ['Impossible de lire le fichier.'];
          _preview = [];
          _fileName = null;
        });
      }
      return;
    }

    final parsed = parseExcelToEmployes(bytes);
    if (mounted) {
      setState(() {
        _fileName = file.name;
        _preview = parsed.employes;
        _parseErrors = parsed.errors;
        _importError = null;
      });
    }
  }

  Future<void> _doImport() async {
    if (_preview.isEmpty) return;
    setState(() {
      _importing = true;
      _importError = null;
    });

    final ids = <String>[];
    try {
      for (final e in _preview) {
        await widget.onAddEmploye(e);
        ids.add(e.id);
      }
      if (_selectedEquipeId != null && ids.isNotEmpty) {
        Equipe? eq;
        for (final x in widget.equipes) {
          if (x.id == _selectedEquipeId) {
            eq = x;
            break;
          }
        }
        if (eq != null) {
          final updated = eq.copyWith(
            membreIds: [...eq.membreIds, ...ids],
          );
          await widget.onUpdateEquipe(updated);
        }
      }
      if (mounted) {
        setState(() => _importing = false);
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _importing = false;
          _importError = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 700,
        constraints: const BoxConstraints(maxHeight: 560),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.upload_file, color: Theme.of(context).primaryColor, size: 28),
                const SizedBox(width: 12),
                const Text(
                  'Importer des employés (Excel)',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Feuille 1 : première ligne = en-têtes (Nom, CIN, Téléphone, Poste, Magasin, Département, Salaire, Type contrat, Date début, CNSS, Date CNSS, Statut…).',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            const SizedBox(height: 20),

            OutlinedButton.icon(
              onPressed: _importing ? null : _pickAndParse,
              icon: const Icon(Icons.folder_open, size: 20),
              label: Text(_fileName ?? 'Choisir un fichier .xlsx'),
            ),

            if (_parseErrors.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _parseErrors.join(' '),
                  style: TextStyle(fontSize: 12, color: Colors.orange[800]),
                ),
              ),

            if (_preview.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                'Aperçu (${_preview.length} employé(s))',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              const SizedBox(height: 8),
              Flexible(
                child: SingleChildScrollView(
                  scrollDirection: Axis.vertical,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      headingRowColor: WidgetStateProperty.all(Colors.grey.shade100),
                      columns: const [
                        DataColumn(label: Text('Nom', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('CIN', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Poste', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Magasin', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Statut', style: TextStyle(fontWeight: FontWeight.bold))),
                      ],
                      rows: _preview.take(15).map((e) {
                        return DataRow(
                          cells: [
                            DataCell(Text(e.nom)),
                            DataCell(Text(e.cin)),
                            DataCell(Text(e.poste)),
                            DataCell(Text(e.magasin)),
                            DataCell(Text(e.statut.label)),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (widget.equipes.isNotEmpty) ...[
                const Text('Attribuer tous à l\'équipe (optionnel)',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  value: _selectedEquipeId,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  hint: const Text('Aucune'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Aucune')),
                    ...widget.equipes.map((eq) => DropdownMenuItem(
                          value: eq.id,
                          child: Text('${eq.nom} (${eq.magasin})'),
                        )),
                  ],
                  onChanged: (v) => setState(() => _selectedEquipeId = v),
                ),
                const SizedBox(height: 16),
              ],
              if (_importError != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    _importError!,
                    style: TextStyle(fontSize: 12, color: Colors.red[700]),
                  ),
                ),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _importing ? null : () => Navigator.of(context).pop(),
                    child: const Text('Annuler'),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    onPressed: _importing || _preview.isEmpty ? null : _doImport,
                    icon: _importing
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.upload),
                    label: Text(_importing ? 'Import…' : 'Importer ${_preview.length} employé(s)'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
