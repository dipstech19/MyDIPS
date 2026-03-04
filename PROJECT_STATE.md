# حالة المشروع — كل شيء حقيقي (بدون بيانات وهمية)

## المنصات المدعومة فقط

- **Android** — التطبيق الرئيسي مع Firebase/Firestore (إضافة وعرض العمال والفرق من القاعدة).
- **Windows (سطح المكتب)** — نفس الواجهة؛ البيانات لا تُحمّل من Firebase (قوائم فارغة مع تنبيه).

لا يُستهدف iOS ولا macOS ولا Web ولا Linux.

---

## ما تم تنفيذه

### 1. إزالة كل البيانات الوهمية
- **حذف** `lib/modules/employees/data/dummy_data.dart` (قوائم العمال والفرق الوهمية).
- **EmployeesProvider**: لا يستخدم أي dummy. عند توفر Firebase ← البيانات من Firestore. عند عدم التوفر (مثلاً Windows) ← قوائم فارغة ولا يُحفظ أي إضافة/تعديل محلياً.
- **لوحة التحكم (Dashboard)**: رقم «Employés» يأتي من القاعدة الحقيقية (`EmployeesProvider.employes.length`). باقي الإحصائيات (Présents, Stock, Rapports) = 0 حتى يتم ربطها لاحقاً بمصادر حقيقية.

### 2. تسجيل الدخول (مؤقت)
- **appUsers** في `auth_model.dart` ما زالت مستخدمة للتسجيل فقط، مع تعليق واضح: استبدالها لاحقاً بـ **Firebase Authentication** مع تخزين الأدوار (directeur / chefEquipe / chauffeur).

### 3. دمج عمل المطور الآخر (فرع dev-marouane)
- **Gestion Magasin** (`lib/modules/magasin/gestion_magasin.dart`) مدمج في القائمة الجانبية:
  - **Stock** (الرتبة 3) → `GestionMagasin()`.
- **Paramètres** (`lib/modules/Paramètres/paramètres.dart`) مدمج كصفحة كاملة (إعدادات، أدمن، أمان، إلخ).
- المسار: `main_layout.dart` → استيراد واستدعاء `GestionMagasin` و `ParametresPage`.
- التنقل الموحد: لغة (FR/AR)، استجابة (موبايل/سطح مكتب)، أدوار (Directeur / Chef Équipe / Chauffeur)، Pointage و Rapport.

### 4. الربط مع Firebase (الحقيقي)
- **مشروع Firebase:** `dips-management` (الحساب: dips.tech2026@gmail.com).
- **العمال والفرق:** من Firestore فقط:
  - مجموعة `employes` — إضافة / تعديل / حذف / تغيير الحالة.
  - مجموعة `equipes` — إضافة / تعديل / حذف فريق، إضافة أعضاء.
- **العرض ديناميكي:** الاشتراك في الـ Streams، أي تحديث في Firestore يظهر فوراً في التطبيق.

### 5. عند عدم اتصال Firebase (مثلاً Windows)
- صفحة Employés تعرض تنبيهاً: «Données en ligne indisponibles. Connectez Firebase (ex: Android)...».
- القوائم فارغة؛ أزرار الإضافة/التعديل لا تُسجّل بيانات (لا تخزين محلي وهمي).

---

## هيكل التنقل الحالي

| الرتبة | القائمة (غير سائق) | الشاشة |
|--------|---------------------|--------|
| 0 | Tableau de bord | Dashboard (إحصائيات حقيقية لـ Employés) |
| 1 | Employés | EmployeesPage (Firestore) |
| 2 | Pointage | PointagePage |
| 3 | Stock | GestionMagasin (المطور الآخر) |
| 4 | Rapports | Placeholder |
| 5 | Paramètres | ParametresPage (المطور الآخر) |

**سائق:** Pointage → DriverPointagePage | Envoyer rapport → ReportPage.

---

## الخطوة التالية (اختياري)
- تفعيل **Firebase Authentication** واستبدال `appUsers` بحسابات حقيقية مع الأدوار (Firestore أو Custom Claims).
