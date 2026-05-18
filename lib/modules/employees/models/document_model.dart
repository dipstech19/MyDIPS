import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

enum DocCategorie { contrat, identite, medical, conge, autre }

extension DocCategorieExt on DocCategorie {
  String get label {
    switch (this) {
      case DocCategorie.contrat:  return 'Contrat';
      case DocCategorie.identite: return 'Identité';
      case DocCategorie.medical:  return 'Médical';
      case DocCategorie.conge:    return 'Congé';
      case DocCategorie.autre:    return 'Autre';
    }
  }

  Color get color {
    switch (this) {
      case DocCategorie.contrat:  return AppColors.brand;
      case DocCategorie.identite: return Colors.green;
      case DocCategorie.medical:  return Colors.red;
      case DocCategorie.conge:    return Colors.orange;
      case DocCategorie.autre:    return Colors.grey;
    }
  }

  IconData get icon {
    switch (this) {
      case DocCategorie.contrat:  return Icons.description;
      case DocCategorie.identite: return Icons.badge;
      case DocCategorie.medical:  return Icons.medical_services;
      case DocCategorie.conge:    return Icons.beach_access;
      case DocCategorie.autre:    return Icons.attach_file;
    }
  }
}

class Document {
  final String id;
  final String nom;
  final String path;
  final DocCategorie categorie;
  final String dateAjout;
  final String extension;

  Document({
    required this.id,
    required this.nom,
    required this.path,
    required this.categorie,
    required this.dateAjout,
    required this.extension,
  });
}