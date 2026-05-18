import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'data/distribution_groups_repository.dart';
import 'models/distribution_group_model.dart';

class DistributionGroupsProvider extends ChangeNotifier {
  final bool _firebaseAvailable = Firebase.apps.isNotEmpty;
  DistributionGroupsRepository? _repo;
  StreamSubscription? _sub;

  List<DistributionGroup> _list = [];
  bool _loading = true;

  List<DistributionGroup> get groups => List.unmodifiable(_list);
  bool get loading => _loading;
  bool get firebaseAvailable => _firebaseAvailable;

  DistributionGroupsProvider() {
    if (!_firebaseAvailable) {
      _loading = false;
      return;
    }
    _repo = DistributionGroupsRepository();
    _sub = _repo!.watchGroups().listen((list) {
      _list = list;
      _loading = false;
      notifyListeners();
    });
  }

  Future<void> addGroup(DistributionGroup g) async => _repo?.addGroup(g);
  Future<void> updateGroup(DistributionGroup g) async => _repo?.updateGroup(g);
  Future<void> deleteGroup(String id) async => _repo?.deleteGroup(id);

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

