// توليد أيقونة التطبيق من الشعار (Windows + Android).
// تشغيل من جذر المشروع: dart run tool/generate_windows_icon.dart
import 'dart:io';
import 'package:image/image.dart' as img;

void main() async {
  final logoPath = 'assets/images/dips_logo.png';
  final logoFile = File(logoPath);
  if (!await logoFile.exists()) {
    print('ERROR: $logoPath not found.');
    exit(1);
  }
  final bytes = await logoFile.readAsBytes();
  final image = img.decodeImage(bytes);
  if (image == null) {
    print('ERROR: Could not decode $logoPath');
    exit(1);
  }

  // ─── Windows: app_icon.ico ───
  img.Image resized = image;
  if (image.width != 256 || image.height != 256) {
    resized = img.copyResize(image, width: 256, height: 256);
  }
  final icoBytes = img.encodeIco(resized);
  if (icoBytes != null && icoBytes.isNotEmpty) {
    final outDir = Directory('windows/runner/resources');
    if (!await outDir.exists()) await outDir.create(recursive: true);
    await File('windows/runner/resources/app_icon.ico').writeAsBytes(icoBytes);
    print('OK: windows/runner/resources/app_icon.ico');
  }

  // ─── Android: mipmap-* / ic_launcher.png ───
  const androidSizes = [
    ('mipmap-mdpi', 48),
    ('mipmap-hdpi', 72),
    ('mipmap-xhdpi', 96),
    ('mipmap-xxhdpi', 144),
    ('mipmap-xxxhdpi', 192),
  ];
  final resDir = Directory('android/app/src/main/res');
  if (await resDir.exists()) {
    for (final e in androidSizes) {
      final dir = Directory('android/app/src/main/res/${e.$1}');
      if (!await dir.exists()) await dir.create(recursive: true);
      final size = e.$2;
      final png = img.copyResize(image, width: size, height: size);
      final pngBytes = img.encodePng(png);
      if (pngBytes != null) {
        await File('${dir.path}/ic_launcher.png').writeAsBytes(pngBytes);
        print('OK: android/.../res/${e.$1}/ic_launcher.png');
      }
    }
  }
  print('Done. Rebuild the app to see the new icon.');
}
