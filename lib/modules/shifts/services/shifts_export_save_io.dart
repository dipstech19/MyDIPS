import 'dart:typed_data';
import 'dart:io' as io;
import 'package:path_provider/path_provider.dart';

Future<String> saveAndOpenExcel(Uint8List bytes, String fileName) async {
  if (bytes.isEmpty) return '';
  final dir = await getApplicationDocumentsDirectory();
  final file = io.File('${dir.path}/$fileName');
  await file.writeAsBytes(bytes);
  return file.path;
}
