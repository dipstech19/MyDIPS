# تصدير التطبيق لـ Windows (الحاسوب)

## المتطلبات
- [Flutter SDK](https://flutter.dev) مثبت على الجهاز
- **Visual Studio 2022** (أو Build Tools) مع workload "Desktop development with C++" و **Windows 10 SDK**

## خطوات التصدير

### 1. تفعيل دعم Windows (مرة واحدة)
```bash
flutter config --enable-windows-desktop
```

### 2. بناء التطبيق
من مجلد المشروع:
```bash
flutter build windows
```

### 3. مكان الملفات بعد البناء
يُنتج البناء مجلداً جاهزاً للتشغيل:
```
build\windows\x64\runner\Release\
```

يحتوي على:
- **dipsmanagment.exe** — البرنامج الرئيسي
- **data/** — موارد التطبيق (مطلوب)
- ***.dll** — مكتبات مطلوبة للتشغيل (مثل flutter_windows.dll وملفات الإضافات)

### 4. التوزيع على أجهزة أخرى
لنقل التطبيق إلى حاسوب آخر (Windows 64-bit):
1. انسخ **المجلد بالكامل** `Release` (أو أنشئ مجلداً جديداً وانسخ كل محتوياته).
2. ضع المجلد في أي مكان (مثلاً `C:\DIPS_Managment` أو على سطح المكتب).
3. شغّل **dipsmanagment.exe** من داخل هذا المجلد.

⚠️ **مهم:** لا تنقل الملف **dipsmanagment.exe** وحده؛ يجب نقل المجلد كاملاً مع مجلد `data` وجميع ملفات `.dll` حتى يعمل التطبيق.

### 5. تشغيل من المشروع (للتطوير)
```bash
flutter run -d windows
```

---

## أيقونة التطبيق (الشعار)
التطبيق يستخدم **شعار النظام** (`assets/images/logo.png`) كأيقونة على الهاتف والحاسوب.

لتوليد الأيقونات من الشعار (مرة واحدة أو عند تغيير الشعار):
```bash
dart run tool/generate_windows_icon.dart
```
سيتم إنشاء:
- **Windows:** `windows/runner/resources/app_icon.ico`
- **Android:** `android/app/src/main/res/mipmap-*/ic_launcher.png`

بعدها أعد بناء التطبيق (`flutter build windows` أو `flutter run -d windows`) لظهور الأيقونة الجديدة.
(لأيقونات iOS يمكن لاحقاً تشغيل: `dart run flutter_launcher_icons`)

---

## إنشاء نسخة محسّنة (اختياري)
- لتحسين الأداء: البناء الحالي هو **Release** وجاهز للاستخدام.
- لتغيير اسم التطبيق أو الأيقونة: عدّل ملفات في مجلد `windows/` (مثل `Runner.rc` و `runner.exe.manifest`).
