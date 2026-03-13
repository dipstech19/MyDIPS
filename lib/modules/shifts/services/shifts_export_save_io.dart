import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';

Future<String> saveAndOpenExcel(Uint8List bytes, String fileName) async {
  Directory dir;
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    dir = await getDownloadsDirectory() ?? await getApplicationDocumentsDirectory();
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
  } catch (_) {}
  return filePath;
}
