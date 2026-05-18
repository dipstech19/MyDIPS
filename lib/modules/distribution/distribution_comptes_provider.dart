import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'data/distribution_comptes_repository.dart';
import 'models/distribution_compte_model.dart';

class DistributionComptesProvider extends ChangeNotifier {
  final bool _firebaseAvailable = Firebase.apps.isNotEmpty;
  DistributionComptesRepository? _repo;
  StreamSubscription? _sub;

  List<DistributionCompte> _list = [];
  bool _loading = true;

  List<DistributionCompte> get comptes => List.unmodifiable(_list);
  bool get loading => _loading;
  bool get firebaseAvailable => _firebaseAvailable;

  DistributionComptesProvider() {
    if (!_firebaseAvailable) {
      _loading = false;
      return;
    }
    _repo = DistributionComptesRepository();
    _sub = _repo!.watchComptes().listen((list) {
      _list = list;
      _loading = false;
      notifyListeners();
    });
  }

  Future<void> addCompte(DistributionCompte c) async => _repo?.addCompte(c);
  Future<void> updateCompte(DistributionCompte c) async => _repo?.updateCompte(c);
  Future<void> deleteCompte(String id) async => _repo?.deleteCompte(id);

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

