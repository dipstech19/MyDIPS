import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:excel/excel.dart' as excel;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import '../models/pointage_model.dart';
import '../models/absence_reason_config.dart';
import '../../overtime/models/overtime_model.dart';
import '../data/daily_snapshot_repository.dart';

class PointageExportRow {
  final String employeId;
  final String employeCin;
  final String employeNom;
  final String equipeName;
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

  const PointageExportRow({
    required this.employeId,
    required this.employeCin,
    required this.employeNom,
    required this.equipeName,
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
  });
}

class PointageExportService {
  static final _dateFormat = DateFormat('dd/MM/yyyy');
  static final _timeFormat = DateFormat('HH:mm');

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

  static Future<Uint8List> buildPointageExcel({
    required DateTime startDate,
    required DateTime endDate,
    required List<PointageExportRow> rows,
    List<AbsenceReasonConfig>? reasonConfigs,
  }) async {
    final start = _dayKey(startDate);
    final end = _dayKey(endDate);
    final days = <DateTime>[];
    final totalDays = end.difference(start).inDays + 1;
    for (int i = 0; i < totalDays; i++) {
      days.add(start.add(Duration(days: i)));
    }

    final book = excel.Excel.createExcel();

    // تجميع الصفوف حسب اسم الفريق
    final grouped = <String, List<PointageExportRow>>{};
    for (final r in rows) {
      grouped.putIfAbsent(r.equipeName, () => []).add(r);
    }

    bool isFirst = true;
    final defaultName = book.getDefaultSheet() ?? 'Sheet1';

    for (final entry in grouped.entries) {
      final teamName = entry.key;
      final teamRows = entry.value;

      // اسم الورقة: 30 حرف كحد أقصى (قيد Excel)
      String sheetName = teamName.length > 30
          ? teamName.substring(0, 30)
          : teamName;
      // إزالة أحرف غير مسموحة في أسماء الأوراق
      sheetName = sheetName.replaceAll(RegExp(r'[\\/*?\[\]:]'), '-');

      if (isFirst) {
        book.rename(defaultName, sheetName);
        isFirst = false;
      }

      final sheet = book[sheetName];

      // عنوان
      sheet.updateCell(
        excel.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0),
        excel.TextCellValue(
            'Rapport pointage: $teamName'),
      );
      sheet.updateCell(
        excel.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 1),
        excel.TextCellValue(
            'Du ${_dateFormat.format(start)} au ${_dateFormat.format(end)}'),
      );

      // رؤوس الأعمدة (منسّقة بشكل أوضح)
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

