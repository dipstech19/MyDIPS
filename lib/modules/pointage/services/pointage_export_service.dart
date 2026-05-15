import 'dart:convert';
import 'dart:io';
import 'dart:math' show max;
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:excel/excel.dart' as excel;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import '../models/pointage_model.dart';
import '../models/absence_reason_config.dart';
import '../../employees/models/employe_model.dart';
import '../../overtime/models/overtime_model.dart';
import '../data/daily_snapshot_repository.dart';

class PointageExportRow {
  final String employeId;
  final String employeCin;
  final String employeNom;
  final String poste;
  final String equipeName;
  final String? equipeId;
  /// Équipe | Groupe | Distribution | Hors équipe
  final String orgTypeLabel;
  final int daysWorked;
  /// Nombre total de shifts planifiés sur la période (hors repos).
  final int plannedShifts;
  final int daysAbsent;
  final double totalHours;
  final double overtimeHours;
  /// Salaire net saisi dans la fiche employe.
  final double salaireNet;
  /// Salaire calcule sur la periode (pro-rata jours payes).
  final double salairePeriode;
  final Map<DateTime, String> hoursByDay;
  /// Code de statut par jour pour le formatage Excel.
  /// present | absent | paid_absence | formation | rest
  final Map<DateTime, String> dayStatusByDay;
  /// لكل يوم غياب، معرف السبب (للتلوين في Excel).
  final Map<DateTime, String?> absenceReasonIdByDay;
  /// Code [OcpExcelSegmentCode] copié depuis la fiche employé ; vide = déduction auto.
  final String ocpExcelSegment;
  final bool ocpForceSalleControle;

  const PointageExportRow({
    required this.employeId,
    required this.employeCin,
    required this.employeNom,
    this.poste = 'Opérateur',
    required this.equipeName,
    this.equipeId,
    this.orgTypeLabel = 'Équipe',
    required this.daysWorked,
    required this.plannedShifts,
    required this.daysAbsent,
    required this.totalHours,
    required this.overtimeHours,
    required this.salaireNet,
    required this.salairePeriode,
    required this.hoursByDay,
    this.dayStatusByDay = const {},
    this.absenceReasonIdByDay = const {},
    this.ocpExcelSegment = '',
    this.ocpForceSalleControle = false,
  });
}

class PointageExportService {
  static final _dateFormat = DateFormat('dd/MM/yyyy');
  static final _timeFormat = DateFormat('HH:mm');

  /// Particules de patronyme (Maghreb) : rattachées au mot suivant dans la colonne Nom.
  static bool _isOcpFamilyNamePrefix(String token) {
    final t = _foldAccentsForMatch(token.trim().toLowerCase());
    const prefixes = <String>{
      'el',
      'ben',
      'bent',
      'bin',
      'bint',
      'ibn',
      'ait',
      'ayt',
      'ould',
      'oul',
    };
    return prefixes.contains(t);
  }

  /// Sépare « Nom » / « Prénom » pour l’export OCP (évite « EL » seul quand le nom est « EL BATTACH », etc.).
  static ({String nom, String prenom}) splitNomPrenomForExcel(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return (nom: '', prenom: '');
    final parts = s.split(RegExp(r'\s+'));
    if (parts.length < 2) return (nom: s, prenom: '');
    if (parts.length == 2) {
      if (_isOcpFamilyNamePrefix(parts[0])) {
        // Ex. « EL MOSTAFA » : tout reste dans Nom.
        return (nom: s, prenom: '');
      }
      return (nom: parts.first, prenom: parts.sublist(1).join(' '));
    }
    // 3+ mots : si le premier est une particule, les deux premiers tokens = nom de famille.
    if (_isOcpFamilyNamePrefix(parts[0])) {
      return (
        nom: '${parts[0]} ${parts[1]}',
        prenom: parts.sublist(2).join(' '),
      );
    }
    return (nom: parts.first, prenom: parts.sublist(1).join(' '));
  }

  /// Largeur colonne Excel (unités approx. caractères) selon le texte le plus long.
  static double ocpExcelColumnWidthForText(
    String text, {
    double min = 10,
    double max = 52,
  }) {
    final len = text.trim().length;
    if (len == 0) return min;
    return (len * 1.12 + 2).clamp(min, max);
  }

  /// Gabarit feuille OCP (Excel) : cellule avec « 1 » ou vide — pas de G/F/A.
  /// Présence, congé et formation → « 1 » ; absence / repos / sans travail → vide.
  static String ocpExcelDayMarker(String status, String fallback) {
    if (status == 'present' || status == 'leave' || status == 'formation') {
      return '1';
    }
    if (status == 'paid_absence' ||
        status == 'absent' ||
        status == 'rest' ||
        status == 'pending_exit') {
      return '';
    }
    if (status.isEmpty) {
      final t = fallback.trim();
      final u = t.toUpperCase();
      if (t == '1' ||
          u == 'P' ||
          u == 'G' ||
          u == 'F' ||
          t == '+' ||
          u == 'X') {
        return '1';
      }
      return '';
    }
    return '';
  }

  /// Normalisation sans accents pour matcher postes / équipes (P1/P2 OCP, shiftCodeForRow).
  static String _foldAccentsForMatch(String s) {
    return s
        .replaceAll('à', 'a')
        .replaceAll('á', 'a')
        .replaceAll('â', 'a')
        .replaceAll('ä', 'a')
        .replaceAll('è', 'e')
        .replaceAll('é', 'e')
        .replaceAll('ê', 'e')
        .replaceAll('ë', 'e')
        .replaceAll('ì', 'i')
        .replaceAll('í', 'i')
        .replaceAll('î', 'i')
        .replaceAll('ï', 'i')
        .replaceAll('ò', 'o')
        .replaceAll('ó', 'o')
        .replaceAll('ô', 'o')
        .replaceAll('ö', 'o')
        .replaceAll('ù', 'u')
        .replaceAll('ú', 'u')
        .replaceAll('û', 'u')
        .replaceAll('ü', 'u')
        .replaceAll('ç', 'c')
        .replaceAll('ñ', 'n');
  }

  /// عدد ساعات العمل المعتمدة لكل يوم (لاحتساب Total heures في Excel).
  static const double hoursPerDay = 8.0;

  // ═══════════════════════════════════════════════════════════════════════
  // PDF
  // ═══════════════════════════════════════════════════════════════════════

