import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import 'leave_demandes_page.dart' show LeaveRequest;

/// Flux temps réel des demandes de congé (collection `leave_requests`).
class LeaveRequestsProvider extends ChangeNotifier {
  final bool _firebaseAvailable = Firebase.apps.isNotEmpty;
  static const _collection = 'leave_requests';

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sub;
  List<LeaveRequest> _requests = [];
  bool _loading = true;
  String? _error;

  List<LeaveRequest> get requests => List.unmodifiable(_requests);
  bool get loading => _loading;
  String? get error => _error;

  LeaveRequestsProvider() {
    if (!_firebaseAvailable) {
      _loading = false;
      notifyListeners();
      return;
    }
    _sub = FirebaseFirestore.instance
        .collection(_collection)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .listen(
      (snap) {
        _requests = snap.docs.map(LeaveRequest.fromDoc).toList();
        _loading = false;
        _error = null;
        notifyListeners();
      },
      onError: (e) {
        _error = e.toString();
        _loading = false;
        notifyListeners();
      },
    );
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
