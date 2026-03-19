import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'models/chauffeur_model.dart';

class ChauffeursProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collection = 'chauffeurs';

  bool _loading = false;
  bool get loading => _loading;

  bool get firebaseAvailable => true;

  List<Chauffeur> _chauffeurs = [];
  List<Chauffeur> get chauffeurs => List.unmodifiable(_chauffeurs);

  ChauffeursProvider() {
    _watch();
  }

  void _watch() {
    _firestore.collection(_collection).snapshots().listen((snap) {
      _chauffeurs = snap.docs
          .map((d) => Chauffeur.fromMap({...d.data(), 'id': d.id}))
          .toList();
      notifyListeners();
    });
  }

  Future<void> addChauffeur(Chauffeur c) async {
    _loading = true;
    notifyListeners();
    try {
      await _firestore.collection(_collection).add(c.toMap());
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> updateChauffeur(Chauffeur c) async {
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

  Future<void> deleteChauffeur(String id) async {
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
