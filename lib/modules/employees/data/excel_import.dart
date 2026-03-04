import 'package:excel/excel.dart';
import '../models/employe_model.dart';

/// Column header names (normalized: trim, lowercase) expected in the first row.
/// Optional columns can be missing; required: at least Nom or CIN to consider a row valid.
const Map<String, String> _headerAliases = {
  'nom': 'nom',
  'cin': 'cin',
  'telephone': 'telephone',
  'téléphone': 'telephone',
  'tel': 'telephone',
  'telephone 2': 'telephone2',
  'téléphone 2': 'telephone2',
  'date naissance': 'dateNaissance',
  'adresse': 'adresse',
  'email': 'email',
  'poste': 'poste',
  'magasin': 'magasin',
  'département': 'departement',
  'departement': 'departement',
  'salaire': 'salaireBase',
  'salaire base': 'salaireBase',
  'type contrat': 'typeContrat',
  'date début': 'dateDebut',
  'date debut': 'dateDebut',
  'fin contrat': 'finContrat',
  'cnss': 'cnss',
  'date cnss': 'dateCnss',
  'statut': 'statut',
  'équipe': 'equipe',
  'equipe': 'equipe',
  'chef direct': 'chefDirect',
};

String _cellString(dynamic cell) {
  if (cell == null) return '';
  final Data? data = cell is Data ? cell : null;
  final CellValue? v = data?.value;
  if (v == null) return '';
  return switch (v) {
    TextCellValue() => v.value.text ?? '',
    IntCellValue() => v.value.toString(),
    DoubleCellValue() => v.value.toString(),
    BoolCellValue() => v.value.toString(),
    DateCellValue() => '${v.day.toString().padLeft(2, '0')}/${v.month.toString().padLeft(2, '0')}/${v.year}',
    DateTimeCellValue() => v.asDateTimeUtc().toIso8601String().split('T').first,
    TimeCellValue() => v.toString(),
    FormulaCellValue() => v.formula,
  };
}

EmployeStatut _statutFromExcel(String? v) {
  if (v == null || v.isEmpty) return EmployeStatut.enService;
  final lower = v.trim().toLowerCase();
  if (lower.contains('quitt') || lower == 'quitte') return EmployeStatut.quitte;
  if (lower.contains('congé') || lower.contains('conge')) return EmployeStatut.enConge;
  if (lower.contains('maladie')) return EmployeStatut.enMaladie;
  return EmployeStatut.enService;
}

/// Result of parsing an Excel file: list of employees and optional errors per row.
class ExcelImportResult {
  ExcelImportResult({required this.employes, this.errors = const []});
  final List<Employe> employes;
  final List<String> errors;
}

/// Parses Excel bytes (first sheet). First row = headers (case-insensitive).
/// Assigns generated ids; optional column "Équipe" is read but not used to create équipes here
/// (assign to équipe is done in the dialog).
ExcelImportResult parseExcelToEmployes(List<int> bytes) {
  final employes = <Employe>[];
  final errors = <String>[];

  try {
    final excel = Excel.decodeBytes(bytes);
    final tables = excel.tables;
    if (tables.isEmpty) {
      errors.add('Fichier Excel sans feuille.');
      return ExcelImportResult(employes: employes, errors: errors);
    }

    final sheet = tables.values.first;
    final rows = sheet.rows;
    if (rows.isEmpty) {
      errors.add('Feuille vide.');
      return ExcelImportResult(employes: employes, errors: errors);
    }

    // Build column index by normalized header
    final headerRow = rows.first;
    final colMap = <String, int>{};
    for (var c = 0; c < headerRow.length; c++) {
      final raw = _cellString(headerRow[c]).trim();
      final key = raw.toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
      final canonical = _headerAliases[key];
      if (canonical != null && !colMap.containsKey(canonical)) {
        colMap[canonical] = c;
      }
    }

    int col(String name) => colMap[name] ?? -1;
    String cell(List<Data?> row, String name) {
      final c = col(name);
      if (c < 0 || c >= row.length) return '';
      return _cellString(row[c]).trim();
    }

    final baseId = DateTime.now().millisecondsSinceEpoch;

    for (var r = 1; r < rows.length; r++) {
      final row = rows[r];
      if (row.isEmpty) continue;

      final nom = cell(row, 'nom');
      final cin = cell(row, 'cin');
      if (nom.isEmpty && cin.isEmpty) continue;

      double salaireBase = 0;
      final sc = col('salaireBase');
      if (sc >= 0 && sc < row.length) {
        final s = _cellString(row[sc]).replaceAll(RegExp(r'[\s,]'), '').replaceAll(',', '.');
        if (s.isNotEmpty) salaireBase = double.tryParse(s) ?? 0;
      }

      final e = Employe(
        id: 'emp_${baseId}_$r',
        nom: nom.isEmpty ? '—' : nom,
        cin: cin,
        telephone: cell(row, 'telephone'),
        telephone2: cell(row, 'telephone2'),
        dateNaissance: cell(row, 'dateNaissance'),
        adresse: cell(row, 'adresse'),
        email: cell(row, 'email'),
        poste: cell(row, 'poste'),
        magasin: cell(row, 'magasin'),
        departement: cell(row, 'departement'),
        salaireBase: salaireBase,
        typeContrat: cell(row, 'typeContrat').isEmpty ? 'CDI' : cell(row, 'typeContrat'),
        dateDebut: cell(row, 'dateDebut'),
        finContrat: cell(row, 'finContrat'),
        chefDirectId: '', // not resolved from Excel by id
        cnss: cell(row, 'cnss'),
        dateCnss: cell(row, 'dateCnss'),
        statut: _statutFromExcel(cell(row, 'statut')),
        documents: [],
      );
      employes.add(e);
    }
  } catch (e) {
    errors.add('Erreur lecture Excel: $e');
  }

  return ExcelImportResult(employes: employes, errors: errors);
}
