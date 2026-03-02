import 'package:flutter/material.dart';

class Equipe {
  final String id;
  final String nom;
  final String magasin;
  final String chefId;
  final List<String> membreIds;

  Equipe({
    required this.id,
    required this.nom,
    required this.magasin,
    required this.chefId,
    this.membreIds = const [],
  });

  Equipe copyWith({
    String? nom,
    String? magasin,
    String? chefId,
    List<String>? membreIds,
  }) {
    return Equipe(
      id: id,
      nom: nom ?? this.nom,
      magasin: magasin ?? this.magasin,
      chefId: chefId ?? this.chefId,
      membreIds: membreIds ?? this.membreIds,
    );
  }
}