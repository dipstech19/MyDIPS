# ربط مشروع Firebase يدوياً (dips-management)

بما أن `flutterfire configure` لا يعمل عندك، اربط المشروع **dips-management** يدوياً كالتالي.

---

## الخطوة 1: تحميل google-services.json من المشروع الجديد

1. افتح **[Firebase Console](https://console.firebase.google.com/)** وسجّل الدخول بـ **dips.tech2026@gmail.com**.
2. اختر المشروع **dips-management**.
3. اضغط على أيقونة **الإعدادات (⚙️)** بجانب "Project Overview" → **Project settings**.
4. في الأسفل تحت **"Your apps"**:
   - إذا **لم** يكن هناك تطبيق Android، اضغط **"Add app"** → أيقونة Android:
     - **Android package name:** `com.dipsmanagment.dipsmanagment` (انسخه كما هو).
     - (باقي الحقول اختيارية) ثم **Register app**.
   - بعد وجود تطبيق Android، اضغط **Download google-services.json**.
5. انسخ الملف المُحمّل إلى مشروعك محل الملف الحالي:
   - المسار في المشروع: **`android/app/google-services.json`**
   - استبدل الملف الموجود بالملف الجديد (تأكد أن اسم الملف بالضبط: `google-services.json`).

---

## الخطوة 2: تحديث firebase_options.dart

بعد أن تضع الملف الجديد في `android/app/google-services.json`، أخبرني أو افتح الملف هنا وسأحدّث لك **`lib/firebase_options.dart`** ليتوافق مع مشروع **dips-management** (بدون الاعتماد على `flutterfire configure`).

---

## ملخص

| الملف | ماذا تفعل |
|-------|------------|
| `android/app/google-services.json` | تحميله من Console لمشروع **dips-management** ووضعه في هذا المسار (استبدال الملف القديم). |
| `lib/firebase_options.dart` | سيتم تحديثه لاحقاً وفق محتوى الملف الجديد. |

**Package name للتطبيق:** `com.dipsmanagment.dipsmanagment`

بعد تنفيذ الخطوة 1، أرسل أنك انتهيت أو الصق محتوى `google-services.json` الجديد وسأعطيك محتوى `firebase_options.dart` المناسب.