  static Future<Uint8List> buildDailyReportPdf({
    required DateTime date,
    required String title,
    /// Présents avec sortie confirmée
    required List<String> presentNames,
    /// Présents sans sortie confirmée
    List<String>? presentNoDepartureNames,
    required List<String> absentNames,
    List<String?>? absentReasons,
    List<AbsenceReasonConfig>? reasonConfigs,
    required String signatureLabel,
    String? personName,
    String? equipeName,
    /// Nom du chef d'équipe (affiché à côté du nom d'équipe : « Équipe — Chef »).
    String? chefName,
  }) async {
    final logo = await _loadLogo();
    final pdf = pw.Document();
    final now = DateTime.now();
    final cleanEquipeName = (equipeName ?? '').trim();
    final cleanChefName = (chefName ?? '').trim();
    final cleanPersonName = (personName ?? '').trim();
    final responsibleName =
        cleanChefName.isNotEmpty ? cleanChefName : cleanPersonName;
    final signaturePersonName = signatureLabel.toLowerCase().contains('chef')
        ? responsibleName
        : cleanPersonName;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => [
          if (logo != null) _buildHeader(logo),
          if (logo != null) pw.SizedBox(height: 16),
          pw.Text(
            title,
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
          ),
          if (cleanEquipeName.isNotEmpty)
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 4),
              child: pw.Text(
                cleanEquipeName,
                style: const pw.TextStyle(fontSize: 12),
              ),
            ),
          if (responsibleName.isNotEmpty)
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 2),
              child: pw.Text(
                'Responsable: $responsibleName',
                style: const pw.TextStyle(fontSize: 11),
              ),
            ),
          pw.SizedBox(height: 8),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Date: ${_dateFormat.format(date)}',
                  style: const pw.TextStyle(fontSize: 11)),
              pw.Text('Heure: ${_timeFormat.format(now)}',
                  style: const pw.TextStyle(fontSize: 11)),
            ],
          ),
          pw.SizedBox(height: 20),

          pw.Text(
            'Liste de présence',
            style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          _buildPresenceTableWithDeparture(
            presentWithDepartureNames: presentNames,
            presentNoDepartureNames: presentNoDepartureNames ?? const [],
            absentNames: absentNames,
            absentReasons: absentReasons ?? List.filled(absentNames.length, null),
            reasonConfigs: reasonConfigs,
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            'Présents (sortie OK): ${presentNames.length}    Présents (sans sortie): ${(presentNoDepartureNames ?? const []).length}    Absents: ${absentNames.length}',
            style: const pw.TextStyle(fontSize: 10),
          ),

          pw.SizedBox(height: 40),
          pw.Divider(thickness: 0.5),
          pw.SizedBox(height: 16),
          pw.Text(
            'Signature $signatureLabel${signaturePersonName.isNotEmpty ? ' ($signaturePersonName)' : ''}:',
            style: const pw.TextStyle(fontSize: 11),
          ),
          pw.SizedBox(height: 30),
          pw.Container(
            width: 200,
            decoration: const pw.BoxDecoration(
                border: pw.Border(bottom: pw.BorderSide(width: 0.5))),
            child: pw.SizedBox(height: 1),
          ),
        ],
      ),
    );

    return pdf.save();
  }

  /// Table: Présent + Sortie, Présent sans sortie, Absent + raison.
  static pw.Widget _buildPresenceTableWithDeparture({
    required List<String> presentWithDepartureNames,
    required List<String> presentNoDepartureNames,
    required List<String> absentNames,
    required List<String?> absentReasons,
    List<AbsenceReasonConfig>? reasonConfigs,
  }) {
    final rows = <pw.TableRow>[];
    if (absentReasons.length != absentNames.length) {
      absentReasons = List.filled(absentNames.length, null);
    }

    rows.add(
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: PdfColors.grey300),
        children: [
          _presenceCell('#', header: true, align: pw.TextAlign.center),
          _presenceCell('Nom', header: true),
          _presenceCell('Entré.', header: true, align: pw.TextAlign.center, maxLines: 1),
          _presenceCell('Sortie', header: true, align: pw.TextAlign.center, maxLines: 1),
          _presenceCell('Abs.', header: true, align: pw.TextAlign.center, maxLines: 1),
          _presenceCell('Raison absence', header: true, maxLines: 2),
        ],
      ),
    );

    int index = 1;
    for (final name in presentWithDepartureNames) {
      rows.add(
        pw.TableRow(
          children: [
            _presenceCell('$index', align: pw.TextAlign.center),
            _presenceCell(name),
            _presenceCell('P1', align: pw.TextAlign.center),
            _presenceCell('P2', align: pw.TextAlign.center),
            _presenceCell('', align: pw.TextAlign.center),
            _presenceCell(''),
          ],
        ),
      );
      index++;
    }
    for (final name in presentNoDepartureNames) {
      rows.add(
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.orange100),
          children: [
            _presenceCell('$index', align: pw.TextAlign.center),
            _presenceCell(name),
            _presenceCell('P1', align: pw.TextAlign.center),
            _presenceCell('', align: pw.TextAlign.center),
            _presenceCell('', align: pw.TextAlign.center),
            _presenceCell('Sortie non confirmée'),
          ],
        ),
      );
      index++;
    }
    for (int i = 0; i < absentNames.length; i++) {
      final reason = i < absentReasons.length ? getAbsenceReasonLabel(absentReasons[i], reasonConfigs) : '';
      rows.add(
        pw.TableRow(
          children: [
            _presenceCell('$index', align: pw.TextAlign.center),
            _presenceCell(absentNames[i]),
            _presenceCell('', align: pw.TextAlign.center),
            _presenceCell('', align: pw.TextAlign.center),
            _presenceCell('X', align: pw.TextAlign.center),
            _presenceCell(reason),
          ],
        ),
      );
      index++;
    }
    if (presentWithDepartureNames.isEmpty && presentNoDepartureNames.isEmpty && absentNames.isEmpty) {
      rows.add(
        pw.TableRow(
          children: [
            _presenceCell('-', align: pw.TextAlign.center),
            _presenceCell('Aucune donnée'),
            _presenceCell('', align: pw.TextAlign.center),
            _presenceCell('', align: pw.TextAlign.center),
            _presenceCell('', align: pw.TextAlign.center),
            _presenceCell(''),
          ],
        ),
      );
    }

    return pw.Table(
      border: pw.TableBorder.all(width: 0.5, color: PdfColors.grey600),
      columnWidths: {
        0: const pw.FixedColumnWidth(20),
        1: const pw.FlexColumnWidth(3.2),
        2: const pw.FixedColumnWidth(34), // Prés.
        3: const pw.FixedColumnWidth(38), // Sortie
        4: const pw.FixedColumnWidth(34), // Abs.
        5: const pw.FlexColumnWidth(3.0), // Raison
      },
      defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
      children: rows,
    );
  }

  static pw.Widget _presenceCell(
    String text, {
    bool header = false,
    pw.TextAlign align = pw.TextAlign.left,
    int? maxLines,
  }) {
    return pw.Padding(
      padding: pw.EdgeInsets.symmetric(horizontal: header ? 5 : 6, vertical: header ? 5 : 4),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: header ? 9 : 10,
          fontWeight: header ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
        textAlign: align,
        maxLines: maxLines,
        overflow: pw.TextOverflow.clip,
      ),
    );
  }

  static Future<pw.ImageProvider?> _loadLogo() async {
    try {
      final data = await rootBundle.load('assets/images/logo.png');
      return pw.MemoryImage(data.buffer.asUint8List());
    } catch (_) {
      return null;
    }
  }

  /// ترويسة بسيطة تحتوي على اسم الشركة واللوغو.
  static pw.Widget _buildHeader(pw.ImageProvider logo) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Container(
              width: 60,
              height: 50,
              child: pw.Image(logo, fit: pw.BoxFit.contain),
            ),
            pw.SizedBox(width: 12),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'DIGITALIZATION, INNOVATION',
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blue800,
                  ),
                ),
                pw.Text(
                  '& PROCESS SIMULATION',
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blue800,
                  ),
                ),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 6),
        pw.Divider(color: PdfColors.blue800, thickness: 1),
      ],
    );
  }

  /// صفحة واحدة في تقرير متعدد (للسائق: équipe + حاضرون/غائبون).
  static Future<Uint8List> buildDailyReportPdfMulti({
    required DateTime date,
    required String title,
    required String signatureLabel,
    String? personName,
    required List<({String equipeName, String? chefName, List<String> presentNames, List<String> presentNoDepartureNames, List<String> absentNames, List<String?> absentReasons})> equipes,
  }) async {
    if (equipes.isEmpty) return Uint8List(0);
    final logo = await _loadLogo();
    final now = DateTime.now();
    final pdf = pw.Document();

    for (final eq in equipes) {
      final cleanEquipeName = eq.equipeName.trim();
      final cleanChefName = (eq.chefName ?? '').trim();
      final cleanPersonName = (personName ?? '').trim();
      final responsibleName =
          cleanChefName.isNotEmpty ? cleanChefName : cleanPersonName;
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (context) => [
            if (logo != null) _buildHeader(logo),
            if (logo != null) pw.SizedBox(height: 16),
            pw.Text(
              title,
              style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
            ),
            if (cleanEquipeName.isNotEmpty)
              pw.Padding(
                padding: const pw.EdgeInsets.only(top: 4),
                child: pw.Text(cleanEquipeName, style: const pw.TextStyle(fontSize: 12)),
              ),
            if (responsibleName.isNotEmpty)
              pw.Padding(
                padding: const pw.EdgeInsets.only(top: 2),
                child: pw.Text(
                  'Responsable: $responsibleName',
                  style: const pw.TextStyle(fontSize: 11),
                ),
              ),
            pw.SizedBox(height: 8),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Date: ${_dateFormat.format(date)}', style: const pw.TextStyle(fontSize: 11)),
                pw.Text('Heure: ${_timeFormat.format(now)}', style: const pw.TextStyle(fontSize: 11)),
              ],
            ),
            pw.SizedBox(height: 20),
            pw.Text(
              'Liste de présence',
              style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 8),
            _buildPresenceTableWithDeparture(
              presentWithDepartureNames: eq.presentNames,
              presentNoDepartureNames: eq.presentNoDepartureNames,
              absentNames: eq.absentNames,
              absentReasons: eq.absentReasons,
            ),
            pw.SizedBox(height: 8),
            pw.Text(
              'Présents: ${eq.presentNames.length + eq.presentNoDepartureNames.length}    Absents: ${eq.absentNames.length}',
              style: const pw.TextStyle(fontSize: 10),
            ),
            pw.SizedBox(height: 40),
            pw.Divider(thickness: 0.5),
            pw.SizedBox(height: 16),
            pw.Text(
              'Signature $signatureLabel${personName != null && personName.isNotEmpty ? ' ($personName)' : ''}:',
              style: const pw.TextStyle(fontSize: 11),
            ),
            pw.SizedBox(height: 30),
            pw.Container(
              width: 200,
              decoration: const pw.BoxDecoration(
                border: pw.Border(bottom: pw.BorderSide(width: 0.5)),
              ),
              child: pw.SizedBox(height: 1),
            ),
          ],
        ),
      );
    }

    return pdf.save();
  }

  /// حفظ PDF واحد يجمع كل الـ équipes (للسائق): صفحة لكل équipe.
  static Future<String> shareDailyReportPdfForDriver({
    required DateTime date,
    required String title,
    required String signatureLabel,
    String? personName,
    required List<({String equipeName, String? chefName, List<String> presentNames, List<String> presentNoDepartureNames, List<String> absentNames, List<String?> absentReasons})> equipes,
  }) async {
    final bytes = await buildDailyReportPdfMulti(
      date: date,
      title: title,
      signatureLabel: signatureLabel,
      personName: personName,
      equipes: equipes,
    );
    final fileName =
        'rapport_pointage_chauffeur_${_dateFormat.format(date).replaceAll('/', '-')}.pdf';
    return _saveAndOpen(bytes, fileName);
  }

  /// حفظ PDF على القرص ثم فتحه بالتطبيق الافتراضي.
  static Future<String> shareDailyReportPdf({
    required DateTime date,
    required String title,
    required List<String> presentNames,
    List<String>? presentNoDepartureNames,
    required List<String> absentNames,
    List<String?>? absentReasons,
    List<AbsenceReasonConfig>? reasonConfigs,
    required String signatureLabel,
    String? personName,
    String? equipeName,
    String? chefName,
  }) async {
    final bytes = await buildDailyReportPdf(
      date: date,
      title: title,
      presentNames: presentNames,
      presentNoDepartureNames: presentNoDepartureNames,
      absentNames: absentNames,
      absentReasons: absentReasons,
      reasonConfigs: reasonConfigs,
      signatureLabel: signatureLabel,
      personName: personName,
      equipeName: equipeName,
      chefName: chefName,
    );
    final nameParts = <String>[
      if (equipeName != null && equipeName.trim().isNotEmpty) equipeName.trim(),
      if (chefName != null && chefName.trim().isNotEmpty) chefName.trim(),
    ];
    final rawSafe = nameParts.isEmpty ? 'rapport' : nameParts.join('_');
    final safeName = rawSafe
        .replaceAll(RegExp(r'[^\w\s-]'), '')
        .replaceAll(RegExp(r'\s+'), '_');
    final fileName =
        'rapport_${safeName}_${_dateFormat.format(date).replaceAll('/', '-')}.pdf';

    return _saveAndOpen(bytes, fileName);
  }

  // ═══════════════════════════════════════════════════════════════════════
  // Excel — ورقة (sheet) منفصلة لكل فريق
  // ═══════════════════════════════════════════════════════════════════════

  static Future<Uint8List> buildOcpPointageExcel({
    required DateTime startDate,
    required DateTime endDate,
    required List<PointageExportRow> rows,
    List<AbsenceReasonConfig>? reasonConfigs,
    bool singleSheet = false,
    String singleSheetName = 'Société',
    bool includeEquipeColumnInSingleSheet = true,
  }) async {
    final start = _dayKey(startDate);
    final end = _dayKey(endDate);
    final days = <DateTime>[];
    final totalDays = end.difference(start).inDays + 1;
    for (int i = 0; i < totalDays; i++) {
      days.add(start.add(Duration(days: i)));
    }

    String normalizePoste(String poste) => poste.trim().toLowerCase();

    bool isChefPoste(String poste) {
      final p = normalizePoste(poste);
      return p.contains("chef d'équipe") ||
          p.contains("chef d'equipe") ||
          p.contains("chef d equipe") ||
          p == 'chef equipe' ||
          p.contains('chef atelier') ||
          p.contains("chef d'atelier");
    }

    /// Chef d'équipe uniquement (pas chef d'atelier) — tri P1/P2 OCP.
    bool isChefEquipePosteOnly(String poste) {
      final p = normalizePoste(poste);
      return p.contains("chef d'équipe") ||
          p.contains("chef d'equipe") ||
          p.contains("chef d equipe") ||
          p == 'chef equipe';
    }

    /// Opérateur de nettoyage : toujours après les autres dans P1/P2.
    bool isOperateurNettoyagePoste(String poste) {
      final p = PointageExportService._foldAccentsForMatch(normalizePoste(poste));
      return p.contains('operateur nettoyage') || p.contains('operateur de nettoyage');
    }

    /// Numéro d'équipe (1…n) pour tri ; sans chiffre → en dernier.
    int ocpExtractEquipeNumber(String equipeName) {
      final m = RegExp(r'(\d+)').firstMatch(equipeName.trim());
      if (m != null) {
        final n = int.tryParse(m.group(1)!);
        if (n != null && n >= 1 && n <= 99) return n;
      }
      return 999;
    }

    int compareRowsP1P2ForOcpExport(PointageExportRow a, PointageExportRow b) {
      final netA = isOperateurNettoyagePoste(a.poste) ? 1 : 0;
      final netB = isOperateurNettoyagePoste(b.poste) ? 1 : 0;
      if (netA != netB) return netA.compareTo(netB);
      final chefA = isChefEquipePosteOnly(a.poste) ? 0 : 1;
      final chefB = isChefEquipePosteOnly(b.poste) ? 0 : 1;
      if (chefA != chefB) return chefA.compareTo(chefB);
      final eqA = ocpExtractEquipeNumber(a.equipeName);
      final eqB = ocpExtractEquipeNumber(b.equipeName);
      if (eqA != eqB) return eqA.compareTo(eqB);
      return a.employeNom.compareTo(b.employeNom);
    }

    bool isAllowedExportShift(String code) =>
        code == 'P1' || code == 'P2' || code == 'P3' || code == 'P4' || code == 'P5' || code == 'P6';

    /// Shift P1…P6 uniquement si un bloc OCP est défini dans la fiche employé.
    String shiftCodeForRow(PointageExportRow row) {
      if (!OcpExcelSegmentCode.hasExplicitPlacement(row.ocpExcelSegment)) {
        return '';
      }
      return OcpExcelSegmentCode.shiftFromSegment(row.ocpExcelSegment);
    }

    bool isOcpExportEligibleRow(PointageExportRow row) {
      if (!OcpExcelSegmentCode.hasExplicitPlacement(row.ocpExcelSegment)) {
        return false;
      }
      return isAllowedExportShift(shiftCodeForRow(row));
    }

    int shiftSortRank(String code) {
      switch (code) {
        case 'P1':
          return 1;
        case 'P2':
          return 2;
        case 'P3':
          return 3;
        case 'P4':
          return 4;
        case 'P5':
          return 5;
        case 'P6':
          return 6;
        default:
          final m = RegExp(r'^P(\d+)$').firstMatch(code);
          if (m != null) {
            final n = int.tryParse(m.group(1)!);
            if (n != null && n >= 1 && n <= 6) return n;
          }
          return 99;
      }
    }

    String ocpFoldTeamPoste(PointageExportRow r) {
      final raw = '${r.equipeName} ${r.poste}'
          .trim()
          .toLowerCase()
          .replaceAll("'", ' ')
          .replaceAll('\u2019', ' ')
          .replaceAll(RegExp(r'\s+'), ' ');
      return PointageExportService._foldAccentsForMatch(raw);
    }

    String? ocpP1Bucket(PointageExportRow r) {
      if (shiftCodeForRow(r) != 'P1') return null;
      final fromSeg = OcpExcelSegmentCode.toP1Bucket(r.ocpExcelSegment);
      if (fromSeg != null) return fromSeg;
      final t = ocpFoldTeamPoste(r);
      if (t.contains('sychem') && t.contains('ro') && t.contains('uf')) return 'p1_ro';
      if (t.contains('remin') || t.contains('transfert')) return 'p1_remin';
      if (t.contains(' qt') || t.contains('qt ') || t.endsWith(' qt') || t.contains('equipe qt')) {
        return 'p1_qt';
      }
      return 'p1_autres';
    }

    int ocpP1BucketRank(String k) {
      switch (k) {
        case 'p1_ro':
          return 0;
        case 'p1_qt':
          return 1;
        case 'p1_remin':
          return 2;
        default:
          return 3;
      }
    }

    ({String label, int ePrev}) ocpP1BucketHeader(String k) {
      switch (k) {
        case 'p1_ro':
          return (label: 'Sychem RO & UF', ePrev: 4);
        case 'p1_qt':
          return (label: 'QT', ePrev: 4);
        case 'p1_remin':
          return (label: 'Sychem Remin & Transfert', ePrev: 4);
        default:
          return (label: 'Autres', ePrev: 0);
      }
    }

    String? ocpP2Bucket(PointageExportRow r) {
      if (shiftCodeForRow(r) != 'P2') return null;
      final fromSeg = OcpExcelSegmentCode.toP2Bucket(r.ocpExcelSegment);
      if (fromSeg != null) return fromSeg;
      final uparts = r.equipeName.toUpperCase().split(RegExp(r'[^A-Z0-9]+'));
      if (uparts.contains('ION')) return 'p2_ion';
      final t = ocpFoldTeamPoste(r);
      if (t.contains(' qt') || t.contains('qt ') || t.endsWith(' qt')) return 'p2_qt';
      return 'p2_sychem';
    }

    int ocpP2BucketRank(String k) {
      switch (k) {
        case 'p2_sychem':
          return 0;
        case 'p2_ion':
          return 1;
        case 'p2_qt':
          return 2;
        default:
          return 3;
      }
    }

    ({String label, int ePrev}) ocpP2BucketHeader(String k) {
      switch (k) {
        case 'p2_sychem':
          return (label: 'Sychem', ePrev: 24);
        case 'p2_ion':
          return (label: 'ION', ePrev: 4);
        case 'p2_qt':
          return (label: 'QT', ePrev: 14);
        default:
          return (label: '', ePrev: 0);
      }
    }

    String? ocpP3Bucket(PointageExportRow r) {
      if (shiftCodeForRow(r) != 'P3') return null;
      final fromSeg = OcpExcelSegmentCode.toP3Bucket(r.ocpExcelSegment);
      if (fromSeg != null) return fromSeg;
      final t = ocpFoldTeamPoste(r);
      if (t.contains('logistique') || t.contains('logistic')) return 'p3_logistique';
      if (t.contains(' qt') || t.contains('qt ') || t.endsWith(' qt') || t.contains('equipe qt')) {
        return 'p3_qt';
      }
      if (t.contains('sychem')) return 'p3_sychem';
      return 'p3_autres';
    }

    int ocpP3BucketRank(String k) {
      switch (k) {
        case 'p3_sychem':
          return 0;
        case 'p3_qt':
          return 1;
        case 'p3_logistique':
          return 2;
        default:
          return 3;
      }
    }

    ({String label, int ePrev}) ocpP3BucketHeader(String k) {
      switch (k) {
        case 'p3_sychem':
          return (label: 'Sychem', ePrev: 4);
        case 'p3_qt':
          return (label: 'QT', ePrev: 4);
        case 'p3_logistique':
          return (label: 'Logistique', ePrev: 1);
        default:
          return (label: 'Autres', ePrev: 0);
      }
    }

    /// Tri P3 OCP : bucket (Sychem / QT / Log.) puis équipe 1…n puis nom.
    int compareRowsP3ForOcpExport(PointageExportRow a, PointageExportRow b) {
      final a3 = ocpP3Bucket(a);
      final b3 = ocpP3Bucket(b);
      if (a3 != null && b3 != null) {
        final br = ocpP3BucketRank(a3).compareTo(ocpP3BucketRank(b3));
        if (br != 0) return br;
      } else if ((a3 == null) != (b3 == null)) {
        return a3 == null ? 1 : -1;
      }
      final eqA = ocpExtractEquipeNumber(a.equipeName);
      final eqB = ocpExtractEquipeNumber(b.equipeName);
      if (eqA != eqB) return eqA.compareTo(eqB);
      return a.employeNom.compareTo(b.employeNom);
    }

    String? ocpP4Bucket(PointageExportRow r) {
      if (shiftCodeForRow(r) != 'P4') return null;
      final fromSeg = OcpExcelSegmentCode.toP4Bucket(r.ocpExcelSegment);
      if (fromSeg != null) return fromSeg;
      final t = ocpFoldTeamPoste(r);
      if ((t.contains('animateur') || t.contains('animation')) && t.contains('hse')) {
        return 'p4_animateur_hse';
      }
      return 'p4_autres';
    }

    int ocpP4BucketRank(String k) {
      switch (k) {
        case 'p4_animateur_hse':
          return 0;
        default:
          return 1;
      }
    }

    ({String label, int ePrev}) ocpP4BucketHeader(String k) {
      switch (k) {
        case 'p4_animateur_hse':
          return (label: 'Animation HSE', ePrev: 1);
        default:
          return (label: 'Autres', ePrev: 0);
      }
    }

    /// Sous-segments P5 export OCP (ordre feuille : chef zone → suivi perf. → QHSE).
    String? ocpP5SubBucketFromRow(PointageExportRow r) {
      final t = ocpFoldTeamPoste(r);
      if (t.contains('suivi performance') || t.contains('responsable suivi performance')) {
        return 'p5_suivi_performance';
      }
      if (t.contains('chef de zone') || t.contains('chef zone')) {
        return 'p5_chef_zone';
      }
      if (t.contains('qhse')) {
        return 'p5_qhse';
      }
      return null;
    }

    String? ocpP5Bucket(PointageExportRow r) {
      if (shiftCodeForRow(r) != 'P5') return null;
      final fromSeg = OcpExcelSegmentCode.toP5Bucket(r.ocpExcelSegment);
      if (fromSeg == 'p5_animation_hse' || fromSeg == 'p5_pilotage_process') {
        return 'p5_autres';
      }
      if (fromSeg == 'p5_cadre') {
        return ocpP5SubBucketFromRow(r) ?? 'p5_autres';
      }
      if (fromSeg != null) {
        return 'p5_autres';
      }
      final t = ocpFoldTeamPoste(r);
      if (t.contains('pilotage') && t.contains('process')) return 'p5_autres';
      if (t.contains('animation') && t.contains('hse')) return 'p5_autres';
      return ocpP5SubBucketFromRow(r) ?? 'p5_autres';
    }

    int ocpP5BucketRank(String k) {
      switch (k) {
        case 'p5_chef_zone':
          return 0;
        case 'p5_suivi_performance':
          return 1;
        case 'p5_qhse':
          return 2;
        default:
          return 3;
      }
    }

    ({String label, int ePrev}) ocpP5BucketHeader(String k) {
      switch (k) {
        case 'p5_chef_zone':
          return (label: 'Chef de zone', ePrev: 1);
        case 'p5_suivi_performance':
          return (label: 'Responsable suivi performance', ePrev: 1);
        case 'p5_qhse':
          return (label: 'QHSE', ePrev: 1);
        default:
          return (label: 'Autres', ePrev: 0);
      }
    }

    String? ocpP6Bucket(PointageExportRow r) {
      if (shiftCodeForRow(r) != 'P6') return null;
      final fromSeg = OcpExcelSegmentCode.toP6Bucket(r.ocpExcelSegment);
      if (fromSeg == 'p6_autres') return 'p6_autres';
      if (fromSeg != null) return 'p6_w2e';
      final t = ocpFoldTeamPoste(r);
      if (t.contains('remin') || t.contains('transfert')) return 'p6_w2e';
      if (t.contains(' qt') || t.contains('qt ') || t.endsWith(' qt')) return 'p6_w2e';
      if (t.contains('sychem')) return 'p6_w2e';
      return 'p6_autres';
    }

    int ocpP6BucketRank(String k) {
      switch (k) {
        case 'p6_w2e':
          return 0;
        default:
          return 1;
      }
    }

    ({String label, int ePrev}) ocpP6BucketHeader(String k) {
      switch (k) {
        case 'p6_w2e':
          return (label: 'W2E', ePrev: 1);
        case 'p6_sychem':
          return (label: 'Sychem', ePrev: 1);
        case 'p6_qt':
          return (label: 'QT', ePrev: 1);
        case 'p6_remin':
          return (label: 'Remin & Transfert', ePrev: 1);
        default:
          return (label: 'Autres', ePrev: 0);
      }
    }

    final sortedRows = List<PointageExportRow>.from(
      rows.where(isOcpExportEligibleRow),
    )
      ..sort((a, b) {
        final byShift = shiftSortRank(shiftCodeForRow(a)).compareTo(shiftSortRank(shiftCodeForRow(b)));
        if (byShift != 0) return byShift;
        final scA = shiftCodeForRow(a);
        if (scA == shiftCodeForRow(b) && (scA == 'P1' || scA == 'P2')) {
          return compareRowsP1P2ForOcpExport(a, b);
        }
        if (shiftCodeForRow(a) == 'P3' && shiftCodeForRow(b) == 'P3') {
          return compareRowsP3ForOcpExport(a, b);
        }
        final byPoste = normalizePoste(a.poste).compareTo(normalizePoste(b.poste));
        if (byPoste != 0) return byPoste;
        final aChef = isChefPoste(a.poste);
        final bChef = isChefPoste(b.poste);
        if (aChef != bChef) return aChef ? -1 : 1;
        final byTeam = a.equipeName.compareTo(b.equipeName);
        if (byTeam != 0) return byTeam;
        return a.employeNom.compareTo(b.employeNom);
      });

    final exportRows = List<PointageExportRow>.from(sortedRows)
      ..sort((a, b) {
        final byShift = shiftSortRank(shiftCodeForRow(a)).compareTo(shiftSortRank(shiftCodeForRow(b)));
        if (byShift != 0) return byShift;
        final a1 = ocpP1Bucket(a);
        final b1 = ocpP1Bucket(b);
        if (a1 != null && b1 != null) {
          final br = ocpP1BucketRank(a1).compareTo(ocpP1BucketRank(b1));
          if (br != 0) return br;
        }
        final a2 = ocpP2Bucket(a);
        final b2 = ocpP2Bucket(b);
        if (a2 != null && b2 != null) {
          final br = ocpP2BucketRank(a2).compareTo(ocpP2BucketRank(b2));
          if (br != 0) return br;
        }
        if (shiftCodeForRow(a) == 'P3' && shiftCodeForRow(b) == 'P3') {
          return compareRowsP3ForOcpExport(a, b);
        }
        final a4 = ocpP4Bucket(a);
        final b4 = ocpP4Bucket(b);
        if (shiftCodeForRow(a) == 'P4' && shiftCodeForRow(b) == 'P4' && a4 != null && b4 != null) {
          final br = ocpP4BucketRank(a4).compareTo(ocpP4BucketRank(b4));
          if (br != 0) return br;
        }
        final a5 = ocpP5Bucket(a);
        final b5 = ocpP5Bucket(b);
        if (shiftCodeForRow(a) == 'P5' && shiftCodeForRow(b) == 'P5' && a5 != null && b5 != null) {
          final br = ocpP5BucketRank(a5).compareTo(ocpP5BucketRank(b5));
          if (br != 0) return br;
        }
        final a6 = ocpP6Bucket(a);
        final b6 = ocpP6Bucket(b);
        if (shiftCodeForRow(a) == 'P6' && shiftCodeForRow(b) == 'P6' && a6 != null && b6 != null) {
          final br = ocpP6BucketRank(a6).compareTo(ocpP6BucketRank(b6));
          if (br != 0) return br;
        }
        final scBoth = shiftCodeForRow(a);
        if (scBoth == shiftCodeForRow(b) && (scBoth == 'P1' || scBoth == 'P2')) {
          return compareRowsP1P2ForOcpExport(a, b);
        }
        final byPoste = normalizePoste(a.poste).compareTo(normalizePoste(b.poste));
        if (byPoste != 0) return byPoste;
        final aChef = isChefPoste(a.poste);
        final bChef = isChefPoste(b.poste);
        if (aChef != bChef) return aChef ? -1 : 1;
        final byTeam = a.equipeName.compareTo(b.equipeName);
        if (byTeam != 0) return byTeam;
        return a.employeNom.compareTo(b.employeNom);
      });

    bool ocpRowExcludedFromSheet(PointageExportRow r) {
      final sc = shiftCodeForRow(r);
      switch (sc) {
        case 'P1':
          return (ocpP1Bucket(r) ?? '') == 'p1_autres';
        case 'P3':
          return (ocpP3Bucket(r) ?? '') == 'p3_autres';
        case 'P4':
          return (ocpP4Bucket(r) ?? '') == 'p4_autres';
        case 'P5':
          return (ocpP5Bucket(r) ?? '') == 'p5_autres';
        case 'P6':
          return (ocpP6Bucket(r) ?? '') == 'p6_autres';
        default:
          return false;
      }
    }

    var exportRowsForSheet =
        exportRows.where((r) => !ocpRowExcludedFromSheet(r)).toList();

    // Gabarit OCP : chaque segment (hors Autres) garde au moins « effectif prévu » lignes,
    // même sans personnes — mêmes entêtes / fusions / colonnes que le modèle.
    {
      String? ocpBucketKeyForRow(PointageExportRow r) {
        switch (shiftCodeForRow(r)) {
          case 'P1':
            return ocpP1Bucket(r);
          case 'P2':
            return ocpP2Bucket(r);
          case 'P3':
            return ocpP3Bucket(r);
          case 'P4':
            return ocpP4Bucket(r);
          case 'P5':
            return ocpP5Bucket(r);
          case 'P6':
            return ocpP6Bucket(r);
          default:
            return null;
        }
      }

      ({String label, int ePrev}) ocpHeaderFor(String sc, String bk) {
        switch (sc) {
          case 'P1':
            return ocpP1BucketHeader(bk);
          case 'P2':
            return ocpP2BucketHeader(bk);
          case 'P3':
            return ocpP3BucketHeader(bk);
          case 'P4':
            return ocpP4BucketHeader(bk);
          case 'P5':
            return ocpP5BucketHeader(bk);
          case 'P6':
            return ocpP6BucketHeader(bk);
          default:
            return (label: '', ePrev: 0);
        }
      }

      String ocpSegmentForSlot(String sc, String bk) {
        switch (sc) {
          case 'P1':
            switch (bk) {
              case 'p1_ro':
                return OcpExcelSegmentCode.p1SychemRoUf;
              case 'p1_qt':
                return OcpExcelSegmentCode.p1Qt;
              case 'p1_remin':
                return OcpExcelSegmentCode.p1SychemRemin;
              default:
                return '';
            }
          case 'P2':
            switch (bk) {
              case 'p2_sychem':
                return OcpExcelSegmentCode.p2Sychem;
              case 'p2_ion':
                return OcpExcelSegmentCode.p2Ion;
              case 'p2_qt':
                return OcpExcelSegmentCode.p2Qt;
              default:
                return '';
            }
          case 'P3':
            switch (bk) {
              case 'p3_sychem':
                return OcpExcelSegmentCode.p3Sychem;
              case 'p3_qt':
                return OcpExcelSegmentCode.p3Qt;
              case 'p3_logistique':
                return OcpExcelSegmentCode.p3Logistique;
              default:
                return '';
            }
          case 'P4':
            return bk == 'p4_animateur_hse' ? OcpExcelSegmentCode.p4AnimateurHse : '';
          case 'P5':
            switch (bk) {
              case 'p5_chef_zone':
              case 'p5_suivi_performance':
              case 'p5_qhse':
                return OcpExcelSegmentCode.p5Cadre;
              case 'p5_animation_hse':
                return OcpExcelSegmentCode.p5AnimationHse;
              case 'p5_pilotage_process':
                return OcpExcelSegmentCode.p5PilotageProcess;
              case 'p5_cadre':
                return OcpExcelSegmentCode.p5Cadre;
              default:
                return '';
            }
          case 'P6':
            switch (bk) {
              case 'p6_w2e':
                return OcpExcelSegmentCode.p6Sychem;
              case 'p6_sychem':
                return OcpExcelSegmentCode.p6Sychem;
              case 'p6_qt':
                return OcpExcelSegmentCode.p6Qt;
              case 'p6_remin':
                return OcpExcelSegmentCode.p6ReminTransfert;
              default:
                return '';
            }
          default:
            return '';
        }
      }

      String defaultPosteForOcpShift(String sc) {
        switch (sc) {
          case 'P1':
            return 'Opérateur salle de contrôle';
          case 'P2':
            return 'Opérateur process';
          case 'P3':
            return 'Chef d\'équipe';
          case 'P4':
            return 'Animateur HSE';
          case 'P5':
            return 'QHSE';
          case 'P6':
            return 'Chef d\'atelier';
          default:
            return 'Opérateur';
        }
      }

      PointageExportRow ocpSkeletonRow(
        PointageExportRow? seed,
        String sc,
        String bk,
        String segment,
        int slotIndex,
      ) {
        // P5 : sans poste explicite, ne pas utiliser « QHSE » par défaut pour tout le bloc
        // (sinon ocpP5Bucket reclasse chaque squelette en p5_qhse → doublon + slot suivi absent).
        final String poste;
        if (seed != null && seed.poste.trim().isNotEmpty) {
          poste = seed.poste;
        } else if (sc == 'P5') {
          poste = ocpP5BucketHeader(bk).label;
        } else {
          poste = defaultPosteForOcpShift(sc);
        }
        final hoursByDay = <DateTime, String>{};
        final dayStatusByDay = <DateTime, String>{};
        for (final d in days) {
          hoursByDay[d] = '';
          dayStatusByDay[d] = '';
        }
        return PointageExportRow(
          employeId: '__ocp_skeleton__${sc}_${bk}_$slotIndex',
          employeCin: '',
          employeNom: '',
          poste: poste,
          equipeName: seed?.equipeName ?? '',
          equipeId: seed?.equipeId,
          orgTypeLabel: seed?.orgTypeLabel ?? 'Équipe',
          daysWorked: 0,
          plannedShifts: days.length,
          daysAbsent: 0,
          totalHours: 0,
          overtimeHours: 0,
          salaireNet: seed?.salaireNet ?? 0,
          salairePeriode: 0,
          hoursByDay: hoursByDay,
          dayStatusByDay: dayStatusByDay,
          absenceReasonIdByDay: const {},
          ocpExcelSegment: segment,
          ocpForceSalleControle: sc == 'P1',
        );
      }

      final byKey = <String, List<PointageExportRow>>{};
      for (final r in exportRowsForSheet) {
        final sc = shiftCodeForRow(r);
        if (!isAllowedExportShift(sc)) continue;
        final bk = ocpBucketKeyForRow(r);
        if (bk == null || bk.endsWith('_autres')) continue;
        byKey.putIfAbsent('$sc|$bk', () => []).add(r);
      }
      for (final list in byKey.values) {
        list.sort((a, b) {
          final sc = shiftCodeForRow(a);
          if (shiftCodeForRow(b) == sc && (sc == 'P1' || sc == 'P2')) {
            return compareRowsP1P2ForOcpExport(a, b);
          }
          if (shiftCodeForRow(b) == sc && sc == 'P3') {
            return compareRowsP3ForOcpExport(a, b);
          }
          return a.employeNom.compareTo(b.employeNom);
        });
      }

      final ocpSlotOrder = <(String sc, List<String> buckets)>[
        ('P1', ['p1_ro', 'p1_qt', 'p1_remin']),
        ('P2', ['p2_sychem', 'p2_ion', 'p2_qt']),
        ('P3', ['p3_sychem', 'p3_qt', 'p3_logistique']),
        ('P4', ['p4_animateur_hse']),
        ('P5', ['p5_chef_zone', 'p5_suivi_performance', 'p5_qhse']),
        ('P6', ['p6_w2e']),
      ];

      final expanded = <PointageExportRow>[];
      final emittedIds = <String>{};
      final processedKeys = <String>{};

      for (final slot in ocpSlotOrder) {
        final sc = slot.$1;
        for (final bk in slot.$2) {
          final hdr = ocpHeaderFor(sc, bk);
          if (hdr.ePrev <= 0) continue;
          final seg = ocpSegmentForSlot(sc, bk);
          if (seg.isEmpty) continue;
          final key = '$sc|$bk';
          processedKeys.add(key);
          final reals = List<PointageExportRow>.from(byKey[key] ?? const []);
          final rowCount = max(hdr.ePrev, reals.length);
          final seed = reals.isNotEmpty ? reals.first : null;
          for (int i = 0; i < reals.length; i++) {
            expanded.add(reals[i]);
            emittedIds.add(reals[i].employeId);
          }
          for (int i = reals.length; i < rowCount; i++) {
            expanded.add(ocpSkeletonRow(seed, sc, bk, seg, i));
          }
        }
      }

      for (final e in byKey.entries) {
        if (processedKeys.contains(e.key)) continue;
        e.value.sort((a, b) {
          final sc = shiftCodeForRow(a);
          if (shiftCodeForRow(b) == sc && (sc == 'P1' || sc == 'P2')) {
            return compareRowsP1P2ForOcpExport(a, b);
          }
          if (shiftCodeForRow(b) == sc && sc == 'P3') {
            return compareRowsP3ForOcpExport(a, b);
          }
          return a.employeNom.compareTo(b.employeNom);
        });
        for (final r in e.value) {
          if (!emittedIds.contains(r.employeId)) {
            expanded.add(r);
            emittedIds.add(r.employeId);
          }
        }
      }

      exportRowsForSheet = expanded;
    }

    final book = excel.Excel.createExcel();
    final defaultName = book.getDefaultSheet() ?? 'Sheet1';
    book.rename(defaultName, 'Pointage');
    final sheet = book['Pointage'];

    final borderThin = excel.Border(
      borderStyle: excel.BorderStyle.Thin,
      borderColorHex: excel.ExcelColor.fromHexString('#BDBDBD'),
    );
    final borderMedium = excel.Border(
      borderStyle: excel.BorderStyle.Medium,
      borderColorHex: excel.ExcelColor.fromHexString('#424242'),
    );
    final borderSep = excel.Border(
      borderStyle: excel.BorderStyle.Thick,
      borderColorHex: excel.ExcelColor.fromHexString('#424242'),
    );
    excel.CellStyle baseStyle({
      bool bold = false,
      String bg = '#FFFFFF',
      String fg = '#000000',
      excel.HorizontalAlign align = excel.HorizontalAlign.Center,
      excel.VerticalAlign vAlign = excel.VerticalAlign.Center,
      excel.Border? left,
      excel.Border? right,
      excel.Border? top,
      excel.Border? bottom,
      excel.TextWrapping? wrap,
    }) {
      return excel.CellStyle(
        bold: bold,
        horizontalAlign: align,
        verticalAlign: vAlign,
        textWrapping: wrap,
        backgroundColorHex: excel.ExcelColor.fromHexString(bg),
        fontColorHex: excel.ExcelColor.fromHexString(fg),
        leftBorder: left ?? borderThin,
        rightBorder: right ?? borderThin,
        topBorder: top ?? borderThin,
        bottomBorder: bottom ?? borderThin,
      );
    }

    final titleStyle = baseStyle(
      bold: true,
      bg: '#D9E1F2',
      fg: '#1F4E78',
      align: excel.HorizontalAlign.Left,
    );
    final headerStyle = baseStyle(
      bold: true,
      bg: '#000000',
      fg: '#FFFFFF',
      align: excel.HorizontalAlign.Center,
    );
    final weekendHeaderStyle = baseStyle(
      bold: true,
      bg: '#263238',
      fg: '#E3F2FD',
      align: excel.HorizontalAlign.Center,
    );
    final dayHeaderLightStyle = baseStyle(
      bold: true,
      bg: '#D9EAF7',
      fg: '#1F4E78',
      align: excel.HorizontalAlign.Center,
    );

    const colShift = 1;
    const colService = 2;
    const colEntite = 3;
    const colPrevuDt = 4;
    const colTotalBloc = 5;
    const colDispo = 6;
    const colNom = 7;
    const colPrenom = 8;
    const colPoste = 9;
    const firstDayCol = 10; // après Shift..POSTE (aligné modèle OCP colonnes Nom / Prénom)
    const dayNamesRow = 7; // ligne 8 dans Excel (après bannière mois)
    const headerRow = 8; // ligne 9 dans Excel
    final shiftsCol = firstDayCol + days.length + 1;
    final totalPiCol = firstDayCol + days.length + 3;

    /// Libellé « Mois de Avril 2026 » selon le mois de début de période export.
    String ocpMonthBannerLabel() {
      final ref = DateTime(start.year, start.month, 1);
      try {
        final m = DateFormat('MMMM', 'fr_FR').format(ref);
        if (m.isEmpty) return 'Mois de ${ref.month} ${ref.year}';
        final cap = '${m[0].toUpperCase()}${m.substring(1)}';
        return 'Mois de $cap ${ref.year}';
      } catch (_) {
        const months = <String>[
          '',
          'Janvier',
          'Février',
          'Mars',
          'Avril',
          'Mai',
          'Juin',
          'Juillet',
          'Août',
          'Septembre',
          'Octobre',
          'Novembre',
          'Décembre',
        ];
        final name =
            ref.month >= 1 && ref.month <= 12 ? months[ref.month] : '${ref.month}';
        return 'Mois de $name ${ref.year}';
      }
    }

    final bannerStyle = baseStyle(
      bold: true,
      bg: '#D32F2F',
      fg: '#FFFFFF',
      align: excel.HorizontalAlign.Center,
      vAlign: excel.VerticalAlign.Center,
      top: borderMedium,
      bottom: borderMedium,
      left: borderMedium,
      right: borderMedium,
    );

    final bannerLabel = ocpMonthBannerLabel();
    // Bannière centrée : fusion sur quelques colonnes au milieu du tableau (pas toute la largeur).
    final bannerSpan = (bannerLabel.length * 0.42).ceil().clamp(5, 12);
    var bannerStartCol = ((totalPiCol - bannerSpan) / 2).round();
    if (bannerStartCol < 1) bannerStartCol = 1;
    var bannerEndCol = bannerStartCol + bannerSpan - 1;
    if (bannerEndCol > totalPiCol) {
      bannerEndCol = totalPiCol;
      bannerStartCol = (bannerEndCol - bannerSpan + 1).clamp(1, totalPiCol);
    }
    final bannerLeft =
        excel.CellIndex.indexByColumnRow(columnIndex: bannerStartCol, rowIndex: 1);
    final bannerRight =
        excel.CellIndex.indexByColumnRow(columnIndex: bannerEndCol, rowIndex: 1);
    sheet.merge(bannerLeft, bannerRight);
    sheet.cell(bannerLeft).value = excel.TextCellValue(bannerLabel);
    sheet.cell(bannerLeft).cellStyle = bannerStyle;
    sheet.setMergedCellStyle(bannerLeft, bannerStyle);

    // Header قريب من القالب المرجعي (سطرين عنوان + سطر أيام + سطر تواريخ)
    sheet.updateCell(
      excel.CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 2),
      excel.TextCellValue('DIPS  / WAVE 2 EAST'),
      cellStyle: titleStyle,
    );
    sheet.updateCell(
      excel.CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 3),
      excel.TextCellValue('FEUILLE DE POINTAGE'),
      cellStyle: titleStyle,
    );
    sheet.updateCell(
      excel.CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 4),
      excel.TextCellValue(
          'Période: ${_dateFormat.format(start)} - ${_dateFormat.format(end)}'),
      cellStyle: baseStyle(
        bold: true,
        bg: '#F5F5F5',
        fg: '#424242',
        align: excel.HorizontalAlign.Left,
      ),
    );

    var maxNomLen = 'Nom'.length;
    var maxPrenomLen = 'Prénom'.length;
    var maxPosteLen = 'POSTE'.length;
    for (final r in exportRowsForSheet) {
      final np = PointageExportService.splitNomPrenomForExcel(r.employeNom.trim());
      final nom = np.nom.trim().toUpperCase();
      final prenom = np.prenom.trim().toUpperCase();
      final poste = (r.poste.trim().isEmpty ? 'Opérateur' : r.poste.trim());
      if (nom.length > maxNomLen) maxNomLen = nom.length;
      if (prenom.length > maxPrenomLen) maxPrenomLen = prenom.length;
      if (poste.length > maxPosteLen) maxPosteLen = poste.length;
    }
    final nomColWidth =
        PointageExportService.ocpExcelColumnWidthForText('N' * maxNomLen, min: 26, max: 52);
    final prenomColWidth =
        PointageExportService.ocpExcelColumnWidthForText('N' * maxPrenomLen, min: 24, max: 52);
    final posteColWidth =
        PointageExportService.ocpExcelColumnWidthForText('N' * maxPosteLen, min: 26, max: 48);
    // سطر أسماء الأيام (Mercredi...)
    for (int i = 0; i < days.length; i++) {
      final d = days[i];
      final c = firstDayCol + i;
      final dayName = _weekdayNameFr(d.weekday);
      final isWeekend = d.weekday == DateTime.saturday || d.weekday == DateTime.sunday;
      sheet.updateCell(
        excel.CellIndex.indexByColumnRow(columnIndex: c, rowIndex: dayNamesRow),
        excel.TextCellValue(dayName),
        cellStyle: isWeekend ? weekendHeaderStyle : dayHeaderLightStyle,
      );
      sheet.updateCell(
        excel.CellIndex.indexByColumnRow(columnIndex: c, rowIndex: headerRow),
        excel.TextCellValue(_dateFormat.format(d)),
        cellStyle: isWeekend ? weekendHeaderStyle : dayHeaderLightStyle,
      );
    }

    // أعمدة القالب المرجعي
    final fixedHeaders = <int, String>{
      colShift: 'Shift',
      colService: 'Service',
      colEntite: 'Entité',
      colPrevuDt: 'Effectif prévu DT',
      colTotalBloc: 'Effectif cible',
      colDispo: 'Effectif disponible',
      colNom: 'Nom',
      colPrenom: 'Prénom',
      colPoste: 'POSTE',
      firstDayCol + days.length: '',
      shiftsCol: 'Nombre de Shift',
      firstDayCol + days.length + 2: '',
      totalPiCol: 'Total Shifts par Pi',
    };
    for (final e in fixedHeaders.entries) {
      sheet.updateCell(
        excel.CellIndex.indexByColumnRow(columnIndex: e.key, rowIndex: headerRow),
        excel.TextCellValue(e.value),
        cellStyle: headerStyle,
      );
    }

    const ocpServiceTitles = [
      'Opérateurs Salle de contrôle',
      'Opérateur Process & Nettoyage',
      'Chefs d\'équipe & logistique',
      'Animateur HSE',
      'Management Atelier',
      'Chefs d\'atelier',
      'Animation HSE',
      'Pilotage Process',
    ];
    var maxServiceLen = fixedHeaders[colService]!.length;
    for (final t in ocpServiceTitles) {
      if (t.length > maxServiceLen) maxServiceLen = t.length;
    }
    sheet.setColumnWidth(
      colShift,
      PointageExportService.ocpExcelColumnWidthForText('Shift', min: 9, max: 14),
    );
    sheet.setColumnWidth(
      colService,
      PointageExportService.ocpExcelColumnWidthForText(
        'N' * maxServiceLen,
        min: 30,
        max: 52,
      ),
    );
    sheet.setColumnWidth(
      colEntite,
      PointageExportService.ocpExcelColumnWidthForText('Entité', min: 14, max: 28),
    );
    sheet.setColumnWidth(
      colPrevuDt,
      PointageExportService.ocpExcelColumnWidthForText(
        fixedHeaders[colPrevuDt]!,
        min: 16,
        max: 24,
      ),
    );
    sheet.setColumnWidth(
      colTotalBloc,
      PointageExportService.ocpExcelColumnWidthForText(
        fixedHeaders[colTotalBloc]!,
        min: 15,
        max: 22,
      ),
    );
    sheet.setColumnWidth(
      colDispo,
      PointageExportService.ocpExcelColumnWidthForText(
        fixedHeaders[colDispo]!,
        min: 18,
        max: 26,
      ),
    );
    sheet.setColumnWidth(colNom, nomColWidth);
    sheet.setColumnWidth(colPrenom, prenomColWidth);
    sheet.setColumnWidth(colPoste, posteColWidth);
    // Largeur calendrier : tenir « dd/MM/yyyy » + nom du jour (Vendredi, Mercredi…).
    var maxDayHeaderChars = 0;
    for (final d in days) {
      final dateLen = _dateFormat.format(d).length;
      final dayLen = _weekdayNameFr(d.weekday).length;
      if (dateLen > maxDayHeaderChars) maxDayHeaderChars = dateLen;
      if (dayLen > maxDayHeaderChars) maxDayHeaderChars = dayLen;
    }
    final dayColWidth = PointageExportService.ocpExcelColumnWidthForText(
      'N' * maxDayHeaderChars,
      min: 14,
      max: 18,
    );
    for (int i = 0; i < days.length; i++) {
      sheet.setColumnWidth(firstDayCol + i, dayColWidth);
    }
    sheet.setColumnWidth(
      shiftsCol,
      PointageExportService.ocpExcelColumnWidthForText(
        fixedHeaders[shiftsCol]!,
        min: 16,
        max: 24,
      ),
    );
    sheet.setColumnWidth(
      totalPiCol,
      PointageExportService.ocpExcelColumnWidthForText(
        fixedHeaders[totalPiCol]!,
        min: 18,
        max: 28,
      ),
    );

    /// Fond bleu = présence/congé ; gris = repos ; blanc = absence / vide.
    excel.CellStyle ocpDayCellStyleForDay({
      required String marker,
      required String status,
      required String fallback,
      required bool isWeekend,
    }) {
      if (marker == '1') {
        return baseStyle(bg: '#E3F2FD', fg: '#0D47A1', align: excel.HorizontalAlign.Center);
      }
      final fb = fallback.trim().toLowerCase();
      if (status == 'rest' || fb == 'repos') {
        return baseStyle(bg: '#D9D9D9', fg: '#616161', align: excel.HorizontalAlign.Center);
      }
      if (isWeekend) {
        return baseStyle(bg: '#F5F5F5', align: excel.HorizontalAlign.Center);
      }
      return baseStyle(bg: '#FFFFFF', align: excel.HorizontalAlign.Center);
    }

    bool isOcpSkeletonExportRow(PointageExportRow r) =>
        r.employeId.startsWith('__ocp_skeleton__');

    String? ocpBucketKeyForCountRow(PointageExportRow r) {
      final sc = shiftCodeForRow(r);
      if (!isAllowedExportShift(sc)) return null;
      if (sc == 'P1') return ocpP1Bucket(r);
      if (sc == 'P2') return ocpP2Bucket(r);
      if (sc == 'P3') return ocpP3Bucket(r);
      if (sc == 'P4') return ocpP4Bucket(r);
      if (sc == 'P5') return ocpP5Bucket(r);
      if (sc == 'P6') return ocpP6Bucket(r);
      return null;
    }

    /// Statut / heures par jour en tolérant des clés [DateTime] légèrement différentes (UTC vs local).
    String exportRowDayStatusForDay(PointageExportRow r, DateTime d) {
      final k = PointageExportService._dayKey(d);
      for (final e in r.dayStatusByDay.entries) {
        if (PointageExportService._dayKey(e.key) == k) return e.value;
      }
      return '';
    }

    String exportRowHoursForDay(PointageExportRow r, DateTime d) {
      final k = PointageExportService._dayKey(d);
      for (final e in r.hoursByDay.entries) {
        if (PointageExportService._dayKey(e.key) == k) return e.value;
      }
      return '';
    }

    final actualPrevuByShiftBucket = <String, int>{};
    final headcountRealByShift = <String, int>{};
    final presentAtLeastOnceByShift = <String, int>{};
    final presentOnceByBucket = <String, int>{};
    for (final r in exportRowsForSheet) {
      if (isOcpSkeletonExportRow(r)) continue;
      final sc = shiftCodeForRow(r);
      if (!isAllowedExportShift(sc)) continue;
      final bk = ocpBucketKeyForCountRow(r);
      if (bk == null || bk.endsWith('_autres')) continue;
      final key = '$sc|$bk';
      actualPrevuByShiftBucket[key] = (actualPrevuByShiftBucket[key] ?? 0) + 1;
      headcountRealByShift[sc] = (headcountRealByShift[sc] ?? 0) + 1;
      var hasPresentOne = false;
      for (final d in days) {
        final status = exportRowDayStatusForDay(r, d);
        final fallback = exportRowHoursForDay(r, d);
        if (PointageExportService.ocpExcelDayMarker(status, fallback) == '1') {
          hasPresentOne = true;
          break;
        }
      }
      if (hasPresentOne) {
        presentAtLeastOnceByShift[sc] = (presentAtLeastOnceByShift[sc] ?? 0) + 1;
        presentOnceByBucket[key] = (presentOnceByBucket[key] ?? 0) + 1;
      }
    }

    /// Effectif cible (colonne fusionnée par shift) : valeurs fixes gabarit OCP.
    int? ocpEffectifCibleFixe(String shiftCode) {
      switch (shiftCode) {
        case 'P1':
          return 12;
        case 'P2':
          return 42;
        case 'P4':
          return 1;
        default:
          return null;
      }
    }

    int rowIndex = headerRow + 1; // première ligne données (ligne 10 Excel)
    String? currentShiftCode;
    int? shiftStartRow;
    int shiftTotalShifts = 0;
    String? currentPoste;
    int? posteStartRow;
    String? currentEntity;
    String? prevOcpP1Bucket;
    String? prevOcpP2Bucket;
    String? prevOcpP3Bucket;
    String? prevOcpP4Bucket;
    String? prevOcpP5Bucket;
    String? prevOcpP6Bucket;
    final shiftRanges = <({int start, int end, String shiftCode, String? ocpBucket, int totalShifts})>[];
    final posteRanges = <({int start, int end})>[];
    final ocpEntiteVerticalMerges = <({int start, int end, bool mergePrevu})>[];
    final ocpEntBlockEndRows = <int>{};
    int? ocpEntBlocStartRow;
    var ocpEntBlocMergePrevu = false;
    String? currentVisualMergeKey;

    void recordOcpEntiteVerticalMerge(int endInclusive) {
      if (ocpEntBlocStartRow == null) return;
      final s = ocpEntBlocStartRow!;
      if (endInclusive >= s) {
        ocpEntBlockEndRows.add(endInclusive);
        if (endInclusive > s) {
          ocpEntiteVerticalMerges.add((
            start: s,
            end: endInclusive,
            mergePrevu: ocpEntBlocMergePrevu,
          ));
        }
      }
      ocpEntBlocStartRow = null;
      ocpEntBlocMergePrevu = false;
    }

    String ocpShiftServiceTitle(String code) {
      switch (code) {
        case 'P1':
          return 'Opérateurs Salle de contrôle';
        case 'P2':
          return 'Opérateur Process & Nettoyage';
        case 'P3':
          return 'Chefs d\'équipe & logistique';
        case 'P4':
          return 'Animateur HSE';
        case 'P5':
          return 'Management Atelier';
        case 'P6':
          return 'Chefs d\'atelier';
        default:
          return '';
      }
    }

    String? ocpBucketFromVisualMergeKey(String? vmk) {
      if (vmk == null || !vmk.contains('|')) return null;
      final parts = vmk.split('|');
      if (parts.length < 2) return null;
      final sc = parts[0];
      if (sc != 'P4' && sc != 'P5' && sc != 'P6') return null;
      return parts[1];
    }

    String ocpBlockServiceTitle(String shiftCode) {
      if (shiftCode == 'P4') return 'Animation HSE';
      if (shiftCode == 'P6') return 'Pilotage Process';
      if (shiftCode == 'P5') return 'Management Atelier';
      return ocpShiftServiceTitle(shiftCode);
    }

    for (final r in exportRowsForSheet) {
      final np = PointageExportService.splitNomPrenomForExcel(r.employeNom.trim());
      final nomCol = np.nom.trim().toUpperCase();
      final prenomCol = np.prenom.trim().toUpperCase();
      final posteLabel = r.poste.trim().isEmpty ? 'Opérateur' : r.poste.trim();
      final posteKey = normalizePoste(posteLabel);
      final shiftCode = shiftCodeForRow(r);
      final p1b = ocpP1Bucket(r);
      final p2b = ocpP2Bucket(r);
      final p3b = ocpP3Bucket(r);
      final p4b = ocpP4Bucket(r);
      final p5b = ocpP5Bucket(r);
      final p6b = ocpP6Bucket(r);

      var visualMergeKey = shiftCode;
      // P5: une seule fusion verticale « P5 » sur tout le bloc (sous-blocs = Entité uniquement).
      if (shiftCode == 'P5' && (p5b == null || p5b.endsWith('_autres'))) {
        visualMergeKey = '$shiftCode|autres';
      }

      final posteKeyForMerge =
          isAllowedExportShift(shiftCode) ? '__m__$visualMergeKey' : posteKey;
      final showMergeBlock = currentVisualMergeKey != visualMergeKey;

      String entityKey = r.equipeName.trim();
      if (shiftCode == 'P3' && p3b != null && p3b != 'p3_autres') {
        entityKey = 'P3|$p3b';
      } else if (shiftCode == 'P4' && p4b != null && p4b != 'p4_autres') {
        entityKey = 'P4|$p4b';
      } else if (shiftCode == 'P5' && p5b != null && p5b != 'p5_autres') {
        entityKey = 'P5|$p5b';
      } else if (shiftCode == 'P6' && p6b != null && p6b != 'p6_autres') {
        entityKey = 'P6|$p6b';
      }

      final ocpSubBlocActif = (shiftCode == 'P3' && p3b != null && p3b != 'p3_autres') ||
          (shiftCode == 'P4' && p4b != null && p4b != 'p4_autres') ||
          (shiftCode == 'P5' && p5b != null && p5b != 'p5_autres') ||
          (shiftCode == 'P6' && p6b != null && p6b != 'p6_autres');

      final showShiftHeader = currentShiftCode != shiftCode;
      final showPosteHeader = currentPoste != posteKeyForMerge;
      final entityBlockChanged = currentEntity != entityKey;
      if (showShiftHeader) {
        prevOcpP1Bucket = null;
        prevOcpP2Bucket = null;
        prevOcpP3Bucket = null;
        prevOcpP4Bucket = null;
        prevOcpP5Bucket = null;
        prevOcpP6Bucket = null;
      }
      final showOcpEntite = (shiftCode == 'P1' && p1b != null && p1b != prevOcpP1Bucket) ||
          (shiftCode == 'P2' && p2b != null && p2b != prevOcpP2Bucket) ||
          (shiftCode == 'P3' && p3b != null && p3b != 'p3_autres' && p3b != prevOcpP3Bucket) ||
          (shiftCode == 'P4' && p4b != null && p4b != 'p4_autres' && p4b != prevOcpP4Bucket) ||
          (shiftCode == 'P5' && p5b != null && p5b != 'p5_autres' && p5b != prevOcpP5Bucket) ||
          (shiftCode == 'P6' && p6b != null && p6b != 'p6_autres' && p6b != prevOcpP6Bucket);
      if (shiftCode == 'P1') prevOcpP1Bucket = p1b;
      if (shiftCode == 'P2') prevOcpP2Bucket = p2b;
      if (shiftCode == 'P3') prevOcpP3Bucket = p3b;
      if (shiftCode == 'P4') prevOcpP4Bucket = p4b;
      if (shiftCode == 'P5') prevOcpP5Bucket = p5b;
      if (shiftCode == 'P6') prevOcpP6Bucket = p6b;

      final isFirstRow = rowIndex == headerRow + 1;
      if (!isFirstRow && showMergeBlock && shiftStartRow != null && currentShiftCode != null) {
        shiftRanges.add((
          start: shiftStartRow,
          end: rowIndex - 1,
          shiftCode: currentShiftCode,
          ocpBucket: ocpBucketFromVisualMergeKey(currentVisualMergeKey),
          totalShifts: shiftTotalShifts,
        ));
        shiftTotalShifts = 0;
      }
      if (!isFirstRow && showPosteHeader && posteStartRow != null) {
        posteRanges.add((start: posteStartRow, end: rowIndex - 1));
      }
      if (!isFirstRow && showMergeBlock && ocpEntBlocStartRow != null) {
        recordOcpEntiteVerticalMerge(rowIndex - 1);
      }
      if (showMergeBlock) shiftStartRow = rowIndex;
      if (showPosteHeader) posteStartRow = rowIndex;
      currentShiftCode = shiftCode;
      currentPoste = posteKeyForMerge;
      currentEntity = entityKey;

      sheet.updateCell(
        excel.CellIndex.indexByColumnRow(columnIndex: colShift, rowIndex: rowIndex),
        excel.TextCellValue(showMergeBlock ? shiftCode : ''),
        cellStyle: baseStyle(bold: true, bg: '#F3F6FB'),
      );
      sheet.updateCell(
        excel.CellIndex.indexByColumnRow(columnIndex: colService, rowIndex: rowIndex),
        excel.TextCellValue(
          showPosteHeader ? ocpBlockServiceTitle(shiftCode) : '',
        ),
        cellStyle: baseStyle(align: excel.HorizontalAlign.Center, bg: '#F3F6FB'),
      );

      if (showOcpEntite) {
        if (ocpEntBlocStartRow != null) {
          recordOcpEntiteVerticalMerge(rowIndex - 1);
        }
        final ({String label, int ePrev}) hdr = shiftCode == 'P1' && p1b != null
            ? ocpP1BucketHeader(p1b)
            : shiftCode == 'P2' && p2b != null
                ? ocpP2BucketHeader(p2b)
                : shiftCode == 'P3' && p3b != null
                    ? ocpP3BucketHeader(p3b)
                    : shiftCode == 'P4' && p4b != null
                        ? ocpP4BucketHeader(p4b)
                        : shiftCode == 'P5' && p5b != null
                            ? ocpP5BucketHeader(p5b)
                            : shiftCode == 'P6' && p6b != null
                                ? ocpP6BucketHeader(p6b)
                                : (label: '', ePrev: 0);
        final ocpBandTop = showShiftHeader ? borderThin : borderMedium;
        sheet.updateCell(
          excel.CellIndex.indexByColumnRow(columnIndex: colEntite, rowIndex: rowIndex),
          excel.TextCellValue(hdr.label),
          cellStyle: baseStyle(
            align: excel.HorizontalAlign.Center,
            bold: true,
            bg: '#ECEFF1',
            top: ocpBandTop,
            vAlign: excel.VerticalAlign.Center,
            wrap: excel.TextWrapping.WrapText,
          ),
        );
        final String? bkForPrevu = shiftCode == 'P1'
            ? p1b
            : shiftCode == 'P2'
                ? p2b
                : shiftCode == 'P3'
                    ? p3b
                    : shiftCode == 'P4'
                        ? p4b
                        : shiftCode == 'P5'
                            ? p5b
                            : shiftCode == 'P6'
                                ? p6b
                                : null;
        final prevuReel = bkForPrevu != null
            ? (actualPrevuByShiftBucket['$shiftCode|$bkForPrevu'] ?? 0)
            : 0;
        final prevuAffiche =
            (shiftCode == 'P1' || shiftCode == 'P2') ? hdr.ePrev : prevuReel;
        if (hdr.ePrev > 0) {
          sheet.updateCell(
            excel.CellIndex.indexByColumnRow(columnIndex: colPrevuDt, rowIndex: rowIndex),
            excel.IntCellValue(prevuAffiche),
            cellStyle: baseStyle(
              bold: true,
              bg: '#ECEFF1',
              align: excel.HorizontalAlign.Center,
              vAlign: excel.VerticalAlign.Center,
            ),
          );
        } else {
          sheet.updateCell(
            excel.CellIndex.indexByColumnRow(columnIndex: colPrevuDt, rowIndex: rowIndex),
            excel.TextCellValue(''),
            cellStyle: baseStyle(bg: '#ECEFF1'),
          );
        }
        ocpEntBlocMergePrevu = hdr.ePrev > 0;
        ocpEntBlocStartRow = rowIndex;
      } else if (!ocpSubBlocActif && shiftCode != 'P1' && shiftCode != 'P2' && entityBlockChanged) {
        if (ocpEntBlocStartRow != null) {
          recordOcpEntiteVerticalMerge(rowIndex - 1);
        }
        sheet.updateCell(
          excel.CellIndex.indexByColumnRow(columnIndex: colEntite, rowIndex: rowIndex),
          excel.TextCellValue(entityKey),
          cellStyle: baseStyle(align: excel.HorizontalAlign.Left),
        );
        sheet.updateCell(
          excel.CellIndex.indexByColumnRow(columnIndex: colPrevuDt, rowIndex: rowIndex),
          excel.TextCellValue(''),
          cellStyle: baseStyle(),
        );
      } else {
        sheet.updateCell(
          excel.CellIndex.indexByColumnRow(columnIndex: colEntite, rowIndex: rowIndex),
          excel.TextCellValue(''),
          cellStyle: baseStyle(),
        );
        sheet.updateCell(
          excel.CellIndex.indexByColumnRow(columnIndex: colPrevuDt, rowIndex: rowIndex),
          excel.TextCellValue(''),
          cellStyle: baseStyle(),
        );
      }

      if (showMergeBlock && isAllowedExportShift(shiftCode)) {
        final String? bkEnt = shiftCode == 'P5' ? p5b : null;
        final int effectifBloc = ocpEffectifCibleFixe(shiftCode) ??
            (shiftCode == 'P5' &&
                    bkEnt != null &&
                    !bkEnt.endsWith('_autres')
                ? (actualPrevuByShiftBucket['$shiftCode|$bkEnt'] ?? 0)
                : (headcountRealByShift[shiftCode] ?? 0));
        sheet.updateCell(
          excel.CellIndex.indexByColumnRow(columnIndex: colTotalBloc, rowIndex: rowIndex),
          excel.IntCellValue(effectifBloc),
          cellStyle: baseStyle(bold: true, align: excel.HorizontalAlign.Center),
        );
      } else {
        sheet.updateCell(
          excel.CellIndex.indexByColumnRow(columnIndex: colTotalBloc, rowIndex: rowIndex),
          excel.TextCellValue(''),
          cellStyle: baseStyle(),
        );
      }
      sheet.updateCell(
        excel.CellIndex.indexByColumnRow(columnIndex: colDispo, rowIndex: rowIndex),
        excel.TextCellValue(''),
        cellStyle: baseStyle(),
      );

      sheet.updateCell(
        excel.CellIndex.indexByColumnRow(columnIndex: colNom, rowIndex: rowIndex),
        excel.TextCellValue(nomCol),
        cellStyle: baseStyle(
          align: excel.HorizontalAlign.Left,
          wrap: excel.TextWrapping.WrapText,
        ),
      );
      sheet.updateCell(
        excel.CellIndex.indexByColumnRow(columnIndex: colPrenom, rowIndex: rowIndex),
        excel.TextCellValue(prenomCol),
        cellStyle: baseStyle(
          align: excel.HorizontalAlign.Left,
          wrap: excel.TextWrapping.WrapText,
        ),
      );
      sheet.updateCell(
        excel.CellIndex.indexByColumnRow(columnIndex: colPoste, rowIndex: rowIndex),
        excel.TextCellValue(r.poste.isEmpty ? 'Opérateur' : r.poste),
        cellStyle: baseStyle(
          align: excel.HorizontalAlign.Left,
          wrap: excel.TextWrapping.WrapText,
        ),
      );

      int presenceCount = 0;
      for (int i = 0; i < days.length; i++) {
        final d = days[i];
        final status = exportRowDayStatusForDay(r, d);
        final fallback = exportRowHoursForDay(r, d);
        final marker = PointageExportService.ocpExcelDayMarker(status, fallback);
        if (marker == '1') presenceCount++;
        final c = firstDayCol + i;
        final isWeekend = d.weekday == DateTime.saturday || d.weekday == DateTime.sunday;
        sheet.updateCell(
          excel.CellIndex.indexByColumnRow(columnIndex: c, rowIndex: rowIndex),
          excel.TextCellValue(marker),
          cellStyle: ocpDayCellStyleForDay(
            marker: marker,
            status: status,
            fallback: fallback,
            isWeekend: isWeekend,
          ),
        );
      }

      shiftTotalShifts += presenceCount;

      sheet.updateCell(
        excel.CellIndex.indexByColumnRow(columnIndex: shiftsCol, rowIndex: rowIndex),
        excel.IntCellValue(presenceCount),
        cellStyle: baseStyle(bold: true),
      );
      sheet.updateCell(
        excel.CellIndex.indexByColumnRow(columnIndex: totalPiCol, rowIndex: rowIndex),
        excel.IntCellValue(presenceCount),
        cellStyle: baseStyle(bold: true, bg: '#E8F5E9', fg: '#1B5E20'),
      );

      rowIndex++;
      currentVisualMergeKey = visualMergeKey;
    }

    recordOcpEntiteVerticalMerge(rowIndex - 1);

    if (exportRowsForSheet.isNotEmpty) {
      if (posteStartRow != null) {
        posteRanges.add((start: posteStartRow, end: rowIndex - 1));
      }
      if (shiftStartRow != null && currentShiftCode != null) {
        shiftRanges.add((
          start: shiftStartRow,
          end: rowIndex - 1,
          shiftCode: currentShiftCode,
          ocpBucket: ocpBucketFromVisualMergeKey(currentVisualMergeKey),
          totalShifts: shiftTotalShifts,
        ));
      }

      for (final rg in shiftRanges) {
        final effectifCibleReel = ocpEffectifCibleFixe(rg.shiftCode) ??
            (rg.ocpBucket != null
                ? (actualPrevuByShiftBucket['${rg.shiftCode}|${rg.ocpBucket}'] ?? 0)
                : (headcountRealByShift[rg.shiftCode] ?? 0));
        // Blocs fusionnés P4/P5/P6 : si aucun jour ne remonte en « présent » mais des lignes
        // existent sur la feuille, afficher au moins l'effectif réel (sinon « disponible » reste 0).
        final int baseEffectifDispo = rg.ocpBucket != null
            ? (presentOnceByBucket['${rg.shiftCode}|${rg.ocpBucket}'] ?? 0)
            : (presentAtLeastOnceByShift[rg.shiftCode] ?? 0);
        final int headOnSheet = headcountRealByShift[rg.shiftCode] ?? 0;
        // P3 : effectif réel sur la feuille (pas seulement présents ≥1 jour).
        final effectifDispoReel = rg.shiftCode == 'P3'
            ? headOnSheet
            : (rg.ocpBucket == null &&
                    (rg.shiftCode == 'P4' ||
                        rg.shiftCode == 'P5' ||
                        rg.shiftCode == 'P6') &&
                    baseEffectifDispo == 0 &&
                    headOnSheet > 0
                ? headOnSheet
                : baseEffectifDispo);

        sheet.updateCell(
          excel.CellIndex.indexByColumnRow(columnIndex: colShift, rowIndex: rg.start),
          excel.TextCellValue(rg.shiftCode),
          cellStyle: baseStyle(
            bold: true,
            bg: '#E3F2FD',
            align: excel.HorizontalAlign.Center,
            vAlign: excel.VerticalAlign.Center,
          ),
        );
        sheet.updateCell(
          excel.CellIndex.indexByColumnRow(columnIndex: totalPiCol, rowIndex: rg.start),
          excel.IntCellValue(rg.totalShifts),
          cellStyle: baseStyle(
            bold: true,
            bg: '#E8F5E9',
            fg: '#1B5E20',
            vAlign: excel.VerticalAlign.Center,
          ),
        );
        sheet.updateCell(
          excel.CellIndex.indexByColumnRow(columnIndex: colDispo, rowIndex: rg.start),
          excel.IntCellValue(effectifDispoReel),
          cellStyle: baseStyle(
            bold: true,
            bg: '#E3F2FD',
            align: excel.HorizontalAlign.Center,
            vAlign: excel.VerticalAlign.Center,
          ),
        );
        if (isAllowedExportShift(rg.shiftCode)) {
          sheet.updateCell(
            excel.CellIndex.indexByColumnRow(columnIndex: colTotalBloc, rowIndex: rg.start),
            excel.IntCellValue(effectifCibleReel),
            cellStyle: baseStyle(
              bold: true,
              bg: '#BBDEFB',
              align: excel.HorizontalAlign.Center,
              vAlign: excel.VerticalAlign.Center,
            ),
          );
        }
      }

      for (final rg in posteRanges) {
        // Accent visuel du bloc POSTE: bordure supérieure et inférieure plus épaisses.
        for (int col = 1; col <= totalPiCol; col++) {
          final topIdx = excel.CellIndex.indexByColumnRow(columnIndex: col, rowIndex: rg.start);
          final topCell = sheet.cell(topIdx);
          topCell.cellStyle = (topCell.cellStyle ?? baseStyle()).copyWith(topBorderVal: borderMedium);
          final bottomIdx = excel.CellIndex.indexByColumnRow(columnIndex: col, rowIndex: rg.end);
          final bottomCell = sheet.cell(bottomIdx);
          bottomCell.cellStyle = (bottomCell.cellStyle ?? baseStyle()).copyWith(bottomBorderVal: borderMedium);
        }
      }

      // Grille fine sur toutes les cellules (avant fusion verticale Entité / Prévu OCP).
      final lastDataCol = totalPiCol;
      for (int rr = headerRow; rr <= rowIndex - 1; rr++) {
        for (int cc = 1; cc <= lastDataCol; cc++) {
          final idx = excel.CellIndex.indexByColumnRow(columnIndex: cc, rowIndex: rr);
          final cell = sheet.cell(idx);
          cell.cellStyle = (cell.cellStyle ?? baseStyle()).copyWith(
            leftBorderVal: borderThin,
            rightBorderVal: borderThin,
            topBorderVal: borderThin,
            bottomBorderVal: borderThin,
          );
        }
      }

      // Bordures horizontales légères (éviter l'effet « liste de gros traits » entre chaque ligne).
      for (int rr = headerRow + 1; rr <= rowIndex - 1; rr++) {
        for (int cc = 1; cc <= lastDataCol; cc++) {
          final idx = excel.CellIndex.indexByColumnRow(columnIndex: cc, rowIndex: rr);
          final cell = sheet.cell(idx);
          cell.cellStyle = (cell.cellStyle ?? baseStyle()).copyWith(bottomBorderVal: borderThin);
        }
      }

      // Outer frame.
      for (int cc = 1; cc <= lastDataCol; cc++) {
        final topIdx = excel.CellIndex.indexByColumnRow(columnIndex: cc, rowIndex: headerRow);
        final topCell = sheet.cell(topIdx);
        topCell.cellStyle = (topCell.cellStyle ?? baseStyle()).copyWith(topBorderVal: borderMedium);
        final bottomIdx = excel.CellIndex.indexByColumnRow(columnIndex: cc, rowIndex: rowIndex - 1);
        final bottomCell = sheet.cell(bottomIdx);
        bottomCell.cellStyle = (bottomCell.cellStyle ?? baseStyle()).copyWith(bottomBorderVal: borderMedium);
      }
      for (int rr = headerRow; rr <= rowIndex - 1; rr++) {
        final leftIdx = excel.CellIndex.indexByColumnRow(columnIndex: colShift, rowIndex: rr);
        final leftCell = sheet.cell(leftIdx);
        leftCell.cellStyle = (leftCell.cellStyle ?? baseStyle()).copyWith(leftBorderVal: borderMedium);
        final rightIdx = excel.CellIndex.indexByColumnRow(columnIndex: lastDataCol, rowIndex: rr);
        final rightCell = sheet.cell(rightIdx);
        rightCell.cellStyle = (rightCell.cellStyle ?? baseStyle()).copyWith(rightBorderVal: borderMedium);
      }

      final ocpMergedEntBandStyle = baseStyle(
        bold: true,
        bg: '#ECEFF1',
        align: excel.HorizontalAlign.Center,
        left: borderThin,
        right: borderThin,
        top: borderThin,
        bottom: borderThin,
        vAlign: excel.VerticalAlign.Center,
        wrap: excel.TextWrapping.WrapText,
      );
      final ocpMergedPrevuBandStyle = baseStyle(
        bold: true,
        bg: '#ECEFF1',
        align: excel.HorizontalAlign.Center,
        left: borderThin,
        right: borderThin,
        top: borderThin,
        bottom: borderThin,
        vAlign: excel.VerticalAlign.Center,
      );

      for (final m in ocpEntiteVerticalMerges) {
        if (m.end > m.start) {
          final entTop = excel.CellIndex.indexByColumnRow(columnIndex: colEntite, rowIndex: m.start);
          final entBottom = excel.CellIndex.indexByColumnRow(columnIndex: colEntite, rowIndex: m.end);
          sheet.merge(entTop, entBottom);
          sheet.setMergedCellStyle(entTop, ocpMergedEntBandStyle);
          if (m.mergePrevu) {
            final prTop = excel.CellIndex.indexByColumnRow(columnIndex: colPrevuDt, rowIndex: m.start);
            final prBottom = excel.CellIndex.indexByColumnRow(columnIndex: colPrevuDt, rowIndex: m.end);
            sheet.merge(prTop, prBottom);
            sheet.setMergedCellStyle(prTop, ocpMergedPrevuBandStyle);
          }
        }
      }

      final shiftBlockMergedStyle = baseStyle(
        bold: true,
        bg: '#E3F2FD',
        align: excel.HorizontalAlign.Center,
        vAlign: excel.VerticalAlign.Center,
        left: borderThin,
        right: borderThin,
        top: borderThin,
        bottom: borderThin,
      );
      final serviceBlockMergedStyle = baseStyle(
        bold: true,
        bg: '#F3F6FB',
        align: excel.HorizontalAlign.Center,
        vAlign: excel.VerticalAlign.Center,
        wrap: excel.TextWrapping.WrapText,
        left: borderThin,
        right: borderThin,
        top: borderThin,
        bottom: borderThin,
      );
      final totalBlocMergedStyle = baseStyle(
        bold: true,
        bg: '#BBDEFB',
        align: excel.HorizontalAlign.Center,
        vAlign: excel.VerticalAlign.Center,
        left: borderThin,
        right: borderThin,
        top: borderThin,
        bottom: borderThin,
      );
      final dispoBlockMergedStyle = baseStyle(
        bold: true,
        bg: '#E3F2FD',
        align: excel.HorizontalAlign.Center,
        vAlign: excel.VerticalAlign.Center,
        left: borderThin,
        right: borderThin,
        top: borderThin,
        bottom: borderThin,
      );
      final totalPiBlockMergedStyle = baseStyle(
        bold: true,
        bg: '#E8F5E9',
        fg: '#1B5E20',
        align: excel.HorizontalAlign.Center,
        vAlign: excel.VerticalAlign.Center,
        left: borderThin,
        right: borderThin,
        top: borderThin,
        bottom: borderThin,
      );

      for (final rg in shiftRanges) {
        if (rg.end > rg.start) {
          final shS = excel.CellIndex.indexByColumnRow(columnIndex: colShift, rowIndex: rg.start);
          final shE = excel.CellIndex.indexByColumnRow(columnIndex: colShift, rowIndex: rg.end);
          sheet.merge(shS, shE);
          sheet.setMergedCellStyle(shS, shiftBlockMergedStyle);

          final piS = excel.CellIndex.indexByColumnRow(columnIndex: totalPiCol, rowIndex: rg.start);
          final piE = excel.CellIndex.indexByColumnRow(columnIndex: totalPiCol, rowIndex: rg.end);
          sheet.merge(piS, piE);
          sheet.setMergedCellStyle(piS, totalPiBlockMergedStyle);

          final dS = excel.CellIndex.indexByColumnRow(columnIndex: colDispo, rowIndex: rg.start);
          final dE = excel.CellIndex.indexByColumnRow(columnIndex: colDispo, rowIndex: rg.end);
          sheet.merge(dS, dE);
          sheet.setMergedCellStyle(dS, dispoBlockMergedStyle);

          if (isAllowedExportShift(rg.shiftCode)) {
            final tS = excel.CellIndex.indexByColumnRow(columnIndex: colTotalBloc, rowIndex: rg.start);
            final tE = excel.CellIndex.indexByColumnRow(columnIndex: colTotalBloc, rowIndex: rg.end);
            sheet.merge(tS, tE);
            sheet.setMergedCellStyle(tS, totalBlocMergedStyle);
          }
        }
      }
      for (final rg in posteRanges) {
        if (rg.end > rg.start) {
          final svS = excel.CellIndex.indexByColumnRow(columnIndex: colService, rowIndex: rg.start);
          final svE = excel.CellIndex.indexByColumnRow(columnIndex: colService, rowIndex: rg.end);
          sheet.merge(svS, svE);
          sheet.setMergedCellStyle(svS, serviceBlockMergedStyle);
        }
      }

      for (final endRow in ocpEntBlockEndRows) {
        if (endRow < headerRow + 1 || endRow > rowIndex - 1) continue;
        for (int cc = 1; cc <= lastDataCol; cc++) {
          final idx = excel.CellIndex.indexByColumnRow(columnIndex: cc, rowIndex: endRow);
          final cell = sheet.cell(idx);
          cell.cellStyle = (cell.cellStyle ?? baseStyle()).copyWith(bottomBorderVal: borderSep);
        }
      }
    }

    if (exportRowsForSheet.isEmpty) {
      sheet.updateCell(
        excel.CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: headerRow + 1),
        excel.TextCellValue(
          exportRows.isEmpty
              ? 'Aucune donnée pour cette période'
              : 'Aucune ligne exportable : les collaborateurs hors segment OCP (Autres) sont exclus de cette feuille.',
        ),
        cellStyle: baseStyle(align: excel.HorizontalAlign.Left, bold: true),
      );
    }

    final bytes = book.encode();
    if (bytes == null) return Uint8List(0);
    return Uint8List.fromList(bytes);
  }

  static Future<Uint8List> buildCompanyPointageExcel({
    required DateTime startDate,
    required DateTime endDate,
    required List<PointageExportRow> rows,
    bool singleSheet = false,
    String singleSheetName = 'Société',
    bool includeEquipeColumnInSingleSheet = true,
  }) async {
    final start = _dayKey(startDate);
    final end = _dayKey(endDate);
    final days = <DateTime>[];
    for (int i = 0; i <= end.difference(start).inDays; i++) {
      days.add(start.add(Duration(days: i)));
    }

    final book = excel.Excel.createExcel();
    final grouped = <String, List<PointageExportRow>>{};
    if (singleSheet) {
      final name = singleSheetName.trim().isEmpty ? 'Société' : singleSheetName.trim();
      final sorted = List<PointageExportRow>.from(rows)
        ..sort((a, b) {
          final c = a.equipeName.compareTo(b.equipeName);
          if (c != 0) return c;
          return a.employeNom.compareTo(b.employeNom);
        });
      grouped[name] = sorted;
    } else {
      for (final r in rows) {
        grouped.putIfAbsent(r.equipeName, () => []).add(r);
      }
    }

    bool isFirst = true;
    final defaultName = book.getDefaultSheet() ?? 'Sheet1';
    String? firstSheetName;

    for (final entry in grouped.entries) {
      var sheetName = entry.key.length > 30 ? entry.key.substring(0, 30) : entry.key;
      sheetName = sheetName.replaceAll(RegExp(r'[\\/*?\[\]:]'), '-');
      if (isFirst) {
        book.rename(defaultName, sheetName);
        firstSheetName = sheetName;
        isFirst = false;
      } else {
        book.copy(firstSheetName ?? defaultName, sheetName);
      }

      final sheet = book[sheetName];
      sheet.updateCell(
        excel.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0),
        excel.TextCellValue('Rapport pointage: ${entry.key}'),
      );
      sheet.updateCell(
        excel.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 1),
        excel.TextCellValue('Du ${_dateFormat.format(start)} au ${_dateFormat.format(end)}'),
      );

      int col = 0;
      const headerRow = 3;
      final headerStyle = excel.CellStyle(
        bold: true,
        horizontalAlign: excel.HorizontalAlign.Center,
        bottomBorder: excel.Border(
          borderStyle: excel.BorderStyle.Thin,
          borderColorHex: excel.ExcelColor.fromHexString('#9E9E9E'),
        ),
        topBorder: excel.Border(
          borderStyle: excel.BorderStyle.Thin,
          borderColorHex: excel.ExcelColor.fromHexString('#9E9E9E'),
        ),
        leftBorder: excel.Border(
          borderStyle: excel.BorderStyle.Thin,
          borderColorHex: excel.ExcelColor.fromHexString('#9E9E9E'),
        ),
        rightBorder: excel.Border(
          borderStyle: excel.BorderStyle.Thin,
          borderColorHex: excel.ExcelColor.fromHexString('#9E9E9E'),
        ),
      );

      if (singleSheet && includeEquipeColumnInSingleSheet) {
        final idx =
            excel.CellIndex.indexByColumnRow(columnIndex: col++, rowIndex: headerRow);
        sheet.updateCell(idx, excel.TextCellValue('Équipe'));
        sheet.cell(idx).cellStyle = headerStyle;
      }

      final idxEmp = excel.CellIndex.indexByColumnRow(columnIndex: col++, rowIndex: headerRow);
      sheet.updateCell(idxEmp, excel.TextCellValue('Collaborateur'));
      sheet.cell(idxEmp).cellStyle = headerStyle;

      for (final d in days) {
        final idx = excel.CellIndex.indexByColumnRow(columnIndex: col++, rowIndex: headerRow);
        sheet.updateCell(idx, excel.TextCellValue(_dateFormat.format(d)));
        sheet.cell(idx).cellStyle = headerStyle;
      }

      void setHeader(String label) {
        final idx = excel.CellIndex.indexByColumnRow(columnIndex: col++, rowIndex: headerRow);
        sheet.updateCell(idx, excel.TextCellValue(label));
        sheet.cell(idx).cellStyle = headerStyle;
      }

      setHeader('Jours travailles');
      setHeader('Jours absents');
      setHeader('Total heures');
      setHeader('Heures sup.');
      setHeader('Temps total');
      setHeader('Salaire net');
      setHeader('Salaire periode');

      var rowIndex = headerRow + 1;
      for (final r in entry.value) {
        col = 0;
        if (singleSheet && includeEquipeColumnInSingleSheet) {
          sheet.updateCell(
            excel.CellIndex.indexByColumnRow(columnIndex: col++, rowIndex: rowIndex),
            excel.TextCellValue(r.equipeName),
          );
        }
        sheet.updateCell(
          excel.CellIndex.indexByColumnRow(columnIndex: col++, rowIndex: rowIndex),
          excel.TextCellValue(r.employeNom),
        );
        final firstDayCol = (singleSheet && includeEquipeColumnInSingleSheet) ? 2 : 1;
        var dayCol = firstDayCol;

        excel.CellStyle makeDayStyle({String bg = '#FFFFFF', String fg = '#000000'}) {
          return excel.CellStyle(
            horizontalAlign: excel.HorizontalAlign.Center,
            backgroundColorHex: excel.ExcelColor.fromHexString(bg),
            fontColorHex: excel.ExcelColor.fromHexString(fg),
            leftBorder: excel.Border(
              borderStyle: excel.BorderStyle.Thin,
              borderColorHex: excel.ExcelColor.fromHexString('#BDBDBD'),
            ),
            rightBorder: excel.Border(
              borderStyle: excel.BorderStyle.Thin,
              borderColorHex: excel.ExcelColor.fromHexString('#BDBDBD'),
            ),
            topBorder: excel.Border(
              borderStyle: excel.BorderStyle.Thin,
              borderColorHex: excel.ExcelColor.fromHexString('#BDBDBD'),
            ),
            bottomBorder: excel.Border(
              borderStyle: excel.BorderStyle.Thin,
              borderColorHex: excel.ExcelColor.fromHexString('#BDBDBD'),
            ),
          );
        }

        for (final d in days) {
          final val = r.hoursByDay[d] ?? '-';
          final cellIndex =
              excel.CellIndex.indexByColumnRow(columnIndex: dayCol, rowIndex: rowIndex);
          final dayStatus = r.dayStatusByDay[d] ?? '';
          final excel.CellStyle style;
          switch (dayStatus) {
            case 'present':
              style = makeDayStyle(bg: '#C8E6C9', fg: '#1B5E20');
            case 'absent':
              style = makeDayStyle(bg: '#FFCDD2', fg: '#B71C1C');
            case 'formation':
              style = makeDayStyle(bg: '#BBDEFB', fg: '#0D47A1');
            case 'leave':
              style = makeDayStyle(bg: '#0D47A1', fg: '#FFFFFF');
            case 'paid_absence':
              style = makeDayStyle(bg: '#FFE0B2', fg: '#E65100');
            case 'rest':
              style = makeDayStyle(bg: '#EEEEEE', fg: '#616161');
            case 'pending_exit':
              style = makeDayStyle(bg: '#FFE082', fg: '#E65100');
            default:
              style = makeDayStyle();
          }
          sheet.updateCell(cellIndex, excel.TextCellValue(val), cellStyle: style);
          dayCol++;
          col = dayCol;
        }

        sheet.updateCell(
          excel.CellIndex.indexByColumnRow(columnIndex: col++, rowIndex: rowIndex),
          excel.TextCellValue('${r.daysWorked}/${r.plannedShifts}'),
        );
        sheet.updateCell(
          excel.CellIndex.indexByColumnRow(columnIndex: col++, rowIndex: rowIndex),
          excel.IntCellValue(r.daysAbsent),
        );
        sheet.updateCell(
          excel.CellIndex.indexByColumnRow(columnIndex: col++, rowIndex: rowIndex),
          excel.DoubleCellValue(r.totalHours),
        );
        sheet.updateCell(
          excel.CellIndex.indexByColumnRow(columnIndex: col++, rowIndex: rowIndex),
          excel.DoubleCellValue(r.overtimeHours),
        );
        sheet.updateCell(
          excel.CellIndex.indexByColumnRow(columnIndex: col++, rowIndex: rowIndex),
          excel.DoubleCellValue(r.totalHours + r.overtimeHours),
        );
        sheet.updateCell(
          excel.CellIndex.indexByColumnRow(columnIndex: col++, rowIndex: rowIndex),
          excel.DoubleCellValue(r.salaireNet),
        );
        sheet.updateCell(
          excel.CellIndex.indexByColumnRow(columnIndex: col++, rowIndex: rowIndex),
          excel.DoubleCellValue(r.salairePeriode),
        );
        rowIndex++;
      }
    }

    if (grouped.isEmpty) {
      book.rename(defaultName, 'Pointage');
      book['Pointage'].updateCell(
        excel.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0),
        excel.TextCellValue('Aucune donnée pour cette période'),
      );
    }

    final bytes = book.encode();
    if (bytes == null) return Uint8List(0);
    return Uint8List.fromList(bytes);
  }

  /// حفظ ملف Excel على القرص ثم فتحه مباشرة.
  static Future<String> saveAndOpenExcel({
    required DateTime startDate,
    required DateTime endDate,
    required List<PointageExportRow> rows,
    List<AbsenceReasonConfig>? reasonConfigs,
    bool useOcpGrid = false,
    bool singleSheet = false,
    String singleSheetName = 'Société',
    bool includeEquipeColumnInSingleSheet = true,
  }) async {
    final Uint8List bytes;
    final String name;
    if (useOcpGrid) {
      bytes = await buildOcpPointageExcel(
        startDate: startDate,
        endDate: endDate,
        rows: rows,
        reasonConfigs: reasonConfigs,
      );
      name =
          'pointage_ocp_${startDate.day}-${startDate.month}-${startDate.year}_${endDate.day}-${endDate.month}-${endDate.year}.xlsx';
    } else {
      bytes = await buildCompanyPointageExcel(
        startDate: startDate,
        endDate: endDate,
        rows: rows,
        singleSheet: singleSheet,
        singleSheetName: singleSheetName,
        includeEquipeColumnInSingleSheet: includeEquipeColumnInSingleSheet,
      );
      name =
          'pointage_${startDate.day}-${startDate.month}-${startDate.year}_${endDate.day}-${endDate.month}-${endDate.year}.xlsx';
    }
    return _saveAndOpen(bytes, name);
  }

  // ═══════════════════════════════════════════════════════════════════════
  // حفظ + فتح ملف عام
  // ═══════════════════════════════════════════════════════════════════════

  static Future<String> _saveAndOpen(Uint8List bytes, String fileName) async {
    if (kIsWeb) return fileName;

    Directory dir;
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      dir = await getDownloadsDirectory() ??
          await getApplicationDocumentsDirectory();
    } else {
      dir = await getApplicationDocumentsDirectory();
    }
    final filePath = '${dir.path}${Platform.pathSeparator}$fileName';
    final file = File(filePath);
    await file.writeAsBytes(bytes);

    try {
      if (Platform.isWindows) {
        await Process.run('cmd', ['/c', 'start', '', filePath]);
      } else if (Platform.isMacOS) {
        await Process.run('open', [filePath]);
      } else if (Platform.isLinux) {
        await Process.run('xdg-open', [filePath]);
      }
    } catch (_) {
      // الملف محفوظ حتى لو لم يُفتح
    }
    return filePath;
  }

  /// Canonical day key: midnight of the given date, ignoring time component.
  static DateTime _dayKey(DateTime dt) {
    return DateTime(dt.year, dt.month, dt.day);
  }

  static bool _isPaidAbsenceByReason(
    String? absenceReason,
    List<AbsenceReasonConfig>? reasonConfigs,
  ) {
    return absenceReason != null &&
        !isAbsenceReasonDeductFromSalary(absenceReason, reasonConfigs);
  }

  static List<PointageExportRow> computeExcelRows({
    required DateTime startDate,
    required DateTime endDate,
    required List<({String id, String cin, String nom, String poste, String equipeName, String? equipeId, double salaireNet})> employees,
    required List<PointageRecord> records,
    List<AbsenceReasonConfig>? reasonConfigs,
    bool Function(DateTime date, String equipeId)? isRestDay,
    /// إذا true: الحضور لا يُحسب إلا إذا كان الدخول والخروج مؤكدين.
    /// غير المؤكدين يُحوّلون تلقائيًا إلى غياب في الـ Excel.
    bool requireConfirmedEntryExit = false,
    /// قائمة سجلات الساعات الإضافية (overtime_assignments) لإضافتها لكل موظف.
    List<OvertimeAssignment>? overtimeAssignments,
    Map<String, String>? ocpExcelSegmentByEmployeId,
    Map<String, bool>? ocpForceSalleControleByEmployeId,
  }) {
    final start = _dayKey(startDate);
    final end = _dayKey(endDate);
    final days = <DateTime>[];
    final totalDays = end.difference(start).inDays + 1;
    for (int i = 0; i < totalDays; i++) {
      days.add(start.add(Duration(days: i)));
    }

    final recordsByEmploye = <String, List<PointageRecord>>{};
    for (final r in records) {
      recordsByEmploye.putIfAbsent(r.employeId, () => []).add(r);
    }

    // تجميع overtime_assignments لكل موظف (الحاضرون فقط المُقفلون أو المنتهون)
    final overtimeByEmploye = <String, List<OvertimeAssignment>>{};
    if (overtimeAssignments != null) {
      for (final ot in overtimeAssignments) {
        if (ot.attendanceStatus == OvertimeAttendanceStatus.present &&
            (ot.finished || ot.locked)) {
          overtimeByEmploye.putIfAbsent(ot.employeId, () => []).add(ot);
        }
      }
    }


    final rows = <PointageExportRow>[];
    for (final emp in employees) {
      final empRecords = recordsByEmploye[emp.id] ?? [];
      final byDay = <DateTime, List<PointageRecord>>{};
      for (final r in empRecords) {
        byDay.putIfAbsent(_dayKey(r.date), () => []).add(r);
      }

      int daysWorked = 0;
      int daysAbsentCount = 0;
      int restDaysCount = 0;
      double totalHours = 0;
      double overtimeHours = 0;
      final hoursByDay = <DateTime, String>{};
      final dayStatusByDay = <DateTime, String>{};
      final absenceReasonIdByDay = <DateTime, String?>{};

      // جمع ساعات overtime_assignments للموظف
      final empOvertimes = overtimeByEmploye[emp.id] ?? [];
      final overtimeByDay = <DateTime, double>{};
      for (final ot in empOvertimes) {
        final key = _dayKey(ot.date);
        overtimeByDay[key] = (overtimeByDay[key] ?? 0) + ot.overtimeMinutes / 60.0;
      }

      for (final d in days) {
        if (emp.equipeId != null && isRestDay != null && isRestDay(d, emp.equipeId!)) {
          hoursByDay[d] = 'repos';
          dayStatusByDay[d] = 'rest';
          restDaysCount++;
          continue;
        }

        final dayRecords = byDay[d] ?? const <PointageRecord>[];

        // Formation (admin final) : take precedence for the day marker.
        PointageRecord? trainingRecord;
        for (final r in dayRecords) {
          if (r.adminFinalStatus == AttendanceStatus.training) {
            trainingRecord = r;
            break;
          }
        }

        if (trainingRecord != null) {
          daysWorked++;
          totalHours += hoursPerDay;
          // If a departure overtime was also recorded on some record(s), include it.
          for (final r in dayRecords) {
            if (r.departureStatus == DepartureStatus.finished) {
              overtimeHours += (r.overtimeMinutes ?? 0) / 60.0;
            }
          }
          hoursByDay[d] = 'F';
          dayStatusByDay[d] = 'formation';

        } else {
          bool hasAnyFinalPresent = false;
          bool hasNaturalHours = false; // natural 8h
          double otForDay = 0;

          // If there is an OvertimeAssignment for this employee on this day,
          // skip PointageRecord.overtimeMinutes to avoid double-counting.
          final hasOtAssignment = (overtimeByDay[d] ?? 0) > 0;

          for (final r in dayRecords) {
            final hasConfirmedEntryExit = r.arrivalMarkedAt != null &&
                r.departureMarkedAt != null &&
                r.departureStatus == DepartureStatus.finished;
            // Règle principale : statut final de présence.
            var canCountAsPresent = r.isFinalPresent &&
                (!requireConfirmedEntryExit || hasConfirmedEntryExit);
            // Fallback élargi : couvre tous les signaux de présence réels
            // (chef seul, driver seul, status direct, leave non confirmé par admin, etc.)
            if (!canCountAsPresent && !requireConfirmedEntryExit) {
              canCountAsPresent =
                  // Statut direct sur le document
                  r.status == AttendanceStatus.present ||
                  r.status == AttendanceStatus.training ||
                  r.status == AttendanceStatus.leave ||
                  // Chef a marqué présent (même sans driver)
                  r.chefStatus == ChefPointageStatus.present ||
                  // Driver a marqué présent ou en véhicule (même sans chef)
                  r.driverStatus == DriverPointageStatus.present ||
                  r.driverStatus == DriverPointageStatus.enVehicule ||
                  // Override admin
                  r.adminFinalStatus == AttendanceStatus.present ||
                  r.adminFinalStatus == AttendanceStatus.training ||
                  r.adminFinalStatus == AttendanceStatus.leave;
            }
            if (canCountAsPresent) {
              hasAnyFinalPresent = true;
              if (!r.tempAssigned) {
                hasNaturalHours = true;
              }
            }
            if (!hasOtAssignment &&
                r.departureStatus == DepartureStatus.finished &&
                (r.overtimeMinutes ?? 0) > 0) {
              otForDay += r.overtimeMinutes! / 60.0;
            }
          }

          final hasLeaveDay = dayRecords.any((r) =>
              r.adminFinalStatus == AttendanceStatus.leave ||
              r.status == AttendanceStatus.leave);

          final anyFullAttendanceDay = dayRecords.any((r) {
            if (r.adminFinalStatus == AttendanceStatus.leave || r.status == AttendanceStatus.leave) {
              return false;
            }
            return r.arrivalMarkedAt != null && r.departureStatus == DepartureStatus.finished;
          });

          final anyPendingExitOnly = !hasLeaveDay &&
              dayRecords.any((r) {
                if (r.adminFinalStatus == AttendanceStatus.training) return false;
                if (r.arrivalMarkedAt == null || r.departureStatus == DepartureStatus.finished) {
                  return false;
                }
                return r.driverStatus == DriverPointageStatus.present ||
                    r.driverStatus == DriverPointageStatus.enVehicule ||
                    r.chefStatus == ChefPointageStatus.present ||
                    r.adminFinalStatus == AttendanceStatus.present;
              });

          // Entrée enregistrée mais pas de sortie confirmée : pas d’heures / jour payé ; cellule explicite.
          if (anyPendingExitOnly && !anyFullAttendanceDay) {
            hoursByDay[d] = 'Att. sortie';
            dayStatusByDay[d] = 'pending_exit';
          } else if (hasAnyFinalPresent) {
            // Congé (leave) : cellule bleue foncée 'G', compte comme jour travaillé.
            final hasLeave = hasLeaveDay;
            daysWorked++;
            if (hasNaturalHours) totalHours += hoursPerDay;
            overtimeHours += otForDay;
            hoursByDay[d] = hasLeave ? 'G' : 'P';
            dayStatusByDay[d] = hasLeave ? 'leave' : 'present';
          } else {
            final r = dayRecords.isNotEmpty ? dayRecords.first : null;
            // Absence avec raison explicite : vérifier si elle est payée.
            final absReason = r?.absenceReason ??
                (r?.chefStatus == ChefPointageStatus.absent ? r?.absenceReason : null);
            final isPaidAbsence = absReason != null &&
                !isAbsenceReasonDeductFromSalary(absReason, reasonConfigs);
            // Paid absence stays an absence in the grid (A) but keeps payable hours.
            hoursByDay[d] = 'A';
            dayStatusByDay[d] = isPaidAbsence ? 'paid_absence' : 'absent';
            daysAbsentCount++;
            if (absReason != null) {
              absenceReasonIdByDay[d] = absReason;
              if (isPaidAbsence) totalHours += hoursPerDay;
            }
          }
        }

        // Overtime assignments: colonne dédiée uniquement (pas d'affichage dans la cellule du jour)
        final dayOtHours = overtimeByDay[d] ?? 0;
        if (dayOtHours > 0) {
          overtimeHours += dayOtHours;
        }
      }

      final daysAbsent = daysAbsentCount.clamp(0, days.length);
      final plannedShifts = (days.length - restDaysCount).clamp(0, days.length);
      final payableDays = totalHours / hoursPerDay;
      final periodBaseDays = (days.length - restDaysCount).clamp(1, days.length);
      final salairePeriode = emp.salaireNet * (payableDays / periodBaseDays);
      rows.add(PointageExportRow(
        employeId: emp.id,
        employeCin: emp.cin,
        employeNom: emp.nom,
        poste: emp.poste,
        equipeName: emp.equipeName,
        equipeId: emp.equipeId,
        orgTypeLabel: _orgTypeLabel(emp.equipeId),
        daysWorked: daysWorked,
        plannedShifts: plannedShifts,
        daysAbsent: daysAbsent,
        totalHours: totalHours,
        overtimeHours: overtimeHours,
        salaireNet: emp.salaireNet,
        salairePeriode: double.parse(salairePeriode.toStringAsFixed(2)),
        hoursByDay: hoursByDay,
        dayStatusByDay: dayStatusByDay,
        absenceReasonIdByDay: absenceReasonIdByDay,
        ocpExcelSegment: () {
          final raw = (ocpExcelSegmentByEmployeId?[emp.id] ?? '').trim();
          if (raw.isEmpty || !OcpExcelSegmentCode.allCodes.contains(raw)) return '';
          return raw;
        }(),
        ocpForceSalleControle: ocpForceSalleControleByEmployeId?[emp.id] ?? false,
      ));
    }

    return rows;
  }

  // ═══════════════════════════════════════════════════════════════════════
  // حساب صفوف Excel من snapshots المخزنة (المصدر الموثوق)
  // ═══════════════════════════════════════════════════════════════════════

  /// يبني صفوف Excel مباشرةً من [DailyEmployeeSnapshot] المخزنة عند تأكيد كل فريق.
  /// هذا المسار أسرع وأكثر دقة من إعادة جلب [PointageRecord] وتفسيرها.
  static List<PointageExportRow> computeExcelRowsFromSnapshots({
    required DateTime startDate,
    required DateTime endDate,
    required List<({String id, String cin, String nom, String poste, String equipeName, String? equipeId, double salaireNet})> employees,
    required List<DailyEmployeeSnapshot> snapshots,
    List<AbsenceReasonConfig>? reasonConfigs,
    bool Function(DateTime date, String equipeId)? isRestDay,
    List<OvertimeAssignment>? overtimeAssignments,
    Map<String, String>? ocpExcelSegmentByEmployeId,
    Map<String, bool>? ocpForceSalleControleByEmployeId,
  }) {
    final start = _dayKey(startDate);
    final end = _dayKey(endDate);
    final days = <DateTime>[];
    final totalDays = end.difference(start).inDays + 1;
    for (int i = 0; i < totalDays; i++) {
      days.add(start.add(Duration(days: i)));
    }

    // تجميع snapshots لكل موظف حسب اليوم
    // المفتاح: employeId → (dayKey → snapshot)
    final snapshotsByEmp = <String, Map<DateTime, DailyEmployeeSnapshot>>{};
    for (final s in snapshots) {
      final dayK = _dayKey(s.date);
      snapshotsByEmp.putIfAbsent(s.employeId, () => <DateTime, DailyEmployeeSnapshot>{})[dayK] = s;
    }

    // تجميع overtime_assignments لكل موظف
    final overtimeByEmploye = <String, Map<DateTime, double>>{};
    if (overtimeAssignments != null) {
      for (final ot in overtimeAssignments) {
        if (ot.attendanceStatus == OvertimeAttendanceStatus.present &&
            (ot.finished || ot.locked)) {
          final dayK = _dayKey(ot.date);
          final empOt = overtimeByEmploye.putIfAbsent(ot.employeId, () => <DateTime, double>{});
          empOt[dayK] = (empOt[dayK] ?? 0) + ot.overtimeMinutes / 60.0;
        }
      }
    }

    final rows = <PointageExportRow>[];
    for (final emp in employees) {
      final empSnaps = snapshotsByEmp[emp.id] ?? {};
      final empOtByDay = overtimeByEmploye[emp.id] ?? {};

      int daysWorked = 0;
      int daysAbsentCount = 0;
      int restDaysCount = 0;
      double totalHours = 0;
      double overtimeHours = 0;
      final hoursByDay = <DateTime, String>{};
      final dayStatusByDay = <DateTime, String>{};
      final absenceReasonIdByDay = <DateTime, String?>{};

      for (final d in days) {
        // يوم راحة
        if (emp.equipeId != null && isRestDay != null && isRestDay(d, emp.equipeId!)) {
          hoursByDay[d] = 'repos';
          dayStatusByDay[d] = 'rest';
          restDaysCount++;
          // ساعات إضافية في يوم الراحة
          final dayOt = empOtByDay[d] ?? 0;
          if (dayOt > 0) overtimeHours += dayOt;
          continue;
        }

        final snap = empSnaps[d];
        final dayOt = empOtByDay[d] ?? 0;

        if (snap == null) {
          // No confirmed snapshot for this day: keep neutral marker (not auto-absent).
          hoursByDay[d] = '-';
          dayStatusByDay[d] = '';
        } else {
          switch (snap.status) {
            case 'present':
              daysWorked++;
              totalHours += hoursPerDay;
              overtimeHours += dayOt;
              hoursByDay[d] = 'P';
              dayStatusByDay[d] = 'present';
            case 'formation':
              daysWorked++;
              totalHours += hoursPerDay;
              overtimeHours += dayOt;
              hoursByDay[d] = 'F';
              dayStatusByDay[d] = 'formation';
            case 'leave':
              daysWorked++;
              totalHours += hoursPerDay;
              overtimeHours += dayOt;
              hoursByDay[d] = 'G';
              dayStatusByDay[d] = 'leave';
            case 'paid_absence':
              final isPaidByReason =
                  _isPaidAbsenceByReason(snap.absenceReason, reasonConfigs);
              daysAbsentCount++;
              hoursByDay[d] = 'A';
              dayStatusByDay[d] = isPaidByReason ? 'paid_absence' : 'absent';
              if (isPaidByReason) {
                totalHours += hoursPerDay;
              }
              if (snap.absenceReason != null) {
                absenceReasonIdByDay[d] = snap.absenceReason;
              }
            case 'rest':
              hoursByDay[d] = 'repos';
              dayStatusByDay[d] = 'rest';
              restDaysCount++;
            default: // 'absent' أو أي قيمة أخرى
              final absReason = snap.absenceReason;
              final isPaid = _isPaidAbsenceByReason(absReason, reasonConfigs);
              if (isPaid) {
                totalHours += hoursPerDay;
                daysAbsentCount++;
                hoursByDay[d] = 'A';
                dayStatusByDay[d] = 'paid_absence';
                absenceReasonIdByDay[d] = absReason;
              } else {
                daysAbsentCount++;
                hoursByDay[d] = 'A';
                dayStatusByDay[d] = 'absent';
                if (absReason != null) absenceReasonIdByDay[d] = absReason;
              }
          }
        }
      }

      final daysAbsent = daysAbsentCount.clamp(0, days.length);
      final plannedShifts = (days.length - restDaysCount).clamp(0, days.length);
      final payableDays = totalHours / hoursPerDay;
      final periodBaseDays = (days.length - restDaysCount).clamp(1, days.length);
      final salairePeriode = emp.salaireNet * (payableDays / periodBaseDays);

      rows.add(PointageExportRow(
        employeId: emp.id,
        employeCin: emp.cin,
        employeNom: emp.nom,
        poste: emp.poste,
        equipeName: emp.equipeName,
        equipeId: emp.equipeId,
        orgTypeLabel: _orgTypeLabel(emp.equipeId),
        daysWorked: daysWorked,
        plannedShifts: plannedShifts,
        daysAbsent: daysAbsent,
        totalHours: totalHours,
        overtimeHours: overtimeHours,
        salaireNet: emp.salaireNet,
        salairePeriode: double.parse(salairePeriode.toStringAsFixed(2)),
        hoursByDay: hoursByDay,
        dayStatusByDay: dayStatusByDay,
        absenceReasonIdByDay: absenceReasonIdByDay,
        ocpExcelSegment: () {
          final raw = (ocpExcelSegmentByEmployeId?[emp.id] ?? '').trim();
          if (raw.isEmpty || !OcpExcelSegmentCode.allCodes.contains(raw)) return '';
          return raw;
        }(),
        ocpForceSalleControle: ocpForceSalleControleByEmployeId?[emp.id] ?? false,
      ));
    }

    return rows;
  }

  static String _orgTypeLabel(String? equipeId) {
    final id = (equipeId ?? '').trim();
    if (id.isEmpty || id == 'hors_equipe') return 'Hors équipe';
    if (id.startsWith('distribution:')) return 'Distribution';
    if (id.startsWith('groupe:')) return 'Groupe';
    return 'Équipe';
  }

  static String _weekdayNameFr(int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return 'Lundi';
      case DateTime.tuesday:
        return 'Mardi';
      case DateTime.wednesday:
        return 'Mercredi';
      case DateTime.thursday:
        return 'Jeudi';
      case DateTime.friday:
        return 'Vendredi';
      case DateTime.saturday:
        return 'Samedi';
      case DateTime.sunday:
        return 'Dimanche';
      default:
        return '';
    }
  }
}
