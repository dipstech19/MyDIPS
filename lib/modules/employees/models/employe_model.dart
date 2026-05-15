import 'package:flutter/material.dart';
import 'document_model.dart';

/// Codes stockés dans [Employe.ocpExcelSegment] pour le regroupement export pointage OCP.
class OcpExcelSegmentCode {
  OcpExcelSegmentCode._();

  static const String auto = '';
  static const String p1SychemRoUf = 'p1_sychem_ro_uf';
  static const String p1Qt = 'p1_qt';
  static const String p1SychemRemin = 'p1_sychem_remin';
  static const String p2Sychem = 'p2_sychem';
  static const String p2Ion = 'p2_ion';
  static const String p2Qt = 'p2_qt';
  static const String p3Sychem = 'p3_sychem';
  static const String p3Qt = 'p3_qt';
  static const String p3Logistique = 'p3_logistique';
  static const String p4AnimateurHse = 'p4_animateur_hse';
  static const String p5AnimationHse = 'p5_animation_hse';
  static const String p5PilotageProcess = 'p5_pilotage_process';
  static const String p5Cadre = 'p5_cadre';
  static const String p6Sychem = 'p6_sychem';
  static const String p6Qt = 'p6_qt';
  static const String p6ReminTransfert = 'p6_remin_transfert';

  static const List<String> allCodes = [
    auto,
    p1SychemRoUf,
    p1Qt,
    p1SychemRemin,
    p2Sychem,
    p2Ion,
    p2Qt,
    p3Sychem,
    p3Qt,
    p3Logistique,
    p4AnimateurHse,
    p5AnimationHse,
    p5PilotageProcess,
    p5Cadre,
    p6Sychem,
    p6Qt,
    p6ReminTransfert,
  ];

  static String labelFr(String code) {
    switch (code.trim()) {
      case p1SychemRoUf:
        return 'P1 — Sychem RO & UF';
      case p1Qt:
        return 'P1 — QT';
      case p1SychemRemin:
        return 'P1 — Sychem Remin & Transfert';
      case p2Sychem:
        return 'P2 — Sychem';
      case p2Ion:
        return 'P2 — ION';
      case p2Qt:
        return 'P2 — QT';
      case p3Sychem:
        return 'P3 — Sychem';
      case p3Qt:
        return 'P3 — QT';
      case p3Logistique:
        return 'P3 — Logistique';
      case p4AnimateurHse:
        return 'P4 — Animateur HSE';
      case p5AnimationHse:
        return 'P5 — Animation HSE';
      case p5PilotageProcess:
        return 'P5 — Pilotage process';
      case p5Cadre:
        return 'P5 — Chef zone / QHSE / Suivi perf.';
      case p6Sychem:
        return 'P6 — Sychem';
      case p6Qt:
        return 'P6 — QT';
      case p6ReminTransfert:
        return 'P6 — Remin & Transfert';
      default:
        return code.trim().isEmpty ? 'Automatique (équipe / poste)' : code;
    }
  }

  /// Bloc OCP défini manuellement dans la fiche (hors mode automatique).
  static bool hasExplicitPlacement(String raw) => raw.trim().isNotEmpty;

  /// Shift P1…P6 déduit du préfixe du code segment.
  static String shiftFromSegment(String raw) {
    final s = raw.trim().toLowerCase();
    if (s.startsWith('p1_')) return 'P1';
    if (s.startsWith('p2_')) return 'P2';
    if (s.startsWith('p3_')) return 'P3';
    if (s.startsWith('p4_')) return 'P4';
    if (s.startsWith('p5_')) return 'P5';
    if (s.startsWith('p6_')) return 'P6';
    return '';
  }

  static bool isP3Logistique(String raw) =>
      raw.trim().toLowerCase() == p3Logistique;

