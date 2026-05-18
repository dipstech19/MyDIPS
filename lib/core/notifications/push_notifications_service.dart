import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../auth/auth_model.dart';
import 'local_notifications_service.dart';
import 'pointage_notifications_service.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await LocalNotificationsService.instance.initialize();
  final n = message.notification;
  if (n == null) return;
  await LocalNotificationsService.instance.show(
    id: message.hashCode,
    title: n.title ?? 'My DIPS',
    body: n.body ?? '',
    channelId: LocalNotificationsService.channelAlertsId,
  );
}

class PushNotificationsService {
  PushNotificationsService._();
  static final PushNotificationsService instance = PushNotificationsService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _tokensCollection = 'notification_tokens';
  static const String _leaveRequestsCollection = 'leave_requests';

  bool _initialized = false;
  String? _currentToken;
  AppUser? _currentUser;
  GlobalKey<ScaffoldMessengerState>? _scaffoldMessengerKey;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _leaveRequestsSub;
  final Map<String, String> _knownLeaveStatusById = <String, String>{};
  bool _leaveBootstrapDone = false;
  final ValueNotifier<int> leaveUnreadCount = ValueNotifier<int>(0);

  Future<void> initialize({
    required GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey,
  }) async {
    if (_initialized) return;
    _initialized = true;
    _scaffoldMessengerKey = scaffoldMessengerKey;

    if (kIsWeb) return;
    if (defaultTargetPlatform != TargetPlatform.android &&
        defaultTargetPlatform != TargetPlatform.iOS) {
      return;
    }

    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    final initial = await FirebaseMessaging.instance.getInitialMessage();
    if (initial != null) {
      _showForegroundSnack(initial);
    }

    FirebaseMessaging.onMessage.listen(_showForegroundSnack);
    FirebaseMessaging.onMessageOpenedApp.listen(_showForegroundSnack);

    _currentToken = await FirebaseMessaging.instance.getToken();
    await _syncTokenDocument();

    FirebaseMessaging.instance.onTokenRefresh.listen((token) async {
      _currentToken = token;
      await _syncTokenDocument();
    });
  }

  Future<void> bindUser(AppUser? user) async {
    _currentUser = user;
    leaveUnreadCount.value = 0;
    await _restartLeaveRequestsNotifications();
    await _syncTokenDocument();
    await PointageNotificationsService.instance.bindUser(user);
  }

  void markLeaveNotificationsRead() {
    if (leaveUnreadCount.value == 0) return;
    leaveUnreadCount.value = 0;
  }

  Future<void> _restartLeaveRequestsNotifications() async {
    await _leaveRequestsSub?.cancel();
    _leaveRequestsSub = null;
    _knownLeaveStatusById.clear();
    _leaveBootstrapDone = false;

    final uid = _currentUser?.id;
    if (uid == null || uid.isEmpty) return;

    _leaveRequestsSub = _firestore
        .collection(_leaveRequestsCollection)
        .orderBy('createdAt', descending: true)
        .limit(250)
        .snapshots()
        .listen(
      (snap) {
        final userId = _currentUser?.id;
        if (userId == null || userId.isEmpty) return;
        var pendingAssignedCount = 0;

        final currentStatuses = <String, String>{};
        for (final d in snap.docs) {
          final m = d.data();
          final status = (m['status'] as String? ?? 'pending').trim();
          final assignedAdminId = (m['assignedAdminId'] as String? ?? '').trim();
          final submittedByUserId = (m['submittedByUserId'] as String? ?? '').trim();
          final employeeName = (m['employeeName'] as String? ?? 'Collaborateur').trim();

          final isAssignedToMe = assignedAdminId == userId;
          final isMyRequest = submittedByUserId == userId;
          if (!isAssignedToMe && !isMyRequest) continue;
          if (isAssignedToMe && status == 'pending' && !isMyRequest) {
            pendingAssignedCount++;
          }

          currentStatuses[d.id] = status;

          if (!_leaveBootstrapDone) continue;

          final previous = _knownLeaveStatusById[d.id];
          if (previous == null) {
            // New request arrived for current approver.
            if (isAssignedToMe && status == 'pending' && !isMyRequest) {
              _showLocalSnack(
                title: 'Nouvelle demande de congé',
                body: '$employeeName a envoyé une demande en attente.',
              );
              leaveUnreadCount.value = leaveUnreadCount.value + 1;
            }
            continue;
          }

          // Decision update for request owner.
          if (isMyRequest && previous != status) {
            if (status == 'approved') {
              _showLocalSnack(
                title: 'Demande approuvée',
                body: 'Votre demande de congé a été approuvée.',
              );
              leaveUnreadCount.value = leaveUnreadCount.value + 1;
            } else if (status == 'rejected') {
              _showLocalSnack(
                title: 'Demande refusée',
                body: 'Votre demande de congé a été refusée.',
              );
              leaveUnreadCount.value = leaveUnreadCount.value + 1;
            }
          }
        }

        _knownLeaveStatusById
          ..clear()
          ..addAll(currentStatuses);
        // Keep badge synced with real pending requests assigned to current user.
        leaveUnreadCount.value = pendingAssignedCount;
        _leaveBootstrapDone = true;
      },
      onError: (e) {
        debugPrint('Leave notifications stream error: $e');
      },
    );
  }

  Future<void> _syncTokenDocument() async {
    if (_currentToken == null || _currentToken!.isEmpty) return;

    final docRef = _firestore.collection(_tokensCollection).doc(_currentToken);
    final now = FieldValue.serverTimestamp();
    if (_currentUser == null) {
      await docRef.set({
        'token': _currentToken,
        'userId': null,
        'username': null,
        'role': null,
        'active': false,
        'platform': defaultTargetPlatform.name,
        'updatedAt': now,
      }, SetOptions(merge: true));
      return;
    }

    final u = _currentUser!;
    await docRef.set({
      'token': _currentToken,
      'userId': u.id,
      'username': u.username,
      'role': u.role.name,
      'equipeId': u.equipeId,
      'groupeId': u.groupeId,
      'distributionGroupIds': u.distributionGroupIds,
      'adminRole': u.adminRole,
      'active': true,
      'platform': defaultTargetPlatform.name,
      'updatedAt': now,
    }, SetOptions(merge: true));
  }

  void _showForegroundSnack(RemoteMessage message) {
    final notification = message.notification;
    final title = notification?.title ?? 'Notification';
    final body = notification?.body ?? '';
    unawaited(LocalNotificationsService.instance.show(
      id: message.hashCode,
      title: title,
      body: body.isEmpty ? title : body,
      channelId: LocalNotificationsService.channelAlertsId,
    ));
    final messenger = _scaffoldMessengerKey?.currentState;
    if (messenger == null) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(body.isEmpty ? title : '$title\n$body'),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _showLocalSnack({required String title, required String body}) {
    final messenger = _scaffoldMessengerKey?.currentState;
    if (messenger == null) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(body.isEmpty ? title : '$title\n$body'),
        duration: const Duration(seconds: 4),
      ),
    );
  }
}

