import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../shifts/models/shift_models.dart';

/// Planning shifts **Distribution** (même doc / collections que [DistributionShiftsPage]).
class DistributionShiftsProvider extends ChangeNotifier {
  static const String _configDocId = 'distribution_shifts_config';
  static const String _overridesCollection = 'distribution_shifts_overrides';

  final bool _firebaseOk = Firebase.apps.isNotEmpty;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _cfgSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _ovSub;

  RotationConfig? _config;
  Map<String, Map<String, ShiftType>> _overridesByDateKey = {};

  DistributionShiftsProvider() {
    if (_firebaseOk) _attach();
  }

  /// Config chargée avec au moins un id de groupe en rotation.
  bool get hasConfig =>
      _config != null && _config!.equipeIds.any((id) => id.trim().isNotEmpty);

  RotationConfig? get config => _config;

  void _attach() {
    final fs = FirebaseFirestore.instance;
    final docRef = fs.collection('app_config').doc(_configDocId);
    _cfgSub = docRef.snapshots().listen(
      (snap) {
        final m = snap.data() ?? const <String, dynamic>{};
        final startRaw = m['startDate'] as String?;
        final start = DateTime.tryParse(startRaw ?? '');
        final idsRaw = m['equipeIds'];
        final ids = idsRaw is List ? idsRaw.map((e) => e.toString()).toList() : const <String>[];
        if (start != null) {
          _config = RotationConfig(
            startDate: DateTime(start.year, start.month, start.day),
            equipeIds: ids,
          );
        } else {
          _config = null;
        }
        notifyListeners();
      },
      onError: (Object e) => debugPrint('DistributionShiftsProvider config: $e'),
    );

    _ovSub = docRef.collection(_overridesCollection).snapshots().listen(
      (snap) {
        final map = <String, Map<String, ShiftType>>{};
        for (final d in snap.docs) {
          final raw = d.data()['overrides'];
          if (raw is! Map) continue;
          final per = <String, ShiftType>{};
          raw.forEach((k, v) {
            if (v is! String) return;
            try {
              per[k.toString()] = ShiftType.values.firstWhere((e) => e.name == v);
            } catch (_) {}
          });
          if (per.isNotEmpty) map[d.id] = per;
        }
        _overridesByDateKey = map;
        notifyListeners();
      },
      onError: (Object e) => debugPrint('DistributionShiftsProvider overrides: $e'),
    );
  }

  static String _dateKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  int _dayInCycle(DateTime day) {
    if (_config == null) return 0;
    final start = _config!.startDay;
    final d = DateTime(day.year, day.month, day.day);
    final diff = d.difference(start).inDays;
    return diff >= 0 ? diff % ShiftRotationLogic.cycleDays : 0;
  }

  /// Le groupe figure dans la rotation configurée (emplacement P1–P4).
  bool hasRotationSlotForGroup(String groupId) {
    if (!hasConfig) return false;
    return _config!.equipeIds.contains(groupId);
  }

  ShiftType getShiftForGroup(String groupId, DateTime date) {
    if (_config == null) return ShiftType.rest;
    final pos = _config!.equipeIds.indexOf(groupId);
    if (pos < 0) return ShiftType.rest;
    final key = _dateKey(date);
    final o = _overridesByDateKey[key]?[groupId];
    if (o != null) return o;
    return ShiftRotationLogic.shiftForPosition(pos, _dayInCycle(date));
  }

  @override
  void dispose() {
    _cfgSub?.cancel();
    _ovSub?.cancel();
    super.dispose();
  }
}
