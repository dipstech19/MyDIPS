import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'models/chef_compte_model.dart';

class ChefComptesProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collection = 'chef_comptes';

  bool _loading = false;
  bool get loading => _loading;

  bool get firebaseAvailable => true;

  List<ChefCompte> _chefComptes = [];
  List<ChefCompte> get chefComptes => List.unmodifiable(_chefComptes);

  ChefComptesProvider() {
    _watch();
  }

  void _watch() {
    _firestore.collection(_collection).snapshots().listen((snap) {
      _chefComptes = snap.docs
          .map((d) => ChefCompte.fromMap({...d.data(), 'id': d.id}))
          .toList();
      notifyListeners();
    });
  }

  Future<void> addChefCompte(ChefCompte c) async {
    _loading = true;
    notifyListeners();
    try {
      await _firestore.collection(_collection).add(c.toMap());
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> updateChefCompte(ChefCompte c) async {
    if (c.id.isEmpty) return;
    _loading = true;
    notifyListeners();
    try {
      await _firestore.collection(_collection).doc(c.id).set(c.toMap());
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> deleteChefCompte(String id) async {
    if (id.isEmpty) return;
    _loading = true;
    notifyListeners();
    try {
      await _firestore.collection(_collection).doc(id).delete();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }
}