  /// Clés internes alignées sur [PointageExportService] (p1_ro, p1_qt, …).
  static String? toP1Bucket(String raw) {
    switch (raw.trim().toLowerCase()) {
      case p1SychemRoUf:
        return 'p1_ro';
      case p1Qt:
        return 'p1_qt';
      case p1SychemRemin:
        return 'p1_remin';
      default:
        return null;
    }
  }

  static String? toP2Bucket(String raw) {
    switch (raw.trim().toLowerCase()) {
      case p2Sychem:
        return 'p2_sychem';
      case p2Ion:
        return 'p2_ion';
      case p2Qt:
        return 'p2_qt';
      default:
        return null;
    }
  }

  static String? toP3Bucket(String raw) {
    switch (raw.trim().toLowerCase()) {
      case p3Sychem:
        return 'p3_sychem';
      case p3Qt:
        return 'p3_qt';
      case p3Logistique:
        return 'p3_logistique';
      default:
        return null;
    }
  }

  static String? toP4Bucket(String raw) {
    switch (raw.trim().toLowerCase()) {
      case p4AnimateurHse:
        return 'p4_animateur_hse';
      default:
        return null;
    }
  }

  static String? toP5Bucket(String raw) {
    switch (raw.trim().toLowerCase()) {
      case p5AnimationHse:
        return 'p5_animation_hse';
      case p5PilotageProcess:
        return 'p5_pilotage_process';
      case p5Cadre:
        return 'p5_cadre';
      default:
        return null;
    }
  }

  static String? toP6Bucket(String raw) {
    switch (raw.trim().toLowerCase()) {
      case p6Sychem:
        return 'p6_sychem';
      case p6Qt:
        return 'p6_qt';
      case p6ReminTransfert:
        return 'p6_remin';
      default:
        return null;
    }
  }
}

enum EmployeStatut { enService, quitte, enConge, enMaladie }

extension EmployeStatutExt on EmployeStatut {
  String get label {
    switch (this) {
      case EmployeStatut.enService:  return 'En service';
      case EmployeStatut.quitte:     return 'Quitté';
      case EmployeStatut.enConge:    return 'En congé';
      case EmployeStatut.enMaladie:  return 'En maladie';
    }
  }

  Color get color {
    switch (this) {
      case EmployeStatut.enService:  return Colors.green;
      case EmployeStatut.quitte:     return Colors.red;
      case EmployeStatut.enConge:    return Colors.orange;
      case EmployeStatut.enMaladie:  return Colors.blue;
    }
  }

  IconData get icon {
    switch (this) {
      case EmployeStatut.enService:  return Icons.check_circle;
      case EmployeStatut.quitte:     return Icons.cancel;
      case EmployeStatut.enConge:    return Icons.beach_access;
      case EmployeStatut.enMaladie:  return Icons.medical_services;
    }
  }
}

class Employe {
  final String id;
  final String nom;
  final String cin;
  final String telephone;
  final String telephone2;
  final String dateNaissance;
  final String adresse;
  final String email;
  final String poste;
  final String magasin;
  final String departement;
  final double salaireBase;
  final String typeContrat;
  final String dateDebut;
  final String finContrat;
  final String chefDirectId;
  final String cnss;
  final String dateCnss;
  /// بطاقة الدخول إلى الـ Site: مفعّلة أم لا
  final bool badgeActif;
  /// تاريخ انتهاء صلاحية البطاقة (صيغة نصية dd/MM/yyyy مثلاً). يمكن أن تكون فارغة.
  final String badgeExpiration;
  final EmployeStatut statut;
  final List<Document> documents;
  final String photoUrl;
  final String? _siteId;
  final double leaveDaysTaken;
  final double leaveDaysExtra;
  /// Segment OCP (export Excel pointage). Vide = déduction depuis équipe / poste.
  final String ocpExcelSegment;
  /// Traiter comme « salle de contrôle » pour la classification P1 si le libellé poste ne le contient pas.
  final bool ocpForceSalleControle;

