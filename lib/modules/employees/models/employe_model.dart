import 'package:flutter/material.dart';
import 'document_model.dart';

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
  final EmployeStatut statut;
  final List<Document> documents;
  final String photoUrl;
  /// موقع العمل: jadida | safi (الجدية / آسفي)
  final String siteId;

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
    required this.statut,
    this.documents = const [],
    this.photoUrl = '',
    this.siteId = 'jadida',
  });

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
      'statut': statut.name,
      'photoUrl': photoUrl,
      'siteId': siteId,
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
      statut: statut,
      documents: documentList,
      photoUrl: map['photoUrl'] as String? ?? '',
      siteId: map['siteId'] as String? ?? 'jadida',
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
    EmployeStatut? statut,
    List<Document>? documents,
    String? photoUrl,
    String? siteId,
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
      statut: statut ?? this.statut,
      documents: documents ?? this.documents,
      photoUrl: photoUrl ?? this.photoUrl,
      siteId: siteId ?? this.siteId,
    );
  }
}