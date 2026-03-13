import 'dart:typed_data';
// هذا الملف يُستورد فقط عند البناء للويب (dart.library.html)
import 'dart:html' as html;

Future<String> saveAndOpenExcel(Uint8List bytes, String fileName) async {
  final blob = html.Blob([bytes]);
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)..download = fileName;
  anchor.click();
  html.Url.revokeObjectUrl(url);
  return fileName;
}