  Employe({
    required this.id,
    required this.nom,
    required this.cin,
    required this.telephone,
    this.telephone2 = '',
    required this.dateNaissance,
    required this.adresse,
    required this.email,
    required this.poste,
    required this.magasin,
    required this.departement,
    required this.salaireBase,
    required this.typeContrat,
    required this.dateDebut,
    this.finContrat = '',
    this.chefDirectId = '',
    required this.cnss,
    required this.dateCnss,
    this.badgeActif = false,
    this.badgeExpiration = '',
    required this.statut,
    this.documents = const [],
    this.photoUrl = '',
    String? siteId,
    this.leaveDaysTaken = 0.0,
    this.leaveDaysExtra = 0.0,
    this.ocpExcelSegment = '',
    this.ocpForceSalleControle = false,
  }) : _siteId = siteId;

  /// للمراكز/المواقع — إن لم يكن معرّفاً يُستخدم 'all'
  String get siteId => _siteId ?? 'all';

  Map<String, dynamic> toMap() {
    return {
      'nom': nom,
      'cin': cin,
      'telephone': telephone,
      'telephone2': telephone2,
      'dateNaissance': dateNaissance,
      'adresse': adresse,
      'email': email,
      'poste': poste,
      'magasin': magasin,
      'departement': departement,
      'salaireBase': salaireBase,
      'typeContrat': typeContrat,
      'dateDebut': dateDebut,
      'finContrat': finContrat,
      'chefDirectId': chefDirectId,
      'cnss': cnss,
      'dateCnss': dateCnss,
      'badgeActif': badgeActif,
      'badgeExpiration': badgeExpiration,
      'statut': statut.name,
      'photoUrl': photoUrl,
      'leaveDaysTaken': leaveDaysTaken,
      'leaveDaysExtra': leaveDaysExtra,
      'ocpExcelSegment': ocpExcelSegment,
      'ocpForceSalleControle': ocpForceSalleControle,
      if (_siteId != null) 'siteId': _siteId,
      'documents': documents.map((d) => {
            'id': d.id,
            'nom': d.nom,
            'path': d.path,
            'categorie': d.categorie.name,
            'dateAjout': d.dateAjout,
            'extension': d.extension,
          }).toList(),
    };
  }

  static Employe fromMap(Map<String, dynamic> map) {
    final docs = map['documents'];
    List<Document> documentList = const [];
    if (docs is List<dynamic>) {
      documentList = docs.map((e) {
        if (e is! Map<String, dynamic>) return null;
        final m = Map<String, dynamic>.from(e);
        DocCategorie cat = DocCategorie.autre;
        final catStr = m['categorie'] as String?;
        if (catStr != null) {
          cat = DocCategorie.values.firstWhere(
            (c) => c.name == catStr,
            orElse: () => DocCategorie.autre,
          );
        }
        return Document(
          id: m['id'] as String? ?? '',
          nom: m['nom'] as String? ?? '',
          path: m['path'] as String? ?? '',
          categorie: cat,
          dateAjout: m['dateAjout'] as String? ?? '',
          extension: m['extension'] as String? ?? '',
        );
      }).whereType<Document>().toList();
    }
    EmployeStatut statut = EmployeStatut.enService;
    final statutStr = map['statut'] as String?;
    if (statutStr != null) {
      statut = EmployeStatut.values.firstWhere(
        (s) => s.name == statutStr,
        orElse: () => EmployeStatut.enService,
      );
    }
    final salaire = map['salaireBase'];
    final salaireBase = salaire is int
        ? salaire.toDouble()
        : (salaire is num ? salaire.toDouble() : 0.0);
    final rawLeaveTaken = map['leaveDaysTaken'];
    final leaveDaysTaken = rawLeaveTaken is num ? rawLeaveTaken.toDouble() : 0.0;
    final rawLeaveExtra = map['leaveDaysExtra'];
    final leaveDaysExtra = rawLeaveExtra is num ? rawLeaveExtra.toDouble() : 0.0;
    final rawOcpSeg = map['ocpExcelSegment'] as String? ?? '';
    final ocpSeg = OcpExcelSegmentCode.allCodes.contains(rawOcpSeg.trim())
        ? rawOcpSeg.trim()
        : '';
    return Employe(
      id: map['id'] as String? ?? '',
      nom: map['nom'] as String? ?? '',
      cin: map['cin'] as String? ?? '',
      telephone: map['telephone'] as String? ?? '',
      telephone2: map['telephone2'] as String? ?? '',
      dateNaissance: map['dateNaissance'] as String? ?? '',
      adresse: map['adresse'] as String? ?? '',
      email: map['email'] as String? ?? '',
      poste: map['poste'] as String? ?? '',
      magasin: map['magasin'] as String? ?? '',
      departement: map['departement'] as String? ?? '',
      salaireBase: salaireBase,
      typeContrat: map['typeContrat'] as String? ?? '',
      dateDebut: map['dateDebut'] as String? ?? '',
      finContrat: map['finContrat'] as String? ?? '',
      chefDirectId: map['chefDirectId'] as String? ?? '',
      cnss: map['cnss'] as String? ?? '',
      dateCnss: map['dateCnss'] as String? ?? '',
      badgeActif: map['badgeActif'] as bool? ?? false,
      badgeExpiration: map['badgeExpiration'] as String? ?? '',
      statut: statut,
      documents: documentList,
      photoUrl: map['photoUrl'] as String? ?? '',
      siteId: map['siteId'] as String?,
      leaveDaysTaken: leaveDaysTaken,
      leaveDaysExtra: leaveDaysExtra,
      ocpExcelSegment: ocpSeg,
      ocpForceSalleControle: map['ocpForceSalleControle'] as bool? ?? false,
    );
  }

