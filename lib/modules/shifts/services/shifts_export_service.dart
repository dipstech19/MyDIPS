import 'dart:typed_data';
import 'package:excel/excel.dart' as excel;
import 'package:intl/intl.dart';
import '../models/shift_models.dart';
import 'shifts_export_save_web.dart' if (dart.library.io) 'shifts_export_save_io.dart' as save_impl;

/// تصدير planning الورديات إلى Excel لفترة (شهر / سنة / مدى مخصص).
class ShiftsExportService {
  static final _headerDateFormat = DateFormat('dd/MM/yyyy');
  static final _rowDateFormat = DateFormat('dd/MM');

  /// تسميات الورديات للإكسل (ثابتة)
  static String _shiftLabel(ShiftType s) {
    switch (s) {
      case ShiftType.morning: return 'Shift 1';
      case ShiftType.evening: return 'Shift 2';
      case ShiftType.night: return 'Shift 3';
      case ShiftType.rest: return 'Repos';
    }
  }

  /// بناء ملف Excel للجدول: صفوف = أيام، أعمدة = تاريخ + P1 + P2 + P3 + RH (أسماء الفرق).
  static Future<Uint8List> buildShiftsExcel({
    required DateTime startDate,
    required DateTime endDate,
    required List<({DateTime date, List<({String equipeId, ShiftType shift})> perEquipe})> schedule,
    required List<String> equipeNames,
    required List<String> positionHeaders,
  }) async {
    final start = DateTime(startDate.year, startDate.month, startDate.day);
    final end = DateTime(endDate.year, endDate.month, endDate.day);

    final book = excel.Excel.createExcel();
    final defaultName = book.getDefaultSheet() ?? 'Sheet1';
    book.rename(defaultName, 'Planning');
    final sheet = book['Planning'];

    // عنوان
    sheet.updateCell(
      excel.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0),
      excel.TextCellValue('Planning des shifts'),
    );
    sheet.updateCell(
      excel.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 1),
      excel.TextCellValue('Du ${_headerDateFormat.format(start)} au ${_headerDateFormat.format(end)}'),
    );

    // Legend: شرح الألوان والتوقيتات مرة واحدة أعلى الجدول.
    final legendHeaderStyle = excel.CellStyle(
      bold: true,
      horizontalAlign: excel.HorizontalAlign.Left,
    );
    final legendCellStyle = excel.CellStyle(
      horizontalAlign: excel.HorizontalAlign.Left,
      bottomBorder: excel.Border(borderStyle: excel.BorderStyle.Thin),
      topBorder: excel.Border(borderStyle: excel.BorderStyle.Thin),
      leftBorder: excel.Border(borderStyle: excel.BorderStyle.Thin),
      rightBorder: excel.Border(borderStyle: excel.BorderStyle.Thin),
    );

    // ألوان الورديات (مطابقة للنظام: أخضر، برتقالي، بنفسجي، رمادي)
    const _colorShift1 = '#C8E6C9'; // Shift 1 — أخضر فاتح
    const _colorShift2 = '#FFE0B2'; // Shift 2 — برتقالي فاتح
    const _colorShift3 = '#C5CAE9'; // Shift 3 — بنفسجي فاتح
    const _colorRepos = '#EEEEEE'; // Repos — رمادي

    sheet.updateCell(
      excel.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 3),
      excel.TextCellValue('Légende'),
    );
    sheet.cell(excel.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 3)).cellStyle =
        legendHeaderStyle;

    final legendRows = <(String name, String time, String color)>[
      ('Shift 1', '06:00-14:00', _colorShift1),
      ('Shift 2', '14:00-22:00', _colorShift2),
      ('Shift 3', '22:00-06:00', _colorShift3),
      ('Repos', '—', _colorRepos),
    ];

    for (var i = 0; i < legendRows.length; i++) {
      final row = 4 + i;
      final item = legendRows[i];
      final nIdx = excel.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row);
      final tIdx = excel.CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row);
      sheet.updateCell(nIdx, excel.TextCellValue(item.$1));
      sheet.updateCell(tIdx, excel.TextCellValue(item.$2));
      sheet.cell(nIdx).cellStyle = legendCellStyle.copyWith(
        backgroundColorHexVal: excel.ExcelColor.fromHexString(item.$3),
      );
      sheet.cell(tIdx).cellStyle = legendCellStyle;
    }

    // رؤوس الأعمدة: Date ثم Shift1, Shift2, Shift3, RH مع أسماء الفرق + لون رمادي
    const headerRow = 9;
    final headerStyle = excel.CellStyle(
      bold: true,
      horizontalAlign: excel.HorizontalAlign.Center,
      backgroundColorHex: excel.ExcelColor.fromHexString('#E0E0E0'),
      bottomBorder: excel.Border(borderStyle: excel.BorderStyle.Thin),
      topBorder: excel.Border(borderStyle: excel.BorderStyle.Thin),
      leftBorder: excel.Border(borderStyle: excel.BorderStyle.Thin),
      rightBorder: excel.Border(borderStyle: excel.BorderStyle.Thin),
    );

    final dateHeaderIndex =
        excel.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: headerRow);
    sheet.updateCell(
      dateHeaderIndex,
      excel.TextCellValue('Date'),
    );
    sheet.cell(dateHeaderIndex).cellStyle = headerStyle;

    for (var i = 0; i < 4; i++) {
      final label = (equipeNames.length > i && equipeNames[i].trim().isNotEmpty)
          ? equipeNames[i]
          : positionHeaders[i];
      final idx =
          excel.CellIndex.indexByColumnRow(columnIndex: i + 1, rowIndex: headerRow);
      sheet.updateCell(idx, excel.TextCellValue(label));
      sheet.cell(idx).cellStyle = headerStyle;
    }

    excel.CellStyle _cellStyleForShift(ShiftType shift) {
      final bg = switch (shift) {
        ShiftType.morning => _colorShift1,
        ShiftType.evening => _colorShift2,
        ShiftType.night => _colorShift3,
        ShiftType.rest => _colorRepos,
      };
      return excel.CellStyle(
        horizontalAlign: excel.HorizontalAlign.Center,
        backgroundColorHex: excel.ExcelColor.fromHexString(bg),
        bottomBorder: excel.Border(borderStyle: excel.BorderStyle.Thin),
        topBorder: excel.Border(borderStyle: excel.BorderStyle.Thin),
        leftBorder: excel.Border(borderStyle: excel.BorderStyle.Thin),
        rightBorder: excel.Border(borderStyle: excel.BorderStyle.Thin),
      );
    }

    final dateCellStyle = excel.CellStyle(
      horizontalAlign: excel.HorizontalAlign.Center,
      bottomBorder: excel.Border(borderStyle: excel.BorderStyle.Thin),
      topBorder: excel.Border(borderStyle: excel.BorderStyle.Thin),
      leftBorder: excel.Border(borderStyle: excel.BorderStyle.Thin),
      rightBorder: excel.Border(borderStyle: excel.BorderStyle.Thin),
    );

    int rowIndex = headerRow + 1;
    for (final s in schedule) {
      final dateIdx =
          excel.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex);
      sheet.updateCell(
        dateIdx,
        excel.TextCellValue(_rowDateFormat.format(s.date)),
      );
      sheet.cell(dateIdx).cellStyle = dateCellStyle;
      for (var pos = 0; pos < 4; pos++) {
        final shift = s.perEquipe.length > pos ? s.perEquipe[pos].shift : ShiftType.rest;
        final idx =
            excel.CellIndex.indexByColumnRow(columnIndex: pos + 1, rowIndex: rowIndex);
        sheet.updateCell(
          idx,
          excel.TextCellValue(_shiftLabel(shift)),
        );
        sheet.cell(idx).cellStyle = _cellStyleForShift(shift);
      }
      rowIndex++;
    }

    final bytes = book.encode();
    if (bytes == null) return Uint8List(0);
    return Uint8List.fromList(bytes);
  }

  /// حفظ الملف ثم فتحه (ويب: تحميل، سطح المكتب: حفظ في التحميلات وفتح).
  static Future<String> saveAndOpenExcel(Uint8List bytes, String fileName) async {
    if (bytes.isEmpty) return '';
    return save_impl.saveAndOpenExcel(bytes, fileName);
  }
}
