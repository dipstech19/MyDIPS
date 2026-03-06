import 'package:flutter/material.dart';

class Employe {
  final String id;
  final String nom;
  final String poste;
  Employe({required this.id, required this.nom, required this.poste});
}

class EmployeesProvider extends ChangeNotifier {
  List<Employe> _employes = [
    Employe(id: '1', nom: 'Ahmed Bensalem', poste: 'Technicien'),
    Employe(id: '2', nom: 'Sara Mansouri', poste: 'Responsable RH'),
  ];

  List<Employe> get employes => _employes;

  void addEmploye(Employe e) {
    _employes.add(e);
    notifyListeners();
  }
}
