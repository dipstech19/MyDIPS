import 'dart:io';
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

class PointageExportRow {
  final String employeId;
  final String employeNom;
  final String equipeName;
  final int daysWorked;
  final int daysAbsent;
  final double totalHours;
  final double overtimeHours;
  final Map<DateTime, String> hoursByDay;
  /// لكل يوم غياب، معرف السبب (للتلوين في Excel).
  final Map<DateTime, String?> absenceReasonIdByDay;

  const PointageExportRow({
    required this.employeId,
    required this.employeNom,
    required this.equipeName,
    required this.daysWorked,
    required this.daysAbsent,
    required this.totalHours,
    required this.overtimeHours,
    required this.hoursByDay,
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
    required List<String> presentNames,
    required List<String> absentNames,
    List<String?>? absentReasons,
    required String signatureLabel,
    String? personName,
    String? equipeName,
  }) async {
    final logo = await _loadLogo();
    final pdf = pw.Document();
    final now = DateTime.now();

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
          if (equipeName != null && equipeName.isNotEmpty)
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 4),
              child: pw.Text(
                equipeName,
                style: const pw.TextStyle(fontSize: 12),
              ),
            ),
          if (personName != null && personName.isNotEmpty)
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 2),
              child: pw.Text(
                'Responsable: $personName',
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
          _buildPresenceTable(presentNames, absentNames, absentReasons ?? List.filled(absentNames.length, null)),
          pw.SizedBox(height: 8),
          pw.Text(
            'Présents: ${presentNames.length}    Absents: ${absentNames.length}',
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
                border: pw.Border(bottom: pw.BorderSide(width: 0.5))),
            child: pw.SizedBox(height: 1),
          ),
        ],
      ),
    );

    return pdf.save();
  }

  /// جدول واحد يحتوي على كل الأسماء مع خانة حاضر/غائب وسبب الغياب.
  static pw.Widget _buildPresenceTable(
    List<String> presentNames,
    List<String> absentNames,
    List<String?> absentReasons,
  ) {
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
          _presenceCell('Présent', header: true, align: pw.TextAlign.center),
          _presenceCell('Absent', header: true, align: pw.TextAlign.center),
          _presenceCell('Raison absence', header: true),
        ],
      ),
    );

    int index = 1;
    for (final name in presentNames) {
      rows.add(
        pw.TableRow(
          children: [
            _presenceCell('$index', align: pw.TextAlign.center),
            _presenceCell(name),
            _presenceCell('X', align: pw.TextAlign.center),
            _presenceCell('', align: pw.TextAlign.center),
            _presenceCell(''),
          ],
        ),
      );
      index++;
    }
    for (int i = 0; i < absentNames.length; i++) {
      final reason = i < absentReasons.length ? getAbsenceReasonLabel(absentReasons[i]) : '';
      rows.add(
        pw.TableRow(
          children: [
            _presenceCell('$index', align: pw.TextAlign.center),
            _presenceCell(absentNames[i]),
            _presenceCell('', align: pw.TextAlign.center),
            _presenceCell('X', align: pw.TextAlign.center),
            _presenceCell(reason),
          ],
        ),
      );
      index++;
    }
    if (presentNames.isEmpty && absentNames.isEmpty) {
      rows.add(
        pw.TableRow(
          children: [
            _presenceCell('-', align: pw.TextAlign.center),
            _presenceCell('Aucune donnée'),
            _presenceCell('', align: pw.TextAlign.center),
            _presenceCell('', align: pw.TextAlign.center),
            _presenceCell(''),
          ],
        ),
      );
    }

    return pw.Table(
      border: pw.TableBorder.all(width: 0.3),
      columnWidths: {
        0: const pw.FixedColumnWidth(24),
        1: const pw.FlexColumnWidth(2),
        2: const pw.FixedColumnWidth(45),
        3: const pw.FixedColumnWidth(45),
        4: const pw.FlexColumnWidth(2),
      },
      defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
      children: rows,
    );
  }

  static pw.Widget _presenceCell(
    String text, {
    bool header = false,
    pw.TextAlign align = pw.TextAlign.left,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 10,
          fontWeight: header ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
        textAlign: align,
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
    required List<({String equipeName, List<String> presentNames, List<String> absentNames, List<String?> absentReasons})> equipes,
  }) async {
    if (equipes.isEmpty) return Uint8List(0);
    final logo = await _loadLogo();
    final now = DateTime.now();
    final pdf = pw.Document();

    for (final eq in equipes) {
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
            if (eq.equipeName.isNotEmpty)
              pw.Padding(
                padding: const pw.EdgeInsets.only(top: 4),
                child: pw.Text(eq.equipeName, style: const pw.TextStyle(fontSize: 12)),
              ),
            if (personName != null && personName.isNotEmpty)
              pw.Padding(
                padding: const pw.EdgeInsets.only(top: 2),
                child: pw.Text(
                  'Responsable: $personName',
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
            _buildPresenceTable(eq.presentNames, eq.absentNames, eq.absentReasons),
            pw.SizedBox(height: 8),
            pw.Text(
              'Présents: ${eq.presentNames.length}    Absents: ${eq.absentNames.length}',
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
    required List<({String equipeName, List<String> presentNames, List<String> absentNames, List<String?> absentReasons})> equipes,
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
    required List<String> absentNames,
    List<String?>? absentReasons,
    required String signatureLabel,
    String? personName,
    String? equipeName,
  }) async {
    final bytes = await buildDailyReportPdf(
      date: date,
      title: title,
      presentNames: presentNames,
      absentNames: absentNames,
      absentReasons: absentReasons,
      signatureLabel: signatureLabel,
      personName: personName,
      equipeName: equipeName,
    );
    final safeName = (equipeName ?? 'rapport')
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
    final start = DateTime(startDate.year, startDate.month, startDate.day);
    final end = DateTime(endDate.year, endDate.month, endDate.day);
    final days = <DateTime>[];
    for (var d = start; !d.isAfter(end); d = d.add(const Duration(days: 1))) {
      days.add(d);
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
        excel.TextCellValue('Employe'),
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
      void _setHeader(String label) {
        final idx =
            excel.CellIndex.indexByColumnRow(columnIndex: col++, rowIndex: headerRow);
        sheet.updateCell(idx, excel.TextCellValue(label));
        sheet.cell(idx).cellStyle = headerStyle;
      }

      _setHeader('Jours travailles');
      _setHeader('Jours absents');
      _setHeader('Total heures');
      _setHeader('Heures sup.');
      _setHeader('Total');

      // بيانات الموظفين + تنسيق خلايا الأيام
      int rowIndex = headerRow + 1;
      for (final r in teamRows) {
        col = 0;
        sheet.updateCell(
            excel.CellIndex.indexByColumnRow(columnIndex: col++, rowIndex: rowIndex),
            excel.TextCellValue(r.employeNom));
        int dayCol = 1;
        for (final d in days) {
          final val = r.hoursByDay[d] ?? '-';
          final cellIndex = excel.CellIndex.indexByColumnRow(columnIndex: dayCol, rowIndex: rowIndex);
          sheet.updateCell(cellIndex, excel.TextCellValue(val));
          // تلوين حسب الحالة:
          // - "repos" (راحة): رمادي
          // - "✓" (حضور): أخضر
          // - "x" أو "x ..." (غياب): أحمر
          final baseStyle = excel.CellStyle(
            horizontalAlign: excel.HorizontalAlign.Center,
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

          final cell = sheet.cell(cellIndex);
          cell.cellStyle = baseStyle;
          dayCol++;
          col = dayCol;
        }
        sheet.updateCell(
            excel.CellIndex.indexByColumnRow(columnIndex: col++, rowIndex: rowIndex),
            excel.IntCellValue(r.daysWorked));
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

  static List<PointageExportRow> computeExcelRows({
    required DateTime startDate,
    required DateTime endDate,
    required List<({String id, String nom, String equipeName, String? equipeId})> employees,
    required List<PointageRecord> records,
    List<AbsenceReasonConfig>? reasonConfigs,
    bool Function(DateTime date, String equipeId)? isRestDay,
  }) {
    final start = DateTime(startDate.year, startDate.month, startDate.day);
    final end = DateTime(endDate.year, endDate.month, endDate.day);
    final days = <DateTime>[];
    for (var d = start; !d.isAfter(end); d = d.add(const Duration(days: 1))) {
      days.add(d);
    }

    final recordsByEmploye = <String, List<PointageRecord>>{};
    for (final r in records) {
      recordsByEmploye.putIfAbsent(r.employeId, () => []).add(r);
    }

    final rows = <PointageExportRow>[];
    for (final emp in employees) {
      final empRecords = recordsByEmploye[emp.id] ?? [];
      final byDate = {
        for (final r in empRecords)
          DateTime(r.date.year, r.date.month, r.date.day): r
      };

      int daysWorked = 0;
      int restDaysCount = 0;
      double totalHours = 0;
      double overtimeHours = 0;
      final hoursByDay = <DateTime, String>{};
      final absenceReasonIdByDay = <DateTime, String?>{};

      for (final d in days) {
        if (emp.equipeId != null && isRestDay != null && isRestDay(d, emp.equipeId!)) {
          hoursByDay[d] = 'repos';
          restDaysCount++;
          continue;
        }
        final r = byDate[d];
        if (r != null && r.isFinalPresent) {
          daysWorked++;
          totalHours += hoursPerDay;
          final ot = (r.overtimeMinutes ?? 0) / 60.0;
          overtimeHours += ot;
          hoursByDay[d] = '✓';
        } else {
          final reasonLabel = r != null ? getAbsenceReasonLabel(r.absenceReason, reasonConfigs) : '';
          hoursByDay[d] = reasonLabel.isEmpty ? 'x' : 'x $reasonLabel';
          if (r != null && r.absenceReason != null) {
            absenceReasonIdByDay[d] = r.absenceReason;
            if (!isAbsenceReasonDeductFromSalary(r.absenceReason, reasonConfigs)) {
              totalHours += hoursPerDay;
            }
          }
        }
      }

      final daysAbsent = (days.length - restDaysCount - daysWorked).clamp(0, days.length);
      rows.add(PointageExportRow(
        employeId: emp.id,
        employeNom: emp.nom,
        equipeName: emp.equipeName,
        daysWorked: daysWorked,
        daysAbsent: daysAbsent,
        totalHours: totalHours,
        overtimeHours: overtimeHours,
        hoursByDay: hoursByDay,
        absenceReasonIdByDay: absenceReasonIdByDay,
      ));
    }

    return rows;
  }
}
