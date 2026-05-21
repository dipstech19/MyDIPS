import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'data/distribution_swaps_repository.dart';
import 'models/distribution_swap_model.dart';

class DistributionSwapsProvider extends ChangeNotifier {
  final bool _firebaseAvailable = Firebase.apps.isNotEmpty;
  DistributionSwapsRepository? _repo;
  StreamSubscription? _sub;

  List<DistributionSwap> _list = [];
  bool _loading = true;

  List<DistributionSwap> get swaps => List.unmodifiable(_list);
  bool get loading => _loading;

  DistributionSwapsProvider() {
    if (!_firebaseAvailable) {
      _loading = false;
      return;
    }
    _repo = DistributionSwapsRepository();
    _sub = _repo!.watchSwaps().listen((list) {
      _list = list;
      _loading = false;
      notifyListeners();
    });
  }

  DistributionSwapsRepository? get repo => _repo;

  Future<void> deleteSwap(String id) async {
    if (_repo == null) return;
    await _repo!.deleteSwap(id);
  }

  List<DistributionSwap> swapsForGroup(String groupId) => _list
      .where((s) =>
          s.status != DistributionSwapStatus.cancelled &&
          (s.groupAId == groupId || s.groupBId == groupId))
      .toList();

  List<DistributionSwap> activeSwapsForMonth(String monthKey) => _list
      .where((s) =>
          s.monthKey == monthKey &&
          s.status != DistributionSwapStatus.cancelled &&
          s.status != DistributionSwapStatus.completed)
      .toList();

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
