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
  });
}