import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class NotificationService {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> initialize() async {
    try {
      await _messaging.requestPermission();
    } catch (e) {
      debugPrint('requestPermission failed: $e');
    }

    // subscribeToTopic is not supported on web and throws there.
    if (!kIsWeb) {
      try {
        await _messaging.subscribeToTopic('students');
      } catch (e) {
        debugPrint('subscribeToTopic failed: $e');
      }
    }

    await saveCurrentToken();

    try {
      _messaging.onTokenRefresh.listen(_saveToken);
    } catch (e) {
      debugPrint('onTokenRefresh listen failed: $e');
    }
  }

  Future<void> saveCurrentToken() async {
    try {
      // On web, getToken requires a VAPID key. Without it FCM is unavailable;
      // skip rather than crash.
      final token = await _messaging.getToken();
      if (token != null) await _saveToken(token);
    } catch (e) {
      debugPrint('getToken failed (push disabled): $e');
    }
  }

  Future<void> _saveToken(String token) async {
    final user = _auth.currentUser;
    if (user == null) return;
    await _db.collection('users').doc(user.uid).set({
      'fcmTokens': FieldValue.arrayUnion([token]),
      'lastTokenUpdatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