  Employe copyWith({
    String? id,
    String? nom,
    String? cin,
    String? telephone,
    String? telephone2,
    String? dateNaissance,
    String? adresse,
    String? email,
    String? poste,
    String? magasin,
    String? departement,
    double? salaireBase,
    String? typeContrat,
    String? dateDebut,
    String? finContrat,
    String? chefDirectId,
    String? cnss,
    String? dateCnss,
    bool? badgeActif,
    String? badgeExpiration,
    EmployeStatut? statut,
    List<Document>? documents,
    String? photoUrl,
    String? siteId,
    double? leaveDaysTaken,
    double? leaveDaysExtra,
    String? ocpExcelSegment,
    bool? ocpForceSalleControle,
  }) {
    return Employe(
      id: id ?? this.id,
      nom: nom ?? this.nom,
      cin: cin ?? this.cin,
      telephone: telephone ?? this.telephone,
      telephone2: telephone2 ?? this.telephone2,
      dateNaissance: dateNaissance ?? this.dateNaissance,
      adresse: adresse ?? this.adresse,
      email: email ?? this.email,
      poste: poste ?? this.poste,
      magasin: magasin ?? this.magasin,
      departement: departement ?? this.departement,
      salaireBase: salaireBase ?? this.salaireBase,
      typeContrat: typeContrat ?? this.typeContrat,
      dateDebut: dateDebut ?? this.dateDebut,
      finContrat: finContrat ?? this.finContrat,
      chefDirectId: chefDirectId ?? this.chefDirectId,
      cnss: cnss ?? this.cnss,
      dateCnss: dateCnss ?? this.dateCnss,
      badgeActif: badgeActif ?? this.badgeActif,
      badgeExpiration: badgeExpiration ?? this.badgeExpiration,
      statut: statut ?? this.statut,
      documents: documents ?? this.documents,
      photoUrl: photoUrl ?? this.photoUrl,
      siteId: siteId ?? _siteId,
      leaveDaysTaken: leaveDaysTaken ?? this.leaveDaysTaken,
      leaveDaysExtra: leaveDaysExtra ?? this.leaveDaysExtra,
      ocpExcelSegment: ocpExcelSegment ?? this.ocpExcelSegment,
      ocpForceSalleControle: ocpForceSalleControle ?? this.ocpForceSalleControle,
    );
  }
}