      sheet.updateCell(
        excel.CellIndex.indexByColumnRow(columnIndex: col++, rowIndex: headerRow),
        excel.TextCellValue('Employé'),
      );
      sheet
          .cell(excel.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: headerRow))
          .cellStyle = headerStyle;
      for (final d in days) {
        final idx =
            excel.CellIndex.indexByColumnRow(columnIndex: col++, rowIndex: headerRow);
        sheet.updateCell(idx, excel.TextCellValue(_dateFormat.format(d)));
        sheet.cell(idx).cellStyle = headerStyle;
      }
      void setHeader(String label) {
        final idx =
            excel.CellIndex.indexByColumnRow(columnIndex: col++, rowIndex: headerRow);
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

      // بيانات الموظفين + تنسيق خلايا الأيام
      int rowIndex = headerRow + 1;
      for (final r in teamRows) {
        col = 0;
        sheet.updateCell(
            excel.CellIndex.indexByColumnRow(columnIndex: col++, rowIndex: rowIndex),
            excel.TextCellValue(r.employeNom));
        int dayCol = 1;
        excel.CellStyle makeDayStyle({
          String bg = '#FFFFFF',
          String fg = '#000000',
        }) {
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
          final cellIndex = excel.CellIndex.indexByColumnRow(columnIndex: dayCol, rowIndex: rowIndex);
          final dayStatus = r.dayStatusByDay[d] ?? '';
          excel.CellStyle style;
          if (dayStatus == 'present') {
            style = makeDayStyle(bg: '#C8E6C9', fg: '#1B5E20');
          } else if (dayStatus == 'absent') {
            style = makeDayStyle(bg: '#FFCDD2', fg: '#B71C1C');
          } else if (dayStatus == 'formation') {
            style = makeDayStyle(bg: '#BBDEFB', fg: '#0D47A1');
          } else if (dayStatus == 'leave') {
            style = makeDayStyle(bg: '#0D47A1', fg: '#FFFFFF');
          } else if (dayStatus == 'paid_absence') {
            style = makeDayStyle(bg: '#FFE0B2', fg: '#E65100');
          } else if (dayStatus == 'rest') {
            style = makeDayStyle(bg: '#EEEEEE', fg: '#616161');
          } else {
            style = makeDayStyle(bg: '#FFFFFF', fg: '#000000');
          }
          // كتابة القيمة ثم تعيين style
          sheet.updateCell(cellIndex, excel.TextCellValue(val), cellStyle: style);
          dayCol++;
          col = dayCol;
        }
        sheet.updateCell(
            excel.CellIndex.indexByColumnRow(columnIndex: col++, rowIndex: rowIndex),
            excel.TextCellValue('${r.daysWorked}/${r.plannedShifts}'));
        sheet.updateCell(
            excel.CellIndex.indexByColumnRow(columnIndex: col++, rowIndex: rowIndex),
            excel.IntCellValue(r.daysAbsent));
        sheet.updateCell(
            excel.CellIndex.indexByColumnRow(columnIndex: col++, rowIndex: rowIndex),
            excel.DoubleCellValue(r.totalHours));
        sheet.updateCell(
            excel.CellIndex.indexByColumnRow(columnIndex: col++, rowIndex: rowIndex),
            excel.DoubleCellValue(r.overtimeHours));
        sheet.updateCell(
            excel.CellIndex.indexByColumnRow(columnIndex: col++, rowIndex: rowIndex),
            excel.DoubleCellValue(r.totalHours + r.overtimeHours));
        sheet.updateCell(
            excel.CellIndex.indexByColumnRow(columnIndex: col++, rowIndex: rowIndex),
            excel.DoubleCellValue(r.salaireNet));
        sheet.updateCell(
            excel.CellIndex.indexByColumnRow(columnIndex: col++, rowIndex: rowIndex),
            excel.DoubleCellValue(r.salairePeriode));
        rowIndex++;
      }
    }

    // إذا لم يكن هناك بيانات أصلاً، على الأقل ورقة واحدة
    if (grouped.isEmpty) {
      book.rename(defaultName, 'Pointage');
      final sheet = book['Pointage'];
      sheet.updateCell(
        excel.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0),
        excel.TextCellValue('Aucune donnee pour cette periode'),
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
  }) async {
    final bytes = await buildPointageExcel(
        startDate: startDate, endDate: endDate, rows: rows, reasonConfigs: reasonConfigs);
    final name =
        'pointage_${startDate.day}-${startDate.month}-${startDate.year}_${endDate.day}-${endDate.month}-${endDate.year}.xlsx';
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

  // ═══════════════════════════════════════════════════════════════════════
  // حساب صفوف Excel
  // ═══════════════════════════════════════════════════════════════════════

  /// Canonical day key: midnight of the given date, ignoring time component.
  static DateTime _dayKey(DateTime dt) {
    return DateTime(dt.year, dt.month, dt.day);
  }

  static List<PointageExportRow> computeExcelRows({
    required DateTime startDate,
    required DateTime endDate,
    required List<({String id, String cin, String nom, String equipeName, String? equipeId, double salaireNet})> employees,
    required List<PointageRecord> records,
    List<AbsenceReasonConfig>? reasonConfigs,
    bool Function(DateTime date, String equipeId)? isRestDay,
    /// إذا true: الحضور لا يُحسب إلا إذا كان الدخول والخروج مؤكدين.
    /// غير المؤكدين يُحوّلون تلقائيًا إلى غياب في الـ Excel.
    bool requireConfirmedEntryExit = false,
    /// قائمة سجلات الساعات الإضافية (overtime_assignments) لإضافتها لكل موظف.
    List<OvertimeAssignment>? overtimeAssignments,
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

          if (hasAnyFinalPresent) {
            // Congé (leave) : cellule bleue foncée 'G', compte comme jour travaillé.
            final hasLeave = dayRecords.any((r) =>
                r.adminFinalStatus == AttendanceStatus.leave ||
                r.status == AttendanceStatus.leave);
            daysWorked++;
            if (hasNaturalHours) totalHours += hoursPerDay;
            overtimeHours += otForDay;
            hoursByDay[d] = hasLeave ? 'G' : '8';
            dayStatusByDay[d] = hasLeave ? 'leave' : 'present';
          } else {
            final r = dayRecords.isNotEmpty ? dayRecords.first : null;
            // Absence avec raison explicite : vérifier si elle est payée.
            final absReason = r?.absenceReason ??
                (r?.chefStatus == ChefPointageStatus.absent ? r?.absenceReason : null);
            final isPaidAbsence = absReason != null &&
                !isAbsenceReasonDeductFromSalary(absReason, reasonConfigs);
            hoursByDay[d] = isPaidAbsence ? '8' : 'absent';
            dayStatusByDay[d] = isPaidAbsence ? 'paid_absence' : 'absent';
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

      final daysAbsent = (days.length - restDaysCount - daysWorked).clamp(0, days.length);
      final plannedShifts = (days.length - restDaysCount).clamp(0, days.length);
      final payableDays = totalHours / hoursPerDay;
      final periodBaseDays = (days.length - restDaysCount).clamp(1, days.length);
      final salairePeriode = emp.salaireNet * (payableDays / periodBaseDays);
      rows.add(PointageExportRow(
        employeId: emp.id,
        employeCin: emp.cin,
        employeNom: emp.nom,
        equipeName: emp.equipeName,
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
    required List<({String id, String cin, String nom, String equipeName, String? equipeId, double salaireNet})> employees,
    required List<DailyEmployeeSnapshot> snapshots,
    List<AbsenceReasonConfig>? reasonConfigs,
    bool Function(DateTime date, String equipeId)? isRestDay,
    List<OvertimeAssignment>? overtimeAssignments,
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
          // لا يوجد snapshot → غائب (لم يتم تأكيد الفريق هذا اليوم)
          hoursByDay[d] = 'absent';
          dayStatusByDay[d] = 'absent';
        } else {
          switch (snap.status) {
            case 'present':
              daysWorked++;
              totalHours += hoursPerDay;
              overtimeHours += dayOt;
              hoursByDay[d] = '8';
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
              daysWorked++;
              totalHours += hoursPerDay;
              hoursByDay[d] = '8';
              dayStatusByDay[d] = 'paid_absence';
              if (snap.absenceReason != null) absenceReasonIdByDay[d] = snap.absenceReason;
            case 'rest':
              hoursByDay[d] = 'repos';
              dayStatusByDay[d] = 'rest';
              restDaysCount++;
            default: // 'absent' أو أي قيمة أخرى
              final absReason = snap.absenceReason;
              final isPaid = absReason != null &&
                  !isAbsenceReasonDeductFromSalary(absReason, reasonConfigs);
              if (isPaid) {
                daysWorked++;
                totalHours += hoursPerDay;
                hoursByDay[d] = '8';
                dayStatusByDay[d] = 'paid_absence';
                absenceReasonIdByDay[d] = absReason;
              } else {
                hoursByDay[d] = 'absent';
                dayStatusByDay[d] = 'absent';
                if (absReason != null) absenceReasonIdByDay[d] = absReason;
              }
          }
        }
      }

      final daysAbsent = (days.length - restDaysCount - daysWorked).clamp(0, days.length);
      final plannedShifts = (days.length - restDaysCount).clamp(0, days.length);
      final payableDays = totalHours / hoursPerDay;
      final periodBaseDays = (days.length - restDaysCount).clamp(1, days.length);
      final salairePeriode = emp.salaireNet * (payableDays / periodBaseDays);

      rows.add(PointageExportRow(
        employeId: emp.id,
        employeCin: emp.cin,
        employeNom: emp.nom,
        equipeName: emp.equipeName,
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
      ));
    }

    return rows;
  }
}
