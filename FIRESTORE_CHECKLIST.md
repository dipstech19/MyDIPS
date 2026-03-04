# التحقق من حفظ الموظفين في Firebase

إذا لم تُضف بيانات الموظف الجديد إلى قاعدة البيانات، تحقق من التالي:

---

## 1. تشغيل التطبيق على **Android** أو **Windows**

- تم تفعيل Firebase لـ **Windows** (نفس مشروع dips-management)، لذا يمكنك إضافة الموظفين من سطح المكتب أو من Android.
- إذا ظهرت الرسالة البرتقالية « Données en ligne indisponibles »:
  - تأكد من نشر **قواعد Firestore** (الخطوة 3 أدناه).
  - أعد تشغيل التطبيق: `flutter run -d windows` أو `flutter run -d android`.

---

## 2. تفعيل Firestore في مشروع dips-management

1. ادخل إلى [Firebase Console](https://console.firebase.google.com/) → مشروع **dips-management**.
2. من القائمة: **Build** → **Firestore Database**.
3. إذا لم يكن قد تم إنشاء قاعدة:
   - **Create database** → اختر الموقع (مثلاً europe-west1) → **Next**.
   - اختر **Start in test mode** (أو Production ثم تعديل القواعد يدوياً) → **Enable**.

---

## 3. قواعد الأمان (Security Rules)

1. في Firebase Console → **Firestore Database** → تبويب **Rules**.
2. يجب أن تسمح القواعد بالكتابة على المجموعات `employes` و `equipes`.
3. انسخ محتوى الملف **`firestore.rules`** من المشروع (القسمين `employes` و `equipes` مع `allow read, write: if true;`) والصقه في المحرر ثم **Publish**.

مثال صحيح:
```
match /employes/{docId} {
  allow read, write: if true;
}
match /equipes/{docId} {
  allow read, write: if true;
}
```

إذا كانت القواعد ترفض الكتابة، ستظهر رسالة حمراء عند الحفظ: « Refusé par Firestore. Vérifiez les règles... ».

---

## 4. ملف google-services.json على Android

- تأكد أن **android/app/google-services.json** من مشروع **dips-management** (وليس مشروع قديم).
- بعد أي تغيير في المشروع أو الملف: `flutter clean` ثم `flutter pub get` ثم `flutter run -d android`.

---

## ملخص

| الخطوة | ماذا تفعل |
|--------|-----------|
| 1 | تشغيل التطبيق على **Android** (ليس Windows) |
| 2 | إنشاء قاعدة Firestore في مشروع dips-management إن لم تكن موجودة |
| 3 | نشر قواعد تسمح بالقراءة/الكتابة لـ employes و equipes |
| 4 | التأكد من google-services.json الصحيح ثم إعادة البناء |

بعد ذلك اضغط **Enregistrer** في نموذج الموظف الجديد — يجب أن تظهر رسالة خضراء « Employé ajouté. » ويظهر الموظف في القائمة وفي Firebase Console (Firestore → employes).
