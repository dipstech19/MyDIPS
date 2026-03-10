# Checklist Firebase — DIPS Management

## 1. المجموعات (Collections) في Firestore — متطابقة مع القواعد

| المجموعة   | الاستخدام في التطبيق              | القواعد (firestore.rules) |
|------------|-----------------------------------|----------------------------|
| `employes` | العمال — قراءة/كتابة/تحديث/حذف   | ✅ `match /employes/{docId}` |
| `equipes`  | الفرق — قراءة/كتابة/تحديث/حذف     | ✅ `match /equipes/{docId}`  |
| `postes`   | المناصب — من Paramètres > Postes  | ✅ `match /postes/{docId}`   |
| `admins`   | الإداريون — من Paramètres         | ✅ `match /admins/{docId}`   |

كل البيانات التي يحفظها التطبيق تذهب إلى هذه المجموعات ولا يوجد تخزين محلي بديل للـ production.

---

## 2. تهيئة التطبيق

- **main.dart**: يتم استدعاء `Firebase.initializeApp()` عند بدء التطبيق (مع `try/catch` لعدم كسر التشغيل على منصات غير مضبوطة).
- **Providers**: `EmployeesProvider`, `PostesProvider`, `AdminsProvider` يتصلون بـ Firestore عند توفر Firebase ويستخدمون `firebaseAvailable` للتحقق.

---

## 3. Android — تشغيل التطبيق مع Firebase

تم إعداد المشروع لاستخدام Firebase على Android:

1. **إضافة الـ plugin** (تمت):
   - في `android/settings.gradle.kts`: إضافة `com.google.gms.google-services`
   - في `android/app/build.gradle.kts`: تطبيق الـ plugin

2. **ملف الإعداد**:
   - ضع ملف **`google-services.json`** (الذي تحمله من Firebase Console) داخل المجلد **`android/app/`** (وليس داخل `android/` فقط).
   - من Firebase Console: Project settings → Your apps → Android app → تحميل `google-services.json`.

3. **نشر قواعد Firestore**:
   - Firebase Console → Firestore Database → Règles → **Publier**
   - أو من الطرفية: `firebase deploy --only firestore:rules`

4. **بناء وتشغيل على Android**:
   ```bash
   flutter clean
   flutter pub get
   flutter run
   ```
   (اختر جهاز أو محاكي Android.)

---

## 4. ملخص التوافق

- **البيانات**: كل المعطيات (عمال، فرق، مناصب، إداريون) مرتبطة بـ Firestore ومتكافئة مع القواعد.
- **Android**: بعد وضع `google-services.json` في `android/app/` ونشر القواعد، التطبيق يعمل على Android مع قراءة/كتابة حقيقية من/إلى Firebase.